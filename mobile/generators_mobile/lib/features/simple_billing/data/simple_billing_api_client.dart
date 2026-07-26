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

  Future<Map<String, dynamic>> recordPayment({
    required String invoiceId,
    required String operationUuid,
    required int amountIqd,
    required String paymentMethod,
    String? note,
  }) async =>
      _unwrap(
        (await _dio.post<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/monthly-billing/invoices/$invoiceId/payments',
          data: _paymentBody(
            operationUuid: operationUuid,
            amountIqd: amountIqd,
            paymentMethod: paymentMethod,
            note: note,
          ),
        ))
            .data,
      );

  Future<Map<String, dynamic>> getCollectorInvoices({String? query}) async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/collector/collections/invoices',
          queryParameters: {
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          },
        ))
            .data,
      );

  Future<Map<String, dynamic>> recordCollectorPayment({
    required String invoiceId,
    required String operationUuid,
    required int amountIqd,
    required String paymentMethod,
    String? note,
  }) async =>
      _unwrap(
        (await _dio.post<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/collector/collections/invoices/$invoiceId/payments',
          data: _paymentBody(
            operationUuid: operationUuid,
            amountIqd: amountIqd,
            paymentMethod: paymentMethod,
            note: note,
          ),
        ))
            .data,
      );

  Map<String, dynamic> _paymentBody({
    required String operationUuid,
    required int amountIqd,
    required String paymentMethod,
    String? note,
  }) =>
      {
        'confirm': true,
        'operation_uuid': operationUuid,
        'amount_iqd': amountIqd,
        'payment_method': paymentMethod,
        'note': note,
      };

  Map<String, dynamic> _unwrap(Map<String, dynamic>? envelope) {
    if (envelope == null || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('استجابة غير صالحة من السيرفر');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
}
