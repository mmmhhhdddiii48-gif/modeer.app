import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_token_storage.dart';

final class InvoiceApiClient {
  InvoiceApiClient({required SecureTokenStorage tokenStorage})
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

  Future<Map<String, dynamic>> getInvoices({String? periodId}) async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/invoices',
          queryParameters: {if (periodId != null && periodId.isNotEmpty) 'period_id': periodId},
        ))
            .data,
      );

  Future<Map<String, dynamic>> getDebtLedger() async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/debt-ledger',
        ))
            .data,
      );

  Future<Map<String, dynamic>> approveDraft(String draftId) async => _unwrap(
        (await _dio.post<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/billing/drafts/$draftId/approve',
          data: const {'confirm': true},
        ))
            .data,
      );

  Map<String, dynamic> _unwrap(Map<String, dynamic>? envelope) {
    if (envelope == null || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('استجابة غير صالحة من السيرفر');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
}
