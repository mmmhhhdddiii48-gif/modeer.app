import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';

final class ApiClient {
  ApiClient({required SecureTokenStorage tokenStorage})
      : _tokenStorage = tokenStorage,
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
          final token = await _tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/auth/login',
      data: {'login': login, 'password': password},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return _unwrap(response.data);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/auth/me',
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getOwnerCollectors() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors',
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> createOwnerCollector(Map<String, dynamic> input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerCollector(
    String collectorId,
    Map<String, dynamic> input,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors/$collectorId',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerCollectorStatus(
    String collectorId,
    String status,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors/$collectorId/status',
      data: {'status': status},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerCollectorPermissions(
    String collectorId,
    List<String> permissions,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors/$collectorId/permissions',
      data: {'permissions': permissions},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> resetOwnerCollectorPassword(
    String collectorId,
    String newPassword,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors/$collectorId/reset-password',
      data: {'new_password': newPassword},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getOwnerCollectorAssignments(String collectorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors/$collectorId/assignments',
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> replaceOwnerCollectorAssignments(
    String collectorId,
    List<Map<String, dynamic>> assignments,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/collectors/$collectorId/assignments',
      data: {'assignments': assignments},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getCollectorAssignments() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/collector/assignments',
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getOwnerGenerators({String? query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/generators',
      queryParameters: _compact({'q': query}),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> createOwnerGenerator(Map<String, dynamic> input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/generators',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerGenerator(String id, Map<String, dynamic> input) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/generators/$id',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerGeneratorStatus(String id, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/generators/$id/status',
      data: {'status': status},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getOwnerRoutes({String? query, String? generatorId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/routes',
      queryParameters: _compact({'q': query, 'generator_id': generatorId}),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> createOwnerRoute(Map<String, dynamic> input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/routes',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerRoute(String id, Map<String, dynamic> input) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/routes/$id',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerRouteStatus(String id, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/routes/$id/status',
      data: {'status': status},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getOwnerSubscribers({
    String? query,
    String? generatorId,
    String? routeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/subscribers',
      queryParameters: _compact({
        'q': query,
        'generator_id': generatorId,
        'route_id': routeId,
      }),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> createOwnerSubscriber(Map<String, dynamic> input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/subscribers',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerSubscriber(String id, Map<String, dynamic> input) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/subscribers/$id',
      data: input,
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> updateOwnerSubscriberStatus(String id, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/subscribers/$id/status',
      data: {'status': status},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getOwnerAssignmentCatalog({required String type}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/owner/assignment-catalog',
      queryParameters: {'type': type},
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> getCollectorDomain() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/collector/domain',
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> pushOperation(Map<String, dynamic> operation) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.generatorsBasePath}/sync/operations',
      data: operation,
    );
    return _unwrap(response.data);
  }

  Map<String, dynamic> _compact(Map<String, dynamic> values) {
    return Map<String, dynamic>.fromEntries(
      values.entries.where((entry) => entry.value != null && entry.value.toString().trim().isNotEmpty),
    );
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? envelope) {
    if (envelope == null || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('استجابة غير صالحة من السيرفر');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
}
