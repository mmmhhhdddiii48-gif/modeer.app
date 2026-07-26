final class MonthlyPeriod {
  const MonthlyPeriod({
    required this.id,
    required this.periodKey,
    required this.title,
    required this.status,
    required this.readingCount,
    required this.priceCount,
    required this.invoiceCount,
    required this.totalIqd,
    required this.paidIqd,
    required this.remainingIqd,
  });

  factory MonthlyPeriod.fromJson(Map<String, dynamic> json) => MonthlyPeriod(
        id: json['id']?.toString() ?? '',
        periodKey: json['period_key']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        status: json['status']?.toString() ?? 'open',
        readingCount: _int(json['reading_count']),
        priceCount: _int(json['price_count']),
        invoiceCount: _int(json['invoice_count']),
        totalIqd: _int(json['total_iqd']),
        paidIqd: _int(json['paid_iqd']),
        remainingIqd: _int(json['remaining_iqd'] ?? json['total_iqd']),
      );

  final String id;
  final String periodKey;
  final String title;
  final String status;
  final int readingCount;
  final int priceCount;
  final int invoiceCount;
  final int totalIqd;
  final int paidIqd;
  final int remainingIqd;

  bool get isLocked => status == 'locked';
}

final class MonthlyGeneratorPrice {
  const MonthlyGeneratorPrice({
    required this.generatorId,
    required this.generatorCode,
    required this.generatorName,
    required this.readingCount,
    required this.priceLocked,
    this.pricePerAmpIqd,
    this.fixedFeeIqd,
  });

  factory MonthlyGeneratorPrice.fromJson(Map<String, dynamic> json) {
    final generator = Map<String, dynamic>.from(json['generator'] as Map? ?? const {});
    final price = json['price'] is Map ? Map<String, dynamic>.from(json['price'] as Map) : null;
    return MonthlyGeneratorPrice(
      generatorId: generator['id']?.toString() ?? '',
      generatorCode: generator['code']?.toString() ?? '',
      generatorName: generator['name']?.toString() ?? '',
      readingCount: _int(json['reading_count']),
      priceLocked: json['price_locked'] == true,
      pricePerAmpIqd: price == null ? null : _int(price['price_per_amp_iqd']),
      fixedFeeIqd: price == null ? null : _int(price['fixed_fee_iqd']),
    );
  }

  final String generatorId;
  final String generatorCode;
  final String generatorName;
  final int readingCount;
  final bool priceLocked;
  final int? pricePerAmpIqd;
  final int? fixedFeeIqd;

  bool get hasPrice => pricePerAmpIqd != null;
}

final class InvoicePayment {
  const InvoicePayment({
    required this.id,
    required this.receiptNumber,
    required this.amountIqd,
    required this.paymentMethod,
    required this.createdAt,
    this.note,
  });

  factory InvoicePayment.fromJson(Map<String, dynamic> json) => InvoicePayment(
        id: json['id']?.toString() ?? '',
        receiptNumber: json['receipt_number']?.toString() ?? '',
        amountIqd: _int(json['amount_iqd']),
        paymentMethod: json['payment_method']?.toString() ?? 'cash',
        note: json['note']?.toString(),
        createdAt: json['created_at']?.toString() ?? '',
      );

  final String id;
  final String receiptNumber;
  final int amountIqd;
  final String paymentMethod;
  final String? note;
  final String createdAt;

  String get methodLabel => paymentMethod == 'transfer' ? 'تحويل' : 'نقد';
}

final class MonthlyInvoice {
  const MonthlyInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.subscriberName,
    required this.accountNumber,
    required this.generatorName,
    required this.contractedAmperes,
    required this.pricePerAmpIqd,
    required this.fixedFeeIqd,
    required this.amountIqd,
    required this.paidAmountIqd,
    required this.remainingAmountIqd,
    required this.consumption,
    required this.payments,
    this.meterNumber,
    this.lastPaymentAt,
  });

  factory MonthlyInvoice.fromJson(Map<String, dynamic> json) => MonthlyInvoice(
        id: json['id']?.toString() ?? '',
        invoiceNumber: json['invoice_number']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unpaid',
        subscriberName: json['subscriber_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        meterNumber: json['meter_number']?.toString(),
        generatorName: json['generator_name']?.toString() ?? '',
        contractedAmperes: _int(json['contracted_amperes']),
        pricePerAmpIqd: _int(json['price_per_amp_iqd']),
        fixedFeeIqd: _int(json['fixed_fee_iqd']),
        amountIqd: _int(json['amount_iqd']),
        paidAmountIqd: _int(json['paid_amount_iqd']),
        remainingAmountIqd: _int(json['remaining_amount_iqd'] ?? json['amount_iqd']),
        consumption: _double(json['consumption']),
        lastPaymentAt: json['last_payment_at']?.toString(),
        payments: (json['payments'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => InvoicePayment.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );

  final String id;
  final String invoiceNumber;
  final String status;
  final String subscriberName;
  final String accountNumber;
  final String? meterNumber;
  final String generatorName;
  final int contractedAmperes;
  final int pricePerAmpIqd;
  final int fixedFeeIqd;
  final int amountIqd;
  final int paidAmountIqd;
  final int remainingAmountIqd;
  final double consumption;
  final String? lastPaymentAt;
  final List<InvoicePayment> payments;

  bool get isPaid => status == 'paid' || remainingAmountIqd <= 0;
  bool get isPartial => status == 'partial';
  String get statusLabel => isPaid ? 'مسددة' : isPartial ? 'جزئي' : 'غير مسددة';
}

final class MonthlySummary {
  const MonthlySummary({
    required this.readingCount,
    required this.requiredPriceCount,
    required this.priceCount,
    required this.missingPriceCount,
    required this.invoiceCount,
    required this.totalIqd,
    required this.paidIqd,
    required this.remainingIqd,
    required this.unpaidCount,
    required this.partialCount,
    required this.paidCount,
    required this.canCreateInvoices,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
        readingCount: _int(json['reading_count']),
        requiredPriceCount: _int(json['required_price_count']),
        priceCount: _int(json['price_count']),
        missingPriceCount: _int(json['missing_price_count']),
        invoiceCount: _int(json['invoice_count']),
        totalIqd: _int(json['total_iqd']),
        paidIqd: _int(json['paid_iqd']),
        remainingIqd: _int(json['remaining_iqd'] ?? json['total_iqd']),
        unpaidCount: _int(json['unpaid_count']),
        partialCount: _int(json['partial_count']),
        paidCount: _int(json['paid_count']),
        canCreateInvoices: json['can_create_invoices'] == true,
      );

  final int readingCount;
  final int requiredPriceCount;
  final int priceCount;
  final int missingPriceCount;
  final int invoiceCount;
  final int totalIqd;
  final int paidIqd;
  final int remainingIqd;
  final int unpaidCount;
  final int partialCount;
  final int paidCount;
  final bool canCreateInvoices;
}

final class MonthlyWorkspace {
  const MonthlyWorkspace({
    required this.period,
    required this.generators,
    required this.invoices,
    required this.summary,
  });

  factory MonthlyWorkspace.fromJson(Map<String, dynamic> json) => MonthlyWorkspace(
        period: MonthlyPeriod.fromJson(Map<String, dynamic>.from(json['period'] as Map? ?? const {})),
        generators: (json['generators'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => MonthlyGeneratorPrice.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        invoices: (json['invoices'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => MonthlyInvoice.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        summary: MonthlySummary.fromJson(Map<String, dynamic>.from(json['summary'] as Map? ?? const {})),
      );

  final MonthlyPeriod period;
  final List<MonthlyGeneratorPrice> generators;
  final List<MonthlyInvoice> invoices;
  final MonthlySummary summary;
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
double _double(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
