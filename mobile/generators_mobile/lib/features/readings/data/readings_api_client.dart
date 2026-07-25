import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_token_storage.dart';

final class ReadingsApiClient {
  ReadingsApiClient({required SecureTokenStorage tokenStorage})
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

  Future<Map<String, dynamic>> getCollectorContext() async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/collector/readings/context',
        ))
            .data,
      );

  Future<Map<String, dynamic>> getOwnerPeriods() async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/reading-periods',
        ))
            .data,
      );

  Future<Map<String, dynamic>> createOwnerPeriod({
    required String periodKey,
    String? title,
  }) async =>
      _unwrap(
        (await _dio.post<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/reading-periods',
          data: {'period_key': periodKey, if (title != null && title.trim().isNotEmpty) 'title': title.trim()},
        ))
            .data,
      );

  Future<Map<String, dynamic>> lockOwnerPeriod(String periodId) async => _unwrap(
        (await _dio.patch<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/reading-periods/$periodId/lock',
          data: const {'confirm': true},
        ))
            .data,
      );

  Future<Map<String, dynamic>> getOwnerReadings(String periodId) async => _unwrap(
        (await _dio.get<Map<String, dynamic>>(
          '${AppConfig.generatorsBasePath}/owner/meter-readings',
          queryParameters: {'period_id': periodId},
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
