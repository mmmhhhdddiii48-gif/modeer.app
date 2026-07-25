final class AuthSession {
  const AuthSession({
    required this.accountId,
    required this.fullName,
    required this.role,
    required this.tenantId,
    required this.tenantName,
    required this.permissions,
  });

  final String accountId;
  final String fullName;
  final String role;
  final String tenantId;
  final String tenantName;
  final List<String> permissions;

  bool get isOwner => role == 'owner';
  bool get isCollector => role == 'collector';

  factory AuthSession.fromApi(Map<String, dynamic> data) {
    final account = Map<String, dynamic>.from(data['account'] as Map);
    final tenant = Map<String, dynamic>.from(data['tenant'] as Map);
    final rawPermissions = data['permissions'] as List? ?? const [];
    return AuthSession(
      accountId: account['id'] as String,
      fullName: account['full_name'] as String,
      role: account['role'] as String,
      tenantId: tenant['id'] as String,
      tenantName: tenant['name'] as String,
      permissions: rawPermissions.map((item) => item.toString()).toList(growable: false),
    );
  }
}
