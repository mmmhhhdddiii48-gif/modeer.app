import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/invoices/domain/invoice_models.dart';

void main() {
  test('Stage06 invoice and debt models parse IQD values', () {
    final result = InvoiceListResult.fromJson({
      'invoices': [
        {
          'id': 'i1',
          'invoice_number': 'INV-202607-ABC',
          'billing_draft_id': 'd1',
          'subscriber_name': 'مشترك',
          'account_number': 'A1',
          'generator_name': 'مولدة',
          'amount_iqd': 123000,
          'paid_amount_iqd': 0,
          'remaining_amount_iqd': 123000,
          'debt_status': 'open',
          'approved_at': '2026-07-26T00:00:00Z',
        }
      ],
      'summary': {
        'invoice_count': 1,
        'open_debt_count': 1,
        'total_amount_iqd': 123000,
        'paid_amount_iqd': 0,
        'remaining_amount_iqd': 123000,
      }
    });
    expect(result.invoices.single.billingDraftId, 'd1');
    expect(result.summary.remainingAmountIqd, 123000);
  });
}
