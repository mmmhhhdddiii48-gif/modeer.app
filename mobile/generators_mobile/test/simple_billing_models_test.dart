import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/simple_billing/domain/simple_billing_models.dart';

void main() {
  test('monthly invoice parses direct unpaid amount', () {
    final invoice = MonthlyInvoice.fromJson({
      'id': 'i1',
      'invoice_number': 'INV-202607-0001',
      'subscriber_name': 'مشترك',
      'account_number': 'A1',
      'generator_name': 'مولدة',
      'contracted_amperes': 10,
      'price_per_amp_iqd': 12000,
      'fixed_fee_iqd': 3000,
      'amount_iqd': 123000,
      'consumption': 100,
    });
    expect(invoice.amountIqd, 123000);
    expect(invoice.contractedAmperes, 10);
  });
}
