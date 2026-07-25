import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/owner/domain/collector_account.dart';

void main() {
  test('CollectorAccount parses Stage02 API response', () {
    final collector = CollectorAccount.fromApi({
      'id': 'collector-1',
      'full_name': 'جابي الاختبار',
      'username': 'collector.test',
      'phone': '07800000000',
      'status': 'active',
      'permissions': ['assignments.read', 'sync.own.read'],
      'assignment_count': 3,
      'last_server_sync_at': '2026-07-25T12:00:00.000Z',
    });

    expect(collector.isActive, isTrue);
    expect(collector.assignmentCount, 3);
    expect(collector.permissions, contains('assignments.read'));
    expect(collector.lastServerSyncAt, isNotNull);
  });

  test('CollectorAssignment serializes only assignment contract fields', () {
    const assignment = CollectorAssignment(
      id: 'local-1',
      type: 'route',
      targetId: 'route-1',
      label: 'المسار الأول',
      metadata: {'area': 'النجف'},
    );

    expect(assignment.toRequest(), {
      'type': 'route',
      'target_id': 'route-1',
      'label': 'المسار الأول',
      'metadata': {'area': 'النجف'},
    });
  });
}
