import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';
import '../network/api_client.dart';

final class SyncEngine {
  SyncEngine({required LocalDatabase database, required ApiClient api})
      : _database = database,
        _api = api;

  final LocalDatabase _database;
  final ApiClient _api;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _flushing = false;

  Future<void> start() async {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(flush());
      }
    });
    final current = await Connectivity().checkConnectivity();
    if (current.any((result) => result != ConnectivityResult.none)) {
      unawaited(flush());
    }
  }

  Future<String> enqueueProbe({Map<String, dynamic> payload = const {}}) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final uuid = const Uuid().v4();
    await db.insert('sync_queue', {
      'operation_uuid': uuid,
      'operation_type': 'sync.probe',
      'payload_json': jsonEncode(payload),
      'client_created_at': now,
      'status': 'pending',
      'attempts': 0,
      'updated_at': now,
    });
    return uuid;
  }

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final db = await _database.database;
      final rows = await db.query(
        'sync_queue',
        where: "status IN ('pending', 'failed', 'sending')",
        orderBy: 'id ASC',
        limit: 50,
      );
      for (final row in rows) {
        await _sendOne(db, row);
      }
      await _database.setMeta('last_sync_at', DateTime.now().toUtc().toIso8601String());
    } finally {
      _flushing = false;
    }
  }

  Future<void> _sendOne(Database db, Map<String, Object?> row) async {
    final id = row['id'] as int;
    final operationUuid = row['operation_uuid'] as String;
    final attempts = (row['attempts'] as int) + 1;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'sync_queue',
      {'status': 'sending', 'attempts': attempts, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _updateLocalReading(
      db,
      operationUuid,
      {'status': 'sending', 'attempts': attempts, 'updated_at': now},
    );

    try {
      final result = await _api.pushOperation({
        'operation_uuid': operationUuid,
        'operation_type': row['operation_type'],
        'payload': jsonDecode(row['payload_json'] as String),
        'client_created_at': row['client_created_at'],
      });
      final serverStatus = result['status']?.toString() ?? 'received';
      final response = result['response'] is Map
          ? Map<String, dynamic>.from(result['response'] as Map)
          : const <String, dynamic>{};
      final error = response['error'] is Map
          ? Map<String, dynamic>.from(response['error'] as Map)
          : const <String, dynamic>{};
      final serverReceivedAt = result['server_received_at']?.toString();

      if (serverStatus == 'conflict') {
        await db.update(
          'sync_queue',
          {
            'status': 'conflict',
            'server_received_at': serverReceivedAt,
            'last_error': error['message']?.toString(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await _updateLocalReading(db, operationUuid, {
          'status': 'conflict',
          'last_error_code': result['conflict_code']?.toString() ?? error['code']?.toString(),
          'last_error_message': error['message']?.toString(),
          'server_received_at': serverReceivedAt,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }

      if (serverStatus == 'rejected') {
        await db.update(
          'sync_queue',
          {
            'status': 'rejected',
            'server_received_at': serverReceivedAt,
            'last_error': error['message']?.toString(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await _updateLocalReading(db, operationUuid, {
          'status': 'failed',
          'last_error_code': result['conflict_code']?.toString() ?? error['code']?.toString(),
          'last_error_message': error['message']?.toString(),
          'server_received_at': serverReceivedAt,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }

      await db.update(
        'sync_queue',
        {
          'status': 'synced',
          'server_received_at': serverReceivedAt,
          'last_error': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _updateLocalReading(db, operationUuid, {
        'status': 'synced',
        'last_error_code': null,
        'last_error_message': null,
        'server_received_at': serverReceivedAt,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      final code = _serverErrorCode(error);
      final message = _serverErrorMessage(error) ?? error.toString();
      final isIdempotencyConflict = code == 'IDEMPOTENCY_CONFLICT';
      await db.update(
        'sync_queue',
        {
          'status': isIdempotencyConflict ? 'conflict' : 'failed',
          'last_error': message,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _updateLocalReading(db, operationUuid, {
        'status': isIdempotencyConflict ? 'conflict' : 'failed',
        'last_error_code': code,
        'last_error_message': message,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> _updateLocalReading(
    Database db,
    String operationUuid,
    Map<String, Object?> values,
  ) async {
    await db.update(
      'local_meter_readings',
      values,
      where: 'operation_uuid = ?',
      whereArgs: [operationUuid],
    );
  }

  String? _serverErrorCode(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['code']?.toString();
    }
    return null;
  }

  String? _serverErrorMessage(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['message']?.toString();
    }
    return null;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }
}
