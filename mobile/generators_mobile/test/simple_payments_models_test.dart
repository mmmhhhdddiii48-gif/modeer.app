import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/simple_billing/domain/simple_billing_models.dart';

void main() {
  test('monthly invoice parses partial payment and visible receipt', () {
    final invoice = MonthlyInvoice.fromJson({
      'id': 'i1',
      'invoice_number': 'INV-202607-0001',
      'status': 'partial',
      'subscriber_name': 'مشترك',
      'account_number': 'A1',
      'generator_name': 'مولدة',
      'contracted_amperes': 10,
      'price_per_amp_iqd': 12000,
      'fixed_fee_iqd': 3000,
      'amount_iqd': 123000,
      'paid_amount_iqd': 50000,
      'remaining_amount_iqd': 73000,
      'consumption': 100,
      'payments': [
        {
          'id': 'p1',
          'receipt_number': 'REC-202607-0001',
          'amount_iqd': 50000,
          'payment_method': 'cash',
          'created_at': '2026-07-26T00:00:00Z',
        }
      ],
    });

    expect(invoice.isPartial, isTrue);
    expect(invoice.paidAmountIqd, 50000);
    expect(invoice.remainingAmountIqd, 73000);
    expect(invoice.payments.single.receiptNumber, 'REC-202607-0001');
  });
}
