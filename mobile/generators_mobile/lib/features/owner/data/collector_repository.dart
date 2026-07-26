import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/database/local_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/collector_account.dart';

final class CollectorRepository {
  const CollectorRepository({required ApiClient api, required LocalDatabase database})
      : _api = api,
        _database = database;

  final ApiClient _api;
  final LocalDatabase _database;

  Future<({List<CollectorAccount> collectors, CollectorUsage usage})> listCollectors(
    String tenantId,
  ) async {
    Map<String, dynamic> data;
    try {
      data = await _api.getOwnerCollectors();
      await _database.setMeta(_collectorsCacheKey(tenantId), jsonEncode(data));
    } on DioException {
      final cached = await _database.getMeta(_collectorsCacheKey(tenantId));
      if (cached == null || cached.isEmpty) rethrow;
      data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }
    return _parseCollectors(data);
  }

  Future<void> createCollector({
    required String fullName,
    required String username,
    required String password,
    String? phone,
  }) async {
    await _api.createOwnerCollector({
      'full_name': fullName,
      'username': username,
      'password': password,
      'phone': phone,
    });
  }

  Future<void> updateCollectorProfile({
    required String collectorId,
    required String fullName,
    required String username,
    String? phone,
  }) async {
    await _api.updateOwnerCollector(collectorId, {
      'full_name': fullName,
      'username': username,
      'phone': phone,
    });
  }

  Future<void> updateStatus(String collectorId, String status) async {
    await _api.updateOwnerCollectorStatus(collectorId, status);
  }

  Future<void> updatePermissions(String collectorId, List<String> permissions) async {
    await _api.updateOwnerCollectorPermissions(collectorId, permissions);
  }

  Future<void> resetPassword(String collectorId, String newPassword) async {
    await _api.resetOwnerCollectorPassword(collectorId, newPassword);
  }

  Future<List<CollectorAssignment>> getAssignments({
    required String tenantId,
    required String collectorId,
  }) async {
    Map<String, dynamic> data;
    try {
      data = await _api.getOwnerCollectorAssignments(collectorId);
      await _database.setMeta(
        _assignmentsCacheKey(tenantId, collectorId),
        jsonEncode(data),
      );
    } on DioException {
      final cached = await _database.getMeta(_assignmentsCacheKey(tenantId, collectorId));
      if (cached == null || cached.isEmpty) rethrow;
      data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }
    return _parseAssignments(data);
  }

  Future<void> replaceAssignments({
    required String tenantId,
    required String collectorId,
    required List<CollectorAssignment> assignments,
  }) async {
    final data = await _api.replaceOwnerCollectorAssignments(
      collectorId,
      assignments.map((item) => item.toRequest()).toList(growable: false),
    );
    await _database.setMeta(
      _assignmentsCacheKey(tenantId, collectorId),
      jsonEncode(data),
    );
  }

  Future<List<CollectorAssignment>> getOwnAssignments({
    required String tenantId,
    required String collectorId,
  }) async {
    Map<String, dynamic> data;
    try {
      data = await _api.getCollectorAssignments();
      await _database.setMeta(
        _assignmentsCacheKey(tenantId, collectorId),
        jsonEncode(data),
      );
    } on DioException {
      final cached = await _database.getMeta(_assignmentsCacheKey(tenantId, collectorId));
      if (cached == null || cached.isEmpty) rethrow;
      data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }
    return _parseAssignments(data);
  }

  ({List<CollectorAccount> collectors, CollectorUsage usage}) _parseCollectors(
    Map<String, dynamic> data,
  ) {
    final rawCollectors = data['collectors'] as List? ?? const [];
    final usage = Map<String, dynamic>.from(data['usage'] as Map? ?? const {});
    return (
      collectors: rawCollectors
          .map((item) => CollectorAccount.fromApi(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      usage: CollectorUsage.fromApi(usage),
    );
  }

  List<CollectorAssignment> _parseAssignments(Map<String, dynamic> data) {
    final raw = data['assignments'] as List? ?? const [];
    return raw
        .map((item) => CollectorAssignment.fromApi(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  String _collectorsCacheKey(String tenantId) => 'stage02.collectors.$tenantId';
  String _assignmentsCacheKey(String tenantId, String collectorId) =>
      'stage02.assignments.$tenantId.$collectorId';
}
