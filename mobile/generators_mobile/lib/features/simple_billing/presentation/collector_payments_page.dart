import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/simple_billing_repository.dart';
import '../domain/simple_billing_models.dart';

final class CollectorPaymentsPage extends StatefulWidget {
  const CollectorPaymentsPage({
    required this.repository,
    required this.online,
    super.key,
  });

  final SimpleBillingRepository repository;
  final bool online;

  @override
  State<CollectorPaymentsPage> createState() => _CollectorPaymentsPageState();
}

final class _CollectorPaymentsPageState extends State<CollectorPaymentsPage> {
  final _searchController = TextEditingController();
  CollectorCollectionsWorkspace? _workspace;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.online) {
      if (mounted) {
        setState(() {
          _loading = false;
          _workspace = null;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final workspace = await widget.repository.getCollectorInvoices(
        query: _searchController.text,
      );
      if (mounted) setState(() => _workspace = workspace);
    } on DioException catch (error) {
      _show(_apiMessage(error));
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordPayment(MonthlyInvoice invoice) async {
    if (!widget.online) {
      _show('تحصيل الفواتير يحتاج اتصالًا بالسيرفر.');
      return;
    }
    if (invoice.isPaid) {
      _show('هذه الفاتورة مسددة بالكامل.');
      return;
    }
    final input = await showDialog<_CollectorPaymentInput>(
      context: context,
      builder: (_) => _CollectorPaymentDialog(invoice: invoice),
    );
    if (input == null || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await widget.repository.recordCollectorPayment(
        invoiceId: invoice.id,
        amountIqd: input.amountIqd,
        paymentMethod: input.paymentMethod,
        note: input.note,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result.duplicate ? 'الوصل محفوظ سابقًا' : 'تم تسجيل الدفعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الوصل: ${result.payment.receiptNumber}'),
              Text('المبلغ: ${_money(result.payment.amountIqd)} د.ع'),
              Text('المتبقي: ${_money(result.remainingAmountIqd)} د.ع'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      await _load();
    } on DioException catch (error) {
      _show(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (!widget.online) return 'تحصيل الفواتير يحتاج اتصالًا بالسيرفر.';
    return 'تعذر تنفيذ عملية التحصيل الآن.';
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحصيل الفواتير'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _working ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _OnlineNotice(online: widget.online),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'ابحث بالاسم أو الحساب أو العداد أو الفاتورة',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _working ? null : _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!widget.online)
              const _EmptyCard(text: 'لا يمكن تحميل الفواتير أو تسجيل دفعة بدون إنترنت.')
            else if (_workspace == null)
              const _EmptyCard(text: 'تعذر تحميل الفواتير.')
            else
              _workspaceBody(_workspace!),
          ],
        ),
      ),
    );
  }

  Widget _workspaceBody(CollectorCollectionsWorkspace workspace) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CollectorSummaryCard(summary: workspace.summary),
        const SizedBox(height: 16),
        Text(
          'الفواتير المكلّف بها',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (workspace.invoices.isEmpty)
          const _EmptyCard(text: 'لا توجد فواتير ضمن تخصيصاتك الحالية.')
        else
          ...workspace.invoices.map(
            (invoice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CollectorInvoiceCard(
                invoice: invoice,
                working: _working,
                onPayment: () => _recordPayment(invoice),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

final class _CollectorInvoiceCard extends StatelessWidget {
  const _CollectorInvoiceCard({
    required this.invoice,
    required this.working,
    required this.onPayment,
  });

  final MonthlyInvoice invoice;
  final bool working;
  final VoidCallback onPayment;

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.isPaid
        ? AppTheme.teal
        : invoice.isPartial
            ? AppTheme.orange
            : Colors.white70;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.subscriberName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                Chip(
                  label: Text(invoice.statusLabel),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            Text('${invoice.invoiceNumber} • شهر ${invoice.periodKey ?? '-'}'),
            Text('حساب ${invoice.accountNumber} • عداد ${invoice.meterNumber ?? '-'}'),
            Text('${invoice.generatorName} • ${invoice.routeName ?? 'بدون مسار'}'),
            if ((invoice.phone ?? '').isNotEmpty) Text('الهاتف: ${invoice.phone}'),
            const Divider(),
            _AmountRow(label: 'الإجمالي', value: invoice.amountIqd),
            _AmountRow(label: 'المدفوع', value: invoice.paidAmountIqd),
            _AmountRow(
              label: 'المتبقي',
              value: invoice.remainingAmountIqd,
              strong: true,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: working || invoice.isPaid ? null : onPayment,
              icon: const Icon(Icons.payments_outlined),
              label: Text(invoice.isPaid ? 'مسددة بالكامل' : 'تسجيل دفعة'),
            ),
            if (invoice.payments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('الوصولات', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ...invoice.payments.map(
                (payment) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${payment.receiptNumber} • ${_money(payment.amountIqd)} د.ع • ${payment.methodLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _CollectorPaymentInput {
  const _CollectorPaymentInput({
    required this.amountIqd,
    required this.paymentMethod,
    this.note,
  });

  final int amountIqd;
  final String paymentMethod;
  final String? note;
}

final class _CollectorPaymentDialog extends StatefulWidget {
  const _CollectorPaymentDialog({required this.invoice});

  final MonthlyInvoice invoice;

  @override
  State<_CollectorPaymentDialog> createState() => _CollectorPaymentDialogState();
}

final class _CollectorPaymentDialogState extends State<_CollectorPaymentDialog> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  String _method = 'cash';

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.invoice.remainingAmountIqd.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تسجيل دفعة — ${widget.invoice.subscriberName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المتبقي: ${_money(widget.invoice.remainingAmountIqd)} د.ع'),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المستلم'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقد')),
                DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
              ],
              onChanged: (value) => setState(() => _method = value ?? 'cash'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 250,
              decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            final amount = int.tryParse(_amount.text.trim());
            if (amount == null || amount <= 0 || amount > widget.invoice.remainingAmountIqd) {
              return;
            }
            Navigator.pop(
              context,
              _CollectorPaymentInput(
                amountIqd: amount,
                paymentMethod: _method,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: const Text('حفظ وإصدار وصل'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }
}

final class _CollectorSummaryCard extends StatelessWidget {
  const _CollectorSummaryCard({required this.summary});

  final CollectorCollectionsSummary summary;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              Text('الفواتير: ${summary.invoiceCount}'),
              Text('غير مسددة: ${summary.unpaidCount}'),
              Text('جزئي: ${summary.partialCount}'),
              Text('مسددة: ${summary.paidCount}'),
              Text(
                'المتبقي: ${_money(summary.remainingIqd)} د.ع',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
}

final class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final int value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${_money(value)} د.ع',
            style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w600),
          ),
        ],
      );
}

final class _OnlineNotice extends StatelessWidget {
  const _OnlineNotice({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        online
            ? 'التحصيل متاح Online. تظهر فقط الفواتير التابعة لتخصيصاتك.'
            : 'التحصيل متوقف بدون إنترنت. لا يتم حفظ دفعات محلية في هذه المرحلة.',
      ),
    );
  }
}

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

String _money(int value) {
  final text = value.toString();
  return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}
