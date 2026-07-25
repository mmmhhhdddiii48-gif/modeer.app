import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/simple_billing_repository.dart';
import '../domain/simple_billing_models.dart';

final class OwnerSimpleBillingPage extends StatefulWidget {
  const OwnerSimpleBillingPage({
    required this.repository,
    required this.online,
    super.key,
  });

  final SimpleBillingRepository repository;
  final bool online;

  @override
  State<OwnerSimpleBillingPage> createState() => _OwnerSimpleBillingPageState();
}

final class _OwnerSimpleBillingPageState extends State<OwnerSimpleBillingPage> {
  List<MonthlyPeriod> _periods = const [];
  MonthlyPeriod? _selected;
  MonthlyWorkspace? _workspace;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    setState(() => _loading = true);
    try {
      final periods = await widget.repository.getPeriods();
      if (!mounted) return;
      final selected = _selected == null
          ? (periods.isEmpty ? null : periods.first)
          : periods.where((item) => item.id == _selected!.id).firstOrNull;
      setState(() {
        _periods = periods;
        _selected = selected ?? (periods.isEmpty ? null : periods.first);
      });
      if (_selected != null) await _loadWorkspace();
    } on DioException catch (error) {
      _show(_apiMessage(error));
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWorkspace() async {
    final selected = _selected;
    if (selected == null) return;
    try {
      final workspace = await widget.repository.getWorkspace(selected.id);
      if (mounted) setState(() => _workspace = workspace);
    } on DioException catch (error) {
      _show(_apiMessage(error));
    }
  }

  Future<void> _selectPeriod(MonthlyPeriod? value) async {
    if (value == null) return;
    setState(() {
      _selected = value;
      _workspace = null;
    });
    await _loadWorkspace();
  }

  Future<void> _editPrice(MonthlyGeneratorPrice generator) async {
    if (generator.priceLocked) {
      _show('تم إنشاء فواتير هذه المولدة، لذلك لا يمكن تغيير السعر.');
      return;
    }
    final result = await showDialog<_PriceInput>(
      context: context,
      builder: (_) => _PriceDialog(generator: generator),
    );
    if (result == null || _selected == null || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.repository.savePrice(
        periodId: _selected!.id,
        generatorId: generator.generatorId,
        pricePerAmpIqd: result.price,
        fixedFeeIqd: result.fee,
      );
      _show('تم حفظ السعر.');
      await _loadWorkspace();
    } on DioException catch (error) {
      _show(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _createInvoices() async {
    final workspace = _workspace;
    final selected = _selected;
    if (workspace == null || selected == null) return;
    if (!workspace.summary.canCreateInvoices) {
      _show('أكمل الأسعار واقفل دورة القراءات أولًا.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء فواتير الشهر'),
        content: Text(
          'سيتم إنشاء ${workspace.summary.readingCount} فاتورة مباشرة. '
          'كل فاتورة ستظهر كدين غير مسدد إلى أن نفعل التسديد لاحقًا.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنشاء الفواتير')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.repository.createInvoices(selected.id);
      _show('تم إنشاء فواتير الشهر.');
      await _loadWorkspace();
      await _loadPeriods();
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
    if (!widget.online) return 'هذه الصفحة تحتاج اتصالًا بالسيرفر.';
    return 'تعذر تنفيذ العملية الآن.';
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير الشهر'),
        actions: [
          IconButton(onPressed: _working ? null : _loadPeriods, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPeriods,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _SimpleFlowCard(online: widget.online),
                  const SizedBox(height: 12),
                  if (_periods.isEmpty)
                    const _EmptyCard(text: 'لا توجد دورة قراءات بعد.')
                  else ...[
                    DropdownButtonFormField<MonthlyPeriod>(
                      value: _selected,
                      decoration: const InputDecoration(
                        labelText: 'اختر الشهر',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: _periods
                          .map(
                            (period) => DropdownMenuItem(
                              value: period,
                              child: Text('${period.periodKey} — ${period.isLocked ? 'مقفلة' : 'مفتوحة'}'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _working ? null : _selectPeriod,
                    ),
                    const SizedBox(height: 14),
                    if (_workspace == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      _workspaceBody(_workspace!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _workspaceBody(MonthlyWorkspace workspace) {
    final summary = workspace.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(summary: summary),
        const SizedBox(height: 14),
        Text('سعر الأمبير', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (workspace.generators.isEmpty)
          const _EmptyCard(text: 'لا توجد قراءات لهذا الشهر.')
        else
          ...workspace.generators.map(
            (generator) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(generator.generatorName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    generator.hasPrice
                        ? 'سعر الأمبير: ${_money(generator.pricePerAmpIqd!)} د.ع'
                            '${(generator.fixedFeeIqd ?? 0) > 0 ? ' + رسم ${_money(generator.fixedFeeIqd!)}' : ''}'
                        : 'السعر غير محدد',
                  ),
                  trailing: OutlinedButton(
                    onPressed: _working ? null : () => _editPrice(generator),
                    child: Text(generator.priceLocked ? 'مقفول' : generator.hasPrice ? 'تعديل' : 'تحديد'),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _working || !summary.canCreateInvoices || summary.invoiceCount > 0 ? null : _createInvoices,
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(summary.invoiceCount > 0 ? 'الفواتير منشأة' : 'إنشاء فواتير الشهر'),
        ),
        const SizedBox(height: 18),
        Text('الفواتير غير المسددة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (workspace.invoices.isEmpty)
          const _EmptyCard(text: 'لم تُنشأ فواتير هذا الشهر بعد.')
        else
          ...workspace.invoices.map(
            (invoice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(invoice.subscriberName, style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          const Chip(label: Text('غير مسددة')),
                        ],
                      ),
                      Text('${invoice.invoiceNumber} • حساب ${invoice.accountNumber}'),
                      Text('${invoice.generatorName} • ${invoice.contractedAmperes} أمبير'),
                      const Divider(),
                      Text(
                        '${invoice.contractedAmperes} × ${_money(invoice.pricePerAmpIqd)}'
                        '${invoice.fixedFeeIqd > 0 ? ' + ${_money(invoice.fixedFeeIqd)}' : ''}'
                        ' = ${_money(invoice.amountIqd)} د.ع',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('الدين الحالي: ${_money(invoice.amountIqd)} د.ع'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final class _PriceInput {
  const _PriceInput(this.price, this.fee);
  final int price;
  final int fee;
}

final class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.generator});
  final MonthlyGeneratorPrice generator;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

final class _PriceDialogState extends State<_PriceDialog> {
  late final TextEditingController _price;
  late final TextEditingController _fee;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.generator.pricePerAmpIqd?.toString() ?? '');
    _fee = TextEditingController(text: (widget.generator.fixedFeeIqd ?? 0).toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.generator.generatorName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'سعر الأمبير بالدينار'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fee,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'رسم ثابت اختياري'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            final price = int.tryParse(_price.text.trim());
            final fee = int.tryParse(_fee.text.trim()) ?? 0;
            if (price == null || price < 0 || fee < 0) return;
            Navigator.pop(context, _PriceInput(price, fee));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _price.dispose();
    _fee.dispose();
    super.dispose();
  }
}

final class _SimpleFlowCard extends StatelessWidget {
  const _SimpleFlowCard({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.40)),
      ),
      child: Text(
        '${online ? 'متصل' : 'غير متصل'}\n'
        'الطريقة واضحة: اقفل القراءات ← حدد سعر الأمبير ← أنشئ فواتير الشهر.\n'
        'الفاتورة غير المسددة هي الدين، ولا توجد مسودات أو مراجعات أو دفتر ذمم منفصل.',
      ),
    );
  }
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            Text('القراءات: ${summary.readingCount}'),
            Text('الأسعار الناقصة: ${summary.missingPriceCount}'),
            Text('الفواتير: ${summary.invoiceCount}'),
            Text('غير المسدد: ${_money(summary.totalIqd)} د.ع'),
          ],
        ),
      ),
    );
  }
}

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

String _money(int value) {
  final text = value.toString();
  return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
