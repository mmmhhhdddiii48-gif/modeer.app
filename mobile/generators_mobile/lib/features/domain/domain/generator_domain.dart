final class GeneratorUnit {
  const GeneratorUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.phaseType,
    required this.routeCount,
    required this.subscriberCount,
    this.area,
    this.address,
    this.capacityKva,
    this.notes,
  });

  final String id;
  final String code;
  final String name;
  final String? area;
  final String? address;
  final double? capacityKva;
  final String phaseType;
  final String status;
  final String? notes;
  final int routeCount;
  final int subscriberCount;

  bool get isActive => status == 'active';

  factory GeneratorUnit.fromApi(Map<String, dynamic> data) => GeneratorUnit(
        id: data['id'] as String,
        code: data['code'] as String,
        name: data['name'] as String,
        area: data['area'] as String?,
        address: data['address'] as String?,
        capacityKva: (data['capacity_kva'] as num?)?.toDouble(),
        phaseType: data['phase_type'] as String? ?? 'unknown',
        status: data['status'] as String? ?? 'active',
        notes: data['notes'] as String?,
        routeCount: (data['route_count'] as num?)?.toInt() ?? 0,
        subscriberCount: (data['subscriber_count'] as num?)?.toInt() ?? 0,
      );
}

final class GeneratorRoute {
  const GeneratorRoute({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.subscriberCount,
    this.area,
    this.notes,
    this.generator,
  });

  final String id;
  final String code;
  final String name;
  final String? area;
  final String status;
  final String? notes;
  final GeneratorReference? generator;
  final int subscriberCount;

  bool get isActive => status == 'active';

  factory GeneratorRoute.fromApi(Map<String, dynamic> data) {
    final rawGenerator = data['generator'];
    return GeneratorRoute(
      id: data['id'] as String,
      code: data['code'] as String,
      name: data['name'] as String,
      area: data['area'] as String?,
      status: data['status'] as String? ?? 'active',
      notes: data['notes'] as String?,
      generator: rawGenerator is Map
          ? GeneratorReference.fromApi(Map<String, dynamic>.from(rawGenerator))
          : null,
      subscriberCount: (data['subscriber_count'] as num?)?.toInt() ?? 0,
    );
  }
}

final class GeneratorSubscriber {
  const GeneratorSubscriber({
    required this.id,
    required this.accountNumber,
    required this.fullName,
    required this.status,
    required this.contractedAmperes,
    required this.generator,
    this.route,
    this.phone,
    this.area,
    this.address,
    this.meterNumber,
    this.notes,
  });

  final String id;
  final String accountNumber;
  final String fullName;
  final String? phone;
  final String? area;
  final String? address;
  final String? meterNumber;
  final int contractedAmperes;
  final String status;
  final String? notes;
  final GeneratorReference generator;
  final RouteReference? route;

  bool get isActive => status == 'active';

  factory GeneratorSubscriber.fromApi(Map<String, dynamic> data) {
    final generator = Map<String, dynamic>.from(data['generator'] as Map);
    final rawRoute = data['route'];
    return GeneratorSubscriber(
      id: data['id'] as String,
      accountNumber: data['account_number'] as String,
      fullName: data['full_name'] as String,
      phone: data['phone'] as String?,
      area: data['area'] as String?,
      address: data['address'] as String?,
      meterNumber: data['meter_number'] as String?,
      contractedAmperes: (data['contracted_amperes'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'active',
      notes: data['notes'] as String?,
      generator: GeneratorReference.fromApi(generator),
      route: rawRoute is Map
          ? RouteReference.fromApi(Map<String, dynamic>.from(rawRoute))
          : null,
    );
  }
}

final class GeneratorReference {
  const GeneratorReference({
    required this.id,
    required this.name,
    required this.status,
    this.code,
  });

  final String id;
  final String? code;
  final String name;
  final String status;

  factory GeneratorReference.fromApi(Map<String, dynamic> data) => GeneratorReference(
        id: data['id'] as String,
        code: data['code'] as String?,
        name: data['name'] as String,
        status: data['status'] as String? ?? 'active',
      );
}

final class RouteReference {
  const RouteReference({
    required this.id,
    required this.name,
    required this.status,
    this.code,
  });

  final String id;
  final String? code;
  final String name;
  final String status;

  factory RouteReference.fromApi(Map<String, dynamic> data) => RouteReference(
        id: data['id'] as String,
        code: data['code'] as String?,
        name: data['name'] as String,
        status: data['status'] as String? ?? 'active',
      );
}

final class AssignmentCatalogItem {
  const AssignmentCatalogItem({
    required this.id,
    required this.type,
    required this.label,
    required this.status,
    this.code,
    this.area,
    this.generatorName,
    this.routeName,
  });

  final String id;
  final String type;
  final String? code;
  final String label;
  final String? area;
  final String status;
  final String? generatorName;
  final String? routeName;

  factory AssignmentCatalogItem.fromApi(
    Map<String, dynamic> data,
    String fallbackType,
  ) =>
      AssignmentCatalogItem(
        id: data['id'] as String,
        type: data['type'] as String? ?? fallbackType,
        code: data['code'] as String?,
        label: data['label'] as String,
        area: data['area'] as String?,
        status: data['status'] as String? ?? 'active',
        generatorName: data['generator_name'] as String?,
        routeName: data['route_name'] as String?,
      );
}

final class DomainSummary {
  const DomainSummary({
    required this.generatorsTotal,
    required this.routesTotal,
    required this.subscribersTotal,
  });

  final int generatorsTotal;
  final int routesTotal;
  final int subscribersTotal;

  factory DomainSummary.fromApi(Map<String, dynamic> data) => DomainSummary(
        generatorsTotal: (data['generators_total'] as num?)?.toInt() ?? 0,
        routesTotal: (data['routes_total'] as num?)?.toInt() ?? 0,
        subscribersTotal: (data['subscribers_total'] as num?)?.toInt() ?? 0,
      );
}

final class AssignedDomain {
  const AssignedDomain({
    required this.generators,
    required this.routes,
    required this.subscribers,
  });

  final List<GeneratorUnit> generators;
  final List<GeneratorRoute> routes;
  final List<GeneratorSubscriber> subscribers;

  factory AssignedDomain.fromApi(Map<String, dynamic> data) => AssignedDomain(
        generators: _list(data['generators'], GeneratorUnit.fromApi),
        routes: _list(data['routes'], GeneratorRoute.fromApi),
        subscribers: _list(data['subscribers'], GeneratorSubscriber.fromApi),
      );

  static List<T> _list<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    final values = raw as List? ?? const [];
    return values
        .map((item) => parser(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }
}
