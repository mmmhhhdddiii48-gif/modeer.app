import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/features/billing/domain/billing_models.dart';

void main() {
  test('Stage05 billing workspace parses tariff and immutable draft snapshots', () {
    final workspace = BillingWorkspace.fromJson({
      'period': {
        'id': 'period-1',
        'period_key': '2026-09',
        'title': 'دورة أيلول',
        'status': 'locked',
      },
      'generators': [
        {
          'generator': {'id': 'g1', 'code': 'G1', 'name': 'مولدة 1'},
          'reading_count': 1,
          'tariff_locked': true,
          'tariff': {
            'id': 't1',
            'price_per_amp_iqd': 12000,
            'fixed_fee_iqd': 3000,
            'calculation_method': 'contracted_amperes',
          },
        }
      ],
      'drafts': [
        {
          'id': 'd1',
          'status': 'draft',
          'subscriber_name': 'علي حسن',
          'account_number': 'A1',
          'generator_name': 'مولدة 1',
          'contracted_amperes': 10,
          'price_per_amp_iqd': 12000,
          'fixed_fee_iqd': 3000,
          'previous_value': 100,
          'current_value': 150,
          'consumption': 50,
          'amount_iqd': 123000,
        }
      ],
      'summary': {
        'reading_count': 1,
        'required_tariff_count': 1,
        'tariff_count': 1,
        'missing_tariff_count': 0,
        'draft_count': 1,
        'reviewed_count': 0,
        'pending_review_count': 1,
        'total_amount_iqd': 123000,
        'can_generate': true,
      },
    });

    expect(workspace.period.isLocked, isTrue);
    expect(workspace.generators.single.tariffLocked, isTrue);
    expect(workspace.drafts.single.amountIqd, 123000);
    expect(workspace.summary.pendingReviewCount, 1);
  });
}
