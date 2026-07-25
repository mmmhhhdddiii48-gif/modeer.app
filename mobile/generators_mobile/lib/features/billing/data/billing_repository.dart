import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/database/local_database.dart';
import '../domain/billing_models.dart';
import 'billing_api_client.dart';

final class BillingRepository {
  BillingRepository({required BillingApiClient api, required LocalDatabase database})
      : _api = api,
        _database = database;

  final BillingApiClient _api;
  final LocalDatabase _database;

  Future<List<BillingPeriodSummary>> getPeriods(String tenantId) async {
    final key = 'stage05.billing.periods.$tenantId';
    try {
      final data = await _api.getPeriods();
      await _database.setMeta(key, jsonEncode(data));
      return _periods(data);
    } on DioException {
      final cached = await _database.getMeta(key);
      if (cached == null) rethrow;
      return _periods(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
  }

  Future<BillingWorkspace> getWorkspace({
    required String tenantId,
    required String periodId,
  }) async {
    final key = 'stage05.billing.workspace.$tenantId.$periodId';
    try {
      final data = await _api.getWorkspace(periodId);
      await _database.setMeta(key, jsonEncode(data));
      return BillingWorkspace.fromJson(data);
    } on DioException {
      final cached = await _database.getMeta(key);
      if (cached == null) rethrow;
      return BillingWorkspace.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
  }

  Future<void> saveTariff({
    required String periodId,
    required String generatorId,
    required int pricePerAmpIqd,
    required int fixedFeeIqd,
  }) async {
    await _api.saveTariff(
      periodId: periodId,
      generatorId: generatorId,
      pricePerAmpIqd: pricePerAmpIqd,
      fixedFeeIqd: fixedFeeIqd,
    );
  }

  Future<void> generateDrafts(String periodId) async {
    await _api.generateDrafts(periodId);
  }

  Future<void> updateDraftStatus(String draftId, String status) async {
    await _api.updateDraftStatus(draftId, status);
  }

  List<BillingPeriodSummary> _periods(Map<String, dynamic> data) =>
      (data['periods'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => BillingPeriodSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
}
