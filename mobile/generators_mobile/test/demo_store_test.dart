import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/demo/demo_store.dart';

void main() {
  group('DemoSnapshot', () {
    test('seed contains a complete customer demo', () {
      final snapshot = DemoSnapshot.seed();
      expect(snapshot.generators.length, 2);
      expect(snapshot.routes.length, 3);
      expect(snapshot.collectors.length, 2);
      expect(snapshot.subscribers.length, 8);
      expect(snapshot.invoices.length, 8);
      expect(snapshot.receipts.length, 4);
      expect(snapshot.billedIqd, greaterThan(0));
      expect(snapshot.collectedIqd, greaterThan(0));
      expect(snapshot.remainingIqd, greaterThan(0));
      expect(snapshot.billedIqd, snapshot.collectedIqd + snapshot.remainingIqd);
    });

    test('collector only receives assigned routes', () {
      final store = DemoStore();
      final collector = store.snapshot.collectors.first;
      final subscribers = store.subscribersForCollector(collector);
      expect(subscribers, isNotEmpty);
      expect(
        subscribers.every((item) => collector.assignedRouteIds.contains(item.routeId)),
        isTrue,
      );
      final subscriberIds = subscribers.map((item) => item.id).toSet();
      expect(
        store.invoicesForCollector(collector).every(
              (item) => subscriberIds.contains(item.subscriberId),
            ),
        isTrue,
      );
    });

    test('invoice status reflects paid and remaining values', () {
      final invoice = DemoInvoice(
        id: 'test',
        number: 'INV-TEST',
        subscriberId: 's1',
        totalIqd: 123000,
        paidIqd: 50000,
        dueDate: DateTime.utc(2026, 7, 30),
      );
      expect(invoice.remainingIqd, 73000);
      expect(invoice.isPartial, isTrue);
      expect(invoice.statusLabel, 'جزئي');
    });
  });
}
