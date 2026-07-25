import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/domain/domain/generator_domain.dart';

void main() {
  test('Stage03 parses generator, route, and subscriber contracts', () {
    final generator = GeneratorUnit.fromApi({
      'id': 'g-1',
      'code': 'GEN-01',
      'name': 'مولدة الاختبار',
      'status': 'active',
      'phase_type': 'three',
      'capacity_kva': 500,
      'route_count': 2,
      'subscriber_count': 20,
    });
    expect(generator.isActive, isTrue);
    expect(generator.capacityKva, 500);

    final route = GeneratorRoute.fromApi({
      'id': 'r-1',
      'code': 'R-01',
      'name': 'المسار الأول',
      'status': 'active',
      'subscriber_count': 10,
      'generator': {'id': 'g-1', 'code': 'GEN-01', 'name': 'مولدة الاختبار', 'status': 'active'},
    });
    expect(route.generator?.id, 'g-1');

    final subscriber = GeneratorSubscriber.fromApi({
      'id': 's-1',
      'account_number': 'A-001',
      'full_name': 'علي حسن',
      'status': 'active',
      'contracted_amperes': 10,
      'generator': {'id': 'g-1', 'code': 'GEN-01', 'name': 'مولدة الاختبار', 'status': 'active'},
      'route': {'id': 'r-1', 'code': 'R-01', 'name': 'المسار الأول', 'status': 'active'},
    });
    expect(subscriber.generator.id, 'g-1');
    expect(subscriber.route?.id, 'r-1');
  });
}
