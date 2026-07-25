import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/database/local_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/generator_domain.dart';

final class DomainRepository {
  const DomainRepository({required ApiClient api, required LocalDatabase database})
      : _api = api,
        _database = database;

  final ApiClient _api;
  final LocalDatabase _database;

  Future<({List<GeneratorUnit> items, DomainSummary summary})> listGenerators(
    String tenantId, {
    String? query,
  }) async {
    final data = await _loadCached(
      key: 'stage03.domain.generators.$tenantId',
      remote: () => _api.getOwnerGenerators(query: query),
    );
    return (
      items: _parseList(data['generators'], GeneratorUnit.fromApi),
      summary: DomainSummary.fromApi(_map(data['summary'])),
    );
  }

  Future<({List<GeneratorRoute> items, DomainSummary summary})> listRoutes(
    String tenantId, {
    String? query,
    String? generatorId,
  }) async {
    final data = await _loadCached(
      key: 'stage03.domain.routes.$tenantId',
      remote: () => _api.getOwnerRoutes(query: query, generatorId: generatorId),
    );
    return (
      items: _parseList(data['routes'], GeneratorRoute.fromApi),
      summary: DomainSummary.fromApi(_map(data['summary'])),
    );
  }

  Future<({List<GeneratorSubscriber> items, DomainSummary summary})> listSubscribers(
    String tenantId, {
    String? query,
    String? generatorId,
    String? routeId,
  }) async {
    final data = await _loadCached(
      key: 'stage03.domain.subscribers.$tenantId',
      remote: () => _api.getOwnerSubscribers(
        query: query,
        generatorId: generatorId,
        routeId: routeId,
      ),
    );
    return (
      items: _parseList(data['subscribers'], GeneratorSubscriber.fromApi),
      summary: DomainSummary.fromApi(_map(data['summary'])),
    );
  }

  Future<GeneratorUnit> saveGenerator({
    String? id,
    required Map<String, dynamic> input,
  }) async {
    final data = id == null
        ? await _api.createOwnerGenerator(input)
        : await _api.updateOwnerGenerator(id, input);
    return GeneratorUnit.fromApi(data);
  }

  Future<GeneratorUnit> setGeneratorStatus(String id, String status) async {
    return GeneratorUnit.fromApi(await _api.updateOwnerGeneratorStatus(id, status));
  }

  Future<GeneratorRoute> saveRoute({
    String? id,
    required Map<String, dynamic> input,
  }) async {
    final data = id == null
        ? await _api.createOwnerRoute(input)
        : await _api.updateOwnerRoute(id, input);
    return GeneratorRoute.fromApi(data);
  }

  Future<GeneratorRoute> setRouteStatus(String id, String status) async {
    return GeneratorRoute.fromApi(await _api.updateOwnerRouteStatus(id, status));
  }

  Future<GeneratorSubscriber> saveSubscriber({
    String? id,
    required Map<String, dynamic> input,
  }) async {
    final data = id == null
        ? await _api.createOwnerSubscriber(input)
        : await _api.updateOwnerSubscriber(id, input);
    return GeneratorSubscriber.fromApi(data);
  }

  Future<GeneratorSubscriber> setSubscriberStatus(String id, String status) async {
    return GeneratorSubscriber.fromApi(await _api.updateOwnerSubscriberStatus(id, status));
  }

  Future<List<AssignmentCatalogItem>> assignmentCatalog(String type) async {
    final data = await _api.getOwnerAssignmentCatalog(type: type);
    final key = switch (type) {
      'generator' => 'generators',
      'route' => 'routes',
      _ => 'subscribers',
    };
    return _parseList(
      data[key],
      (item) => AssignmentCatalogItem.fromApi(item, type),
    );
  }

  Future<AssignedDomain> getCollectorAssignedDomain({
    required String tenantId,
    required String collectorId,
  }) async {
    final data = await _loadCached(
      key: 'stage03.domain.collector.$tenantId.$collectorId',
      remote: _api.getCollectorDomain,
    );
    return AssignedDomain.fromApi(data);
  }

  Future<Map<String, dynamic>> _loadCached({
    required String key,
    required Future<Map<String, dynamic>> Function() remote,
  }) async {
    try {
      final data = await remote();
      await _database.setMeta(key, jsonEncode(data));
      return data;
    } on DioException {
      final cached = await _database.getMeta(key);
      if (cached == null || cached.isEmpty) rethrow;
      return Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<T> _parseList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    final values = raw as List? ?? const [];
    return values
        .map((item) => parser(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }
}
