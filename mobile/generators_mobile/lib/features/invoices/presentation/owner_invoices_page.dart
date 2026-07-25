import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/domain/billing_models.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_models.dart';

part 'owner_invoices_widgets.dart';

final class OwnerInvoicesPage extends StatefulWidget {
  const OwnerInvoicesPage({
    required this.billingRepository,
    required this.invoiceRepository,
    required this.tenantId,
    required this.online,
    super.key,
  });

  final BillingRepository billingRepository;
  final InvoiceRepository invoiceRepository;
  final String tenantId;
  final bool online;

  @override
  State<OwnerInvoicesPage> createState() => _OwnerInvoicesPageState();
}

final class _OwnerInvoicesPageState extends State<OwnerInvoicesPage> {
  List<BillingPeriodSummary> _periods = const [];
  BillingWorkspace? _billing;
  InvoiceListResult _invoices = const InvoiceListResult(
    invoices: [],
    summary: InvoiceSummary(invoiceCount: 0, openDebtCount: 0, totalAmountIqd: 0, paidAmountIqd: 0, remainingAmountIqd: 0),
  );
  DebtLedgerResult _ledger = const DebtLedgerResult(
    entries: [],
    summary: DebtSummary(entryCount: 0, totalDebitIqd: 0, totalCreditIqd: 0, totalReceivablesIqd: 0),
  );
  String? _periodId;
  bool _loading = true;
  String? _approvingDraftId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final periods = await widget.billingRepository.getPeriods(widget.tenantId);
      final selected = _periodId ?? (periods.isNotEmpty ? periods.first.id : null);
      BillingWorkspace? billing;
      if (selected != null) {
        billing = await widget.billingRepository.getWorkspace(tenantId: widget.tenantId, periodId: selected);
      }
      final invoices = await widget.invoiceRepository.getInvoices(tenantId: widget.tenantId, periodId: selected);
      final ledger = await widget.invoiceRepository.getDebtLedger(widget.tenantId);
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _periodId = selected;
        _billing = billing;
        _invoices = invoices;
        _ledger = ledger;
      });
    } on DioException catch (error) {
      _message(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPeriod(String? value) async {
    if (value == null || value == _periodId) return;
    setState(() => _periodId = value);
    await _load();
  }

  Future<void> _approve(BillingDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد الفاتورة وفتح الذمة'),
        content: Text(
          'سيتم اعتماد فاتورة بمبلغ ${_money(draft.amountIqd)} وفتح ذمة على المشترك ${draft.subscriberName}.\n\n'
          'لن يحدث قبض أو إصدار وصل أو تأثير على الصندوق في هذه المرحلة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('اعتماد وفتح الذمة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _approvingDraftId = draft.id);
    try {
      await widget.invoiceRepository.approveDraft(draft.id);
      _message('تم اعتماد الفاتورة وفتح قيد الذمة دون قبض.');
      await _load();
    } on DioException catch (error) {
      _message(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _approvingDraftId = null);
    }
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return widget.online ? 'تعذر تنفيذ العملية الآن.' : 'لا يوجد اتصال. آخر بيانات مؤكدة معروضة فقط.';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final approvedDraftIds = _invoices.invoices.map((item) => item.billingDraftId).toSet();
    final candidates = (_billing?.drafts ?? const <BillingDraft>[])
        .where((draft) => draft.isReviewed && !approvedDraftIds.contains(draft.id))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير والذمم'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StageNotice(online: widget.online),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _periodId,
            decoration: const InputDecoration(labelText: 'دورة الفاتورة'),
            items: _periods
                .map((period) => DropdownMenuItem(value: period.id, child: Text('${period.periodKey} — ${period.title}')))
                .toList(growable: false),
            onChanged: _loading ? null : _selectPeriod,
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(42), child: Center(child: CircularProgressIndicator()))
          else ...[
            _SummaryGrid(invoiceSummary: _invoices.summary, debtSummary: _ledger.summary),
            const SizedBox(height: 18),
            _SectionTitle(title: 'مسودات مراجَعة جاهزة للاعتماد', icon: Icons.fact_check_outlined),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              const _EmptyCard(text: 'لا توجد مسودات مراجَعة غير معتمدة في هذه الدورة.')
            else
              ...candidates.map((draft) => _CandidateCard(
                    draft: draft,
                    loading: _approvingDraftId == draft.id,
                    onApprove: () => _approve(draft),
                  )),
            const SizedBox(height: 18),
            _SectionTitle(title: 'الفواتير المعتمدة', icon: Icons.receipt_long_outlined),
            const SizedBox(height: 8),
            if (_invoices.invoices.isEmpty)
              const _EmptyCard(text: 'لا توجد فواتير معتمدة لهذه الدورة.')
            else
              ..._invoices.invoices.map((invoice) => _InvoiceCard(invoice: invoice)),
            const SizedBox(height: 18),
            _SectionTitle(title: 'سجل الذمم', icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: 8),
            if (_ledger.entries.isEmpty)
              const _EmptyCard(text: 'لا توجد قيود ذمم بعد.')
            else
              ..._ledger.entries.take(30).map((entry) => _DebtCard(entry: entry)),
          ],
        ],
      ),
    );
  }
}

String _money(int value) => '${value.toString()} د.ع';
