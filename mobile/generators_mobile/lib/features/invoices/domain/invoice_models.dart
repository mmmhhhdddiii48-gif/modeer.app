final class ApprovedInvoice {
  const ApprovedInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.billingDraftId,
    required this.subscriberName,
    required this.accountNumber,
    required this.generatorName,
    required this.amountIqd,
    required this.paidAmountIqd,
    required this.remainingAmountIqd,
    required this.debtStatus,
    required this.approvedAt,
    this.periodId,
    this.periodKey,
    this.meterNumber,
  });

  factory ApprovedInvoice.fromJson(Map<String, dynamic> json) => ApprovedInvoice(
        id: json['id']?.toString() ?? '',
        invoiceNumber: json['invoice_number']?.toString() ?? '',
        billingDraftId: json['billing_draft_id']?.toString() ?? '',
        subscriberName: json['subscriber_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        generatorName: json['generator_name']?.toString() ?? '',
        amountIqd: _int(json['amount_iqd']),
        paidAmountIqd: _int(json['paid_amount_iqd']),
        remainingAmountIqd: _int(json['remaining_amount_iqd']),
        debtStatus: json['debt_status']?.toString() ?? 'open',
        approvedAt: json['approved_at']?.toString() ?? '',
        periodId: json['period_id']?.toString(),
        periodKey: json['period_key']?.toString(),
        meterNumber: json['meter_number']?.toString(),
      );

  final String id;
  final String invoiceNumber;
  final String billingDraftId;
  final String subscriberName;
  final String accountNumber;
  final String generatorName;
  final int amountIqd;
  final int paidAmountIqd;
  final int remainingAmountIqd;
  final String debtStatus;
  final String approvedAt;
  final String? periodId;
  final String? periodKey;
  final String? meterNumber;
}

final class InvoiceSummary {
  const InvoiceSummary({
    required this.invoiceCount,
    required this.openDebtCount,
    required this.totalAmountIqd,
    required this.paidAmountIqd,
    required this.remainingAmountIqd,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) => InvoiceSummary(
        invoiceCount: _int(json['invoice_count']),
        openDebtCount: _int(json['open_debt_count']),
        totalAmountIqd: _int(json['total_amount_iqd']),
        paidAmountIqd: _int(json['paid_amount_iqd']),
        remainingAmountIqd: _int(json['remaining_amount_iqd']),
      );

  final int invoiceCount;
  final int openDebtCount;
  final int totalAmountIqd;
  final int paidAmountIqd;
  final int remainingAmountIqd;
}

final class InvoiceListResult {
  const InvoiceListResult({required this.invoices, required this.summary});

  factory InvoiceListResult.fromJson(Map<String, dynamic> json) => InvoiceListResult(
        invoices: (json['invoices'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => ApprovedInvoice.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        summary: InvoiceSummary.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
        ),
      );

  final List<ApprovedInvoice> invoices;
  final InvoiceSummary summary;
}

final class DebtLedgerEntry {
  const DebtLedgerEntry({
    required this.id,
    required this.subscriberName,
    required this.accountNumber,
    required this.entryType,
    required this.debitIqd,
    required this.creditIqd,
    required this.balanceAfterIqd,
    required this.createdAt,
    this.invoiceNumber,
    this.periodKey,
    this.note,
  });

  factory DebtLedgerEntry.fromJson(Map<String, dynamic> json) => DebtLedgerEntry(
        id: json['id']?.toString() ?? '',
        subscriberName: json['subscriber_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        entryType: json['entry_type']?.toString() ?? 'invoice_debit',
        debitIqd: _int(json['debit_iqd']),
        creditIqd: _int(json['credit_iqd']),
        balanceAfterIqd: _int(json['balance_after_iqd']),
        createdAt: json['created_at']?.toString() ?? '',
        invoiceNumber: json['invoice_number']?.toString(),
        periodKey: json['period_key']?.toString(),
        note: json['note']?.toString(),
      );

  final String id;
  final String subscriberName;
  final String accountNumber;
  final String entryType;
  final int debitIqd;
  final int creditIqd;
  final int balanceAfterIqd;
  final String createdAt;
  final String? invoiceNumber;
  final String? periodKey;
  final String? note;
}

final class DebtSummary {
  const DebtSummary({
    required this.entryCount,
    required this.totalDebitIqd,
    required this.totalCreditIqd,
    required this.totalReceivablesIqd,
  });

  factory DebtSummary.fromJson(Map<String, dynamic> json) => DebtSummary(
        entryCount: _int(json['entry_count']),
        totalDebitIqd: _int(json['total_debit_iqd']),
        totalCreditIqd: _int(json['total_credit_iqd']),
        totalReceivablesIqd: _int(json['total_receivables_iqd']),
      );

  final int entryCount;
  final int totalDebitIqd;
  final int totalCreditIqd;
  final int totalReceivablesIqd;
}

final class DebtLedgerResult {
  const DebtLedgerResult({required this.entries, required this.summary});

  factory DebtLedgerResult.fromJson(Map<String, dynamic> json) => DebtLedgerResult(
        entries: (json['entries'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => DebtLedgerEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        summary: DebtSummary.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
        ),
      );

  final List<DebtLedgerEntry> entries;
  final DebtSummary summary;
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
