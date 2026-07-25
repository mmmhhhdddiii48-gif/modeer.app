import '../domain/simple_billing_models.dart';
import 'simple_billing_api_client.dart';

final class SimpleBillingRepository {
  SimpleBillingRepository({required SimpleBillingApiClient api}) : _api = api;

  final SimpleBillingApiClient _api;

  Future<List<MonthlyPeriod>> getPeriods() async {
    final data = await _api.getPeriods();
    return (data['periods'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => MonthlyPeriod.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<MonthlyWorkspace> getWorkspace(String periodId) async =>
      MonthlyWorkspace.fromJson(await _api.getWorkspace(periodId));

  Future<void> savePrice({
    required String periodId,
    required String generatorId,
    required int pricePerAmpIqd,
    required int fixedFeeIqd,
  }) =>
      _api.savePrice(
        periodId: periodId,
        generatorId: generatorId,
        pricePerAmpIqd: pricePerAmpIqd,
        fixedFeeIqd: fixedFeeIqd,
      );

  Future<void> createInvoices(String periodId) => _api.createInvoices(periodId);
}
