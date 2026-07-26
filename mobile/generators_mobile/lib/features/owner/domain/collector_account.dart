final class CollectorAccount {
  const CollectorAccount({
    required this.id,
    required this.fullName,
    required this.username,
    required this.status,
    required this.permissions,
    required this.assignmentCount,
    this.phone,
    this.lastServerSyncAt,
  });

  final String id;
  final String fullName;
  final String username;
  final String? phone;
  final String status;
  final List<String> permissions;
  final int assignmentCount;
  final DateTime? lastServerSyncAt;

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get isDisabled => status == 'disabled';

  factory CollectorAccount.fromApi(Map<String, dynamic> data) {
    final rawPermissions = data['permissions'] as List? ?? const [];
    return CollectorAccount(
      id: data['id'] as String,
      fullName: data['full_name'] as String,
      username: data['username'] as String,
      phone: data['phone'] as String?,
      status: data['status'] as String,
      permissions: rawPermissions.map((item) => item.toString()).toList(growable: false),
      assignmentCount: (data['assignment_count'] as num?)?.toInt() ?? 0,
      lastServerSyncAt: _parseDate(data['last_server_sync_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

final class CollectorUsage {
  const CollectorUsage({
    required this.limit,
    required this.usedSlots,
    required this.remainingSlots,
    required this.activeCount,
    required this.suspendedCount,
    required this.disabledCount,
  });

  final int limit;
  final int usedSlots;
  final int remainingSlots;
  final int activeCount;
  final int suspendedCount;
  final int disabledCount;

  factory CollectorUsage.fromApi(Map<String, dynamic> data) {
    int read(String key) => (data[key] as num?)?.toInt() ?? 0;
    return CollectorUsage(
      limit: read('limit'),
      usedSlots: read('used_slots'),
      remainingSlots: read('remaining_slots'),
      activeCount: read('active_count'),
      suspendedCount: read('suspended_count'),
      disabledCount: read('disabled_count'),
    );
  }
}

final class CollectorAssignment {
  const CollectorAssignment({
    required this.id,
    required this.type,
    required this.targetId,
    required this.label,
    required this.metadata,
  });

  final String id;
  final String type;
  final String targetId;
  final String? label;
  final Map<String, dynamic> metadata;

  factory CollectorAssignment.fromApi(Map<String, dynamic> data) {
    final rawMetadata = data['metadata'];
    return CollectorAssignment(
      id: data['id'] as String,
      type: data['type'] as String,
      targetId: data['target_id'] as String,
      label: data['label'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toRequest() => {
        'type': type,
        'target_id': targetId,
        'label': label,
        'metadata': metadata,
      };
}
