import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../domain/meter_reading_models.dart';
import 'readings_api_client.dart';

final class ReadingRepository {
  ReadingRepository({required ReadingsApiClient api, required LocalDatabase database})
      : _api = api,
        _database = database;

  final ReadingsApiClient _api;
  final LocalDatabase _database;

  Future<CollectorReadingContext> getCollectorContext({
    required String tenantId,
    required String collectorId,
  }) async {
    final key = 'reading_context_${tenantId}_$collectorId';
    try {
      final data = await _api.getCollectorContext();
      await _database.setMeta(key, jsonEncode(data));
      return CollectorReadingContext.fromJson(data);
    } catch (_) {
      final cached = await _database.getMeta(key);
      if (cached == null || cached.isEmpty) rethrow;
      return CollectorReadingContext.fromJson(
        Map<String, dynamic>.from(jsonDecode(cached) as Map),
      );
    }
  }

  Future<List<LocalMeterReading>> listLocalReadings({
    required String tenantId,
    required String periodId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_meter_readings',
      where: 'tenant_id = ? AND period_id = ?',
      whereArgs: [tenantId, periodId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(LocalMeterReading.fromRow).toList(growable: false);
  }

  Future<String> queueMeterReading({
    required String tenantId,
    required ReadingPeriod period,
    required ReadingSubscriber subscriber,
    required double currentValue,
    String? note,
  }) async {
    if (currentValue < subscriber.previousValue) {
      throw StateError('القراءة الحالية لا يمكن أن تكون أقل من القراءة السابقة.');
    }
    if (subscriber.serverCurrentValue != null) {
      throw StateError('توجد قراءة مؤكدة لهذا المشترك في الدورة الحالية.');
    }

    final db = await _database.database;
    final uuid = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final consumption = currentValue - subscriber.previousValue;
    final payload = {
      'period_id': period.id,
      'subscriber_id': subscriber.id,
      'previous_value': subscriber.previousValue,
      'current_value': currentValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    await db.transaction((txn) async {
      final existing = await txn.query(
        'local_meter_readings',
        columns: const ['operation_uuid', 'status'],
        where: 'tenant_id = ? AND period_id = ? AND subscriber_id = ?',
        whereArgs: [tenantId, period.id, subscriber.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError('توجد حركة قراءة محلية لهذا المشترك في الدورة الحالية.');
      }
      await txn.insert('local_meter_readings', {
        'operation_uuid': uuid,
        'tenant_id': tenantId,
        'period_id': period.id,
        'period_key': period.periodKey,
        'subscriber_id': subscriber.id,
        'subscriber_name': subscriber.fullName,
        'account_number': subscriber.accountNumber,
        'meter_number': subscriber.meterNumber,
        'previous_value': subscriber.previousValue,
        'current_value': currentValue,
        'consumption': consumption,
        'note': note?.trim(),
        'client_created_at': now,
        'status': 'pending',
        'attempts': 0,
        'updated_at': now,
      });
      await txn.insert('sync_queue', {
        'operation_uuid': uuid,
        'operation_type': 'reading.create',
        'payload_json': jsonEncode(payload),
        'client_created_at': now,
        'status': 'pending',
        'attempts': 0,
        'updated_at': now,
      });
    });
    return uuid;
  }

  Future<List<ReadingPeriod>> getOwnerPeriods({required String tenantId}) async {
    const keySuffix = 'owner_reading_periods';
    final key = '${keySuffix}_$tenantId';
    try {
      final data = await _api.getOwnerPeriods();
      await _database.setMeta(key, jsonEncode(data));
      return _periodsFromEnvelope(data);
    } catch (_) {
      final cached = await _database.getMeta(key);
      if (cached == null || cached.isEmpty) rethrow;
      return _periodsFromEnvelope(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
  }

  Future<ReadingPeriod> createOwnerPeriod({required String periodKey, String? title}) async {
    return ReadingPeriod.fromJson(
      await _api.createOwnerPeriod(periodKey: periodKey, title: title),
    );
  }

  Future<ReadingPeriod> lockOwnerPeriod(String periodId) async {
    return ReadingPeriod.fromJson(await _api.lockOwnerPeriod(periodId));
  }

  Future<({ReadingPeriod? period, List<OwnerMeterReading> readings, Map<String, dynamic> summary})>
      getOwnerReadings(String periodId) async {
    final data = await _api.getOwnerReadings(periodId);
    final period = data['period'] is Map
        ? ReadingPeriod.fromJson(Map<String, dynamic>.from(data['period'] as Map))
        : null;
    final readings = (data['readings'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => OwnerMeterReading.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final summary = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : const <String, dynamic>{};
    return (period: period, readings: readings, summary: summary);
  }

  List<ReadingPeriod> _periodsFromEnvelope(Map<String, dynamic> data) {
    return (data['periods'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ReadingPeriod.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
