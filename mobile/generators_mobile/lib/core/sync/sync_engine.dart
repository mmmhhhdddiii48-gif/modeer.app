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
        where: "status IN ('pending', 'failed')",
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
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'sync_queue',
      {'status': 'sending', 'attempts': (row['attempts'] as int) + 1, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    try {
      final result = await _api.pushOperation({
        'operation_uuid': row['operation_uuid'],
        'operation_type': row['operation_type'],
        'payload': jsonDecode(row['payload_json'] as String),
        'client_created_at': row['client_created_at'],
      });
      await db.update(
        'sync_queue',
        {
          'status': 'synced',
          'server_received_at': result['server_received_at'],
          'last_error': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (error) {
      final code = _serverErrorCode(error);
      final message = error.toString();
      await db.update(
        'sync_queue',
        {
          'status': code == 'IDEMPOTENCY_CONFLICT' ? 'conflict' : 'failed',
          'last_error': message,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  String? _serverErrorCode(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['code']?.toString();
    }
    return null;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }
}
