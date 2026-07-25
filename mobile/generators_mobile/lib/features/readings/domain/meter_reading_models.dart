final class ReadingPeriod {
  const ReadingPeriod({
    required this.id,
    required this.periodKey,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.readingCount,
    required this.activeSubscriberCount,
    this.lockedAt,
  });

  final String id;
  final String periodKey;
  final String title;
  final String startsAt;
  final String endsAt;
  final String status;
  final int readingCount;
  final int activeSubscriberCount;
  final String? lockedAt;

  bool get isOpen => status == 'open';

  factory ReadingPeriod.fromJson(Map<String, dynamic> json) => ReadingPeriod(
        id: json['id']?.toString() ?? '',
        periodKey: json['period_key']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        startsAt: json['starts_at']?.toString() ?? '',
        endsAt: json['ends_at']?.toString() ?? '',
        status: json['status']?.toString() ?? 'locked',
        readingCount: (json['reading_count'] as num?)?.toInt() ?? 0,
        activeSubscriberCount: (json['active_subscriber_count'] as num?)?.toInt() ?? 0,
        lockedAt: json['locked_at']?.toString(),
      );
}

final class ReadingSubscriber {
  const ReadingSubscriber({
    required this.id,
    required this.fullName,
    required this.accountNumber,
    required this.generatorName,
    required this.previousValue,
    this.meterNumber,
    this.routeName,
    this.area,
    this.serverCurrentValue,
  });

  final String id;
  final String fullName;
  final String accountNumber;
  final String? meterNumber;
  final String generatorName;
  final String? routeName;
  final String? area;
  final double previousValue;
  final double? serverCurrentValue;

  factory ReadingSubscriber.fromJson(Map<String, dynamic> json) {
    final generator = json['generator'] is Map
        ? Map<String, dynamic>.from(json['generator'] as Map)
        : const <String, dynamic>{};
    final route = json['route'] is Map
        ? Map<String, dynamic>.from(json['route'] as Map)
        : const <String, dynamic>{};
    final current = json['current_reading'] is Map
        ? Map<String, dynamic>.from(json['current_reading'] as Map)
        : const <String, dynamic>{};
    return ReadingSubscriber(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      meterNumber: json['meter_number']?.toString(),
      generatorName: generator['name']?.toString() ?? '',
      routeName: route['name']?.toString(),
      area: json['area']?.toString(),
      previousValue: (json['previous_value'] as num?)?.toDouble() ?? 0,
      serverCurrentValue: (current['current_value'] as num?)?.toDouble(),
    );
  }
}

final class CollectorReadingContext {
  const CollectorReadingContext({
    required this.period,
    required this.subscribers,
    required this.readingEnabled,
  });

  final ReadingPeriod? period;
  final List<ReadingSubscriber> subscribers;
  final bool readingEnabled;

  factory CollectorReadingContext.fromJson(Map<String, dynamic> json) => CollectorReadingContext(
        period: json['period'] is Map
            ? ReadingPeriod.fromJson(Map<String, dynamic>.from(json['period'] as Map))
            : null,
        subscribers: (json['subscribers'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => ReadingSubscriber.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        readingEnabled: json['reading_enabled'] == true,
      );
}

final class LocalMeterReading {
  const LocalMeterReading({
    required this.operationUuid,
    required this.periodId,
    required this.subscriberId,
    required this.previousValue,
    required this.currentValue,
    required this.consumption,
    required this.status,
    required this.clientCreatedAt,
    this.errorCode,
    this.errorMessage,
    this.serverReceivedAt,
  });

  final String operationUuid;
  final String periodId;
  final String subscriberId;
  final double previousValue;
  final double currentValue;
  final double consumption;
  final String status;
  final String clientCreatedAt;
  final String? errorCode;
  final String? errorMessage;
  final String? serverReceivedAt;

  bool get isSynced => status == 'synced';
  bool get isConflict => status == 'conflict';
  bool get isPending => status == 'pending' || status == 'sending';

  factory LocalMeterReading.fromRow(Map<String, Object?> row) => LocalMeterReading(
        operationUuid: row['operation_uuid'] as String,
        periodId: row['period_id'] as String,
        subscriberId: row['subscriber_id'] as String,
        previousValue: (row['previous_value'] as num).toDouble(),
        currentValue: (row['current_value'] as num).toDouble(),
        consumption: (row['consumption'] as num).toDouble(),
        status: row['status'] as String,
        clientCreatedAt: row['client_created_at'] as String,
        errorCode: row['last_error_code'] as String?,
        errorMessage: row['last_error_message'] as String?,
        serverReceivedAt: row['server_received_at'] as String?,
      );
}

final class OwnerMeterReading {
  const OwnerMeterReading({
    required this.id,
    required this.subscriberName,
    required this.accountNumber,
    required this.previousValue,
    required this.currentValue,
    required this.consumption,
    required this.collectorName,
    required this.serverReceivedAt,
  });

  final String id;
  final String subscriberName;
  final String accountNumber;
  final double previousValue;
  final double currentValue;
  final double consumption;
  final String collectorName;
  final String serverReceivedAt;

  factory OwnerMeterReading.fromJson(Map<String, dynamic> json) {
    final collector = json['collector'] is Map
        ? Map<String, dynamic>.from(json['collector'] as Map)
        : const <String, dynamic>{};
    return OwnerMeterReading(
      id: json['id']?.toString() ?? '',
      subscriberName: json['subscriber_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      previousValue: (json['previous_value'] as num?)?.toDouble() ?? 0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      consumption: (json['consumption'] as num?)?.toDouble() ?? 0,
      collectorName: collector['name']?.toString() ?? '',
      serverReceivedAt: json['server_received_at']?.toString() ?? '',
    );
  }
}
