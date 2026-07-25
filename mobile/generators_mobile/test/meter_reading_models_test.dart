import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/readings/domain/meter_reading_models.dart';

void main() {
  test('reading context parses server period and previous values', () {
    final context = CollectorReadingContext.fromJson({
      'reading_enabled': true,
      'period': {
        'id': 'period-1',
        'period_key': '2026-07',
        'title': 'دورة تموز',
        'starts_at': '2026-07-01T00:00:00.000Z',
        'ends_at': '2026-07-31T23:59:59.999Z',
        'status': 'open',
      },
      'subscribers': [
        {
          'id': 'subscriber-1',
          'full_name': 'مشترك تجريبي',
          'account_number': 'A-1',
          'meter_number': 'M-1',
          'previous_value': 125,
          'generator': {'name': 'مولدة 1'},
          'route': {'name': 'مسار 1'},
        }
      ],
    });

    expect(context.readingEnabled, isTrue);
    expect(context.period?.isOpen, isTrue);
    expect(context.subscribers.single.previousValue, 125);
  });

  test('local reading exposes pending, conflict, and synced states', () {
    LocalMeterReading row(String status) => LocalMeterReading.fromRow({
          'operation_uuid': 'uuid-$status',
          'period_id': 'period-1',
          'subscriber_id': 'subscriber-1',
          'previous_value': 10,
          'current_value': 15,
          'consumption': 5,
          'status': status,
          'client_created_at': '2026-07-25T00:00:00.000Z',
          'last_error_code': null,
          'last_error_message': null,
          'server_received_at': null,
        });

    expect(row('pending').isPending, isTrue);
    expect(row('sending').isPending, isTrue);
    expect(row('conflict').isConflict, isTrue);
    expect(row('synced').isSynced, isTrue);
  });
}
