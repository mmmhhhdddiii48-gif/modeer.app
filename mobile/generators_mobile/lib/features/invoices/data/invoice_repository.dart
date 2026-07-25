import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/database/local_database.dart';
import '../domain/invoice_models.dart';
import 'invoice_api_client.dart';

final class InvoiceRepository {
  InvoiceRepository({required InvoiceApiClient api, required LocalDatabase database})
      : _api = api,
        _database = database;

  final InvoiceApiClient _api;
  final LocalDatabase _database;

  Future<InvoiceListResult> getInvoices({required String tenantId, String? periodId}) async {
    final key = 'stage06.invoices.$tenantId.${periodId ?? 'all'}';
    try {
      final data = await _api.getInvoices(periodId: periodId);
      await _database.setMeta(key, jsonEncode(data));
      return InvoiceListResult.fromJson(data);
    } on DioException {
      final cached = await _database.getMeta(key);
      if (cached == null) rethrow;
      return InvoiceListResult.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
  }

  Future<DebtLedgerResult> getDebtLedger(String tenantId) async {
    final key = 'stage06.debt-ledger.$tenantId';
    try {
      final data = await _api.getDebtLedger();
      await _database.setMeta(key, jsonEncode(data));
      return DebtLedgerResult.fromJson(data);
    } on DioException {
      final cached = await _database.getMeta(key);
      if (cached == null) rethrow;
      return DebtLedgerResult.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
  }

  Future<void> approveDraft(String draftId) async {
    await _api.approveDraft(draftId);
  }
}
