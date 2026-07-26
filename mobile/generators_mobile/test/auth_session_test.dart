import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/auth/domain/auth_session.dart';

void main() {
  test('parses owner session without exposing another tenant', () {
    final session = AuthSession.fromApi({
      'account': {'id': 'account-a', 'full_name': 'صاحب المولدة', 'role': 'owner'},
      'tenant': {'id': 'tenant-a', 'name': 'مولدة أ'},
      'permissions': ['dashboard.read'],
    });
    expect(session.isOwner, isTrue);
    expect(session.tenantId, 'tenant-a');
    expect(session.permissions, contains('dashboard.read'));
  });
}
