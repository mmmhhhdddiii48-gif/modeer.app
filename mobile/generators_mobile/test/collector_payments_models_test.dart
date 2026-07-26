import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/simple_billing/domain/simple_billing_models.dart';

void main() {
  test('collector workspace parses assigned invoice and receiver identity', () {
    final workspace = CollectorCollectionsWorkspace.fromJson({
      'online_required': true,
      'summary': {
        'invoice_count': 1,
        'total_iqd': 123000,
        'paid_iqd': 50000,
        'remaining_iqd': 73000,
        'unpaid_count': 0,
        'partial_count': 1,
        'paid_count': 0,
      },
      'invoices': [
        {
          'id': 'invoice-1',
          'invoice_number': 'INV-202608-0001',
          'period_key': '2026-08',
          'subscriber_name': 'مشترك أ',
          'account_number': 'A-001',
          'generator_name': 'مولدة أ',
          'route_name': 'مسار أ',
          'contracted_amperes': 10,
          'price_per_amp_iqd': 12000,
          'fixed_fee_iqd': 3000,
          'amount_iqd': 123000,
          'paid_amount_iqd': 50000,
          'remaining_amount_iqd': 73000,
          'status': 'partial',
          'consumption': 100,
          'payments': [
            {
              'id': 'payment-1',
              'receipt_number': 'REC-202608-0001',
              'amount_iqd': 50000,
              'payment_method': 'cash',
              'received_by': {
                'name': 'جابي أ',
                'role': 'collector',
              },
              'created_at': '2026-08-01T10:00:00Z',
            }
          ],
        }
      ],
    });

    expect(workspace.invoices.length, 1);
    expect(workspace.summary.remainingIqd, 73000);
    expect(workspace.invoices.first.isPartial, true);
    expect(workspace.invoices.first.payments.first.receiverLabel, contains('جابي أ'));
  });
}
