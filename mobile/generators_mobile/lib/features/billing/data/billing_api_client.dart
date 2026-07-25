import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_token_storage.dart';

final class BillingApiClient {
  BillingApiClient({required SecureTokenStorage tokenStorage})
      : _tokens = tokenStorage,
        _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokens;

  Future<Map<String, dynamic>> getPeriods() async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/billing/periods',
        )).data,
      );

  Future<Map<String, dynamic>> getWorkspace(String periodId) async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/billing/periods/$periodId',
        )).data,
      );

  Future<Map<String, dynamic>> saveTariff({
    required String periodId,
    required String generatorId,
    required int pricePerAmpIqd,
    required int fixedFeeIqd,
  }) async =>
      _unwrap(
        (await _dio.put<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/billing/periods/$periodId/tariffs/$generatorId',
          data: {
            'price_per_amp_iqd': pricePerAmpIqd,
            'fixed_fee_iqd': fixedFeeIqd,
          },
        )).data,
      );

  Future<Map<String, dynamic>> generateDrafts(String periodId) async => _unwrap(
        (await _dio.post<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/billing/periods/$periodId/generate',
        )).data,
      );

  Future<Map<String, dynamic>> updateDraftStatus(String draftId, String status) async => _unwrap(
        (await _dio.patch<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/billing/drafts/$draftId/status',
          data: {'status': status},
        )).data,
      );

  Map<String, dynamic> _unwrap(Map<String, dynamic>? envelope) {
    if (envelope == null || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('استجابة غير صالحة من السيرفر');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
}
