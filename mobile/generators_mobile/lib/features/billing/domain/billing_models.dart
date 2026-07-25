final class BillingPeriodSummary {
  const BillingPeriodSummary({
    required this.id,
    required this.periodKey,
    required this.title,
    required this.status,
    required this.readingCount,
    required this.tariffCount,
    required this.draftCount,
    required this.reviewedCount,
    required this.totalAmountIqd,
    this.lockedAt,
  });

  factory BillingPeriodSummary.fromJson(Map<String, dynamic> json) => BillingPeriodSummary(
        id: json['id']?.toString() ?? '',
        periodKey: json['period_key']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        status: json['status']?.toString() ?? 'open',
        readingCount: _int(json['reading_count']),
        tariffCount: _int(json['tariff_count']),
        draftCount: _int(json['draft_count']),
        reviewedCount: _int(json['reviewed_count']),
        totalAmountIqd: _int(json['total_amount_iqd']),
        lockedAt: json['locked_at']?.toString(),
      );

  final String id;
  final String periodKey;
  final String title;
  final String status;
  final int readingCount;
  final int tariffCount;
  final int draftCount;
  final int reviewedCount;
  final int totalAmountIqd;
  final String? lockedAt;
  bool get isLocked => status == 'locked';
}

final class BillingTariff {
  const BillingTariff({
    required this.id,
    required this.pricePerAmpIqd,
    required this.fixedFeeIqd,
    required this.calculationMethod,
  });

  factory BillingTariff.fromJson(Map<String, dynamic> json) => BillingTariff(
        id: json['id']?.toString() ?? '',
        pricePerAmpIqd: _int(json['price_per_amp_iqd']),
        fixedFeeIqd: _int(json['fixed_fee_iqd']),
        calculationMethod: json['calculation_method']?.toString() ?? 'contracted_amperes',
      );

  final String id;
  final int pricePerAmpIqd;
  final int fixedFeeIqd;
  final String calculationMethod;
}

final class BillingGeneratorTariff {
  const BillingGeneratorTariff({
    required this.generatorId,
    required this.generatorCode,
    required this.generatorName,
    required this.readingCount,
    required this.tariffLocked,
    this.tariff,
  });

  factory BillingGeneratorTariff.fromJson(Map<String, dynamic> json) {
    final generator = Map<String, dynamic>.from(json['generator'] as Map? ?? const {});
    return BillingGeneratorTariff(
      generatorId: generator['id']?.toString() ?? '',
      generatorCode: generator['code']?.toString() ?? '',
      generatorName: generator['name']?.toString() ?? '',
      readingCount: _int(json['reading_count']),
      tariffLocked: json['tariff_locked'] == true,
      tariff: json['tariff'] is Map
          ? BillingTariff.fromJson(Map<String, dynamic>.from(json['tariff'] as Map))
          : null,
    );
  }

  final String generatorId;
  final String generatorCode;
  final String generatorName;
  final int readingCount;
  final bool tariffLocked;
  final BillingTariff? tariff;
}

final class BillingDraft {
  const BillingDraft({
    required this.id,
    required this.status,
    required this.subscriberName,
    required this.accountNumber,
    required this.generatorName,
    required this.contractedAmperes,
    required this.pricePerAmpIqd,
    required this.fixedFeeIqd,
    required this.previousValue,
    required this.currentValue,
    required this.consumption,
    required this.amountIqd,
    this.meterNumber,
    this.reviewedAt,
  });

  factory BillingDraft.fromJson(Map<String, dynamic> json) => BillingDraft(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'draft',
        subscriberName: json['subscriber_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        meterNumber: json['meter_number']?.toString(),
        generatorName: json['generator_name']?.toString() ?? '',
        contractedAmperes: _int(json['contracted_amperes']),
        pricePerAmpIqd: _int(json['price_per_amp_iqd']),
        fixedFeeIqd: _int(json['fixed_fee_iqd']),
        previousValue: _double(json['previous_value']),
        currentValue: _double(json['current_value']),
        consumption: _double(json['consumption']),
        amountIqd: _int(json['amount_iqd']),
        reviewedAt: json['reviewed_at']?.toString(),
      );

  final String id;
  final String status;
  final String subscriberName;
  final String accountNumber;
  final String? meterNumber;
  final String generatorName;
  final int contractedAmperes;
  final int pricePerAmpIqd;
  final int fixedFeeIqd;
  final double previousValue;
  final double currentValue;
  final double consumption;
  final int amountIqd;
  final String? reviewedAt;
  bool get isReviewed => status == 'reviewed';
}

final class BillingSummary {
  const BillingSummary({
    required this.readingCount,
    required this.requiredTariffCount,
    required this.tariffCount,
    required this.missingTariffCount,
    required this.draftCount,
    required this.reviewedCount,
    required this.pendingReviewCount,
    required this.totalAmountIqd,
    required this.canGenerate,
  });

  factory BillingSummary.fromJson(Map<String, dynamic> json) => BillingSummary(
        readingCount: _int(json['reading_count']),
        requiredTariffCount: _int(json['required_tariff_count']),
        tariffCount: _int(json['tariff_count']),
        missingTariffCount: _int(json['missing_tariff_count']),
        draftCount: _int(json['draft_count']),
        reviewedCount: _int(json['reviewed_count']),
        pendingReviewCount: _int(json['pending_review_count']),
        totalAmountIqd: _int(json['total_amount_iqd']),
        canGenerate: json['can_generate'] == true,
      );

  final int readingCount;
  final int requiredTariffCount;
  final int tariffCount;
  final int missingTariffCount;
  final int draftCount;
  final int reviewedCount;
  final int pendingReviewCount;
  final int totalAmountIqd;
  final bool canGenerate;
}

final class BillingWorkspace {
  const BillingWorkspace({
    required this.period,
    required this.generators,
    required this.drafts,
    required this.summary,
  });

  factory BillingWorkspace.fromJson(Map<String, dynamic> json) => BillingWorkspace(
        period: BillingPeriodSummary.fromJson(
          Map<String, dynamic>.from(json['period'] as Map? ?? const {}),
        ),
        generators: (json['generators'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => BillingGeneratorTariff.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        drafts: (json['drafts'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => BillingDraft.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        summary: BillingSummary.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
        ),
      );

  final BillingPeriodSummary period;
  final List<BillingGeneratorTariff> generators;
  final List<BillingDraft> drafts;
  final BillingSummary summary;
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
double _double(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
