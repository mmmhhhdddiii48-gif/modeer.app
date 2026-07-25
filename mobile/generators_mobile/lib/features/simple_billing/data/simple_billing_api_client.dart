import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_token_storage.dart';

final class SimpleBillingApiClient {
  SimpleBillingApiClient({required SecureTokenStorage tokenStorage})
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
          '${AppConfig.generatorsBasePath}/owner/monthly-billing/periods',
        ))
            .data,
      );

  Future<Map<String, dynamic>> getWorkspace(String periodId) async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/monthly-billing/periods/$periodId',
        ))
            .data,
      );

  Future<void> savePrice({
    required String periodId,
    required String generatorId,
    required int pricePerAmpIqd,
    required int fixedFeeIqd,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/monthly-billing/periods/$periodId/generators/$generatorId/price',
      data: {
        'price_per_amp_iqd': pricePerAmpIqd,
        'fixed_fee_iqd': fixedFeeIqd,
      },
    );
  }

  Future<void> createInvoices(String periodId) async {
    await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/monthly-billing/periods/$periodId/create-invoices',
      data: const {'confirm': true},
    );
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? envelope) {
    if (envelope == null || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('استجابة غير صالحة من السيرفر');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
}
