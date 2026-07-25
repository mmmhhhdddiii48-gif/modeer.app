import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';

part 'owner_billing_tariff_dialog.dart';
part 'owner_billing_widgets.dart';

final class OwnerBillingPage extends StatefulWidget {
  const OwnerBillingPage({
    required this.repository,
    required this.tenantId,
    required this.online,
    super.key,
  });

  final BillingRepository repository;
  final String tenantId;
  final bool online;

  @override
  State<OwnerBillingPage> createState() => _OwnerBillingPageState();
}

final class _OwnerBillingPageState extends State<OwnerBillingPage> {
  List<BillingPeriodSummary> _periods = const [];
  BillingPeriodSummary? _selectedPeriod;
  BillingWorkspace? _workspace;
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
      final periods = await widget.repository.getPeriods(widget.tenantId);
      final selected = periods.firstWhere(
        (item) => item.id == _selectedPeriod?.id,
        orElse: () => periods.isNotEmpty ? periods.first : const BillingPeriodSummary(
          id: '', periodKey: '', title: '', status: 'open', readingCount: 0,
          tariffCount: 0, draftCount: 0, reviewedCount: 0, totalAmountIqd: 0,
        ),
      );
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _selectedPeriod = selected.id.isEmpty ? null : selected;
      });
      if (_selectedPeriod != null) await _loadWorkspace();
    } on DioException catch (error) {
      _message(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWorkspace() async {
    final period = _selectedPeriod;
    if (period == null) return;
    try {
      final workspace = await widget.repository.getWorkspace(
        tenantId: widget.tenantId,
        periodId: period.id,
      );
      if (!mounted) return;
      setState(() => _workspace = workspace);
    } on DioException catch (error) {
      _message(_apiMessage(error));
    }
  }

  Future<void> _selectPeriod(BillingPeriodSummary period) async {
    setState(() {
      _selectedPeriod = period;
      _workspace = null;
      _loading = true;
    });
    await _loadWorkspace();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editTariff(BillingGeneratorTariff generator) async {
    if (!widget.online) {
      _message('تعديل التسعيرة يحتاج اتصالًا بالسيرفر.');
      return;
    }
    if (generator.tariffLocked) {
      _message('التسعيرة مقفلة لأن مسودات هذه المولدة تم توليدها.');
      return;
    }
    final result = await showDialog<_TariffInput>(
      context: context,
      builder: (_) => _TariffDialog(generator: generator),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      await widget.repository.saveTariff(
        periodId: _selectedPeriod!.id,
        generatorId: generator.generatorId,
        pricePerAmpIqd: result.pricePerAmpIqd,
        fixedFeeIqd: result.fixedFeeIqd,
      );
      await _loadWorkspace();
      _message('تم حفظ تسعيرة ${generator.generatorName}.');
    });
  }

  Future<void> _generate() async {
    final workspace = _workspace;
    if (workspace == null) return;
    if (!widget.online) {
      _message('توليد المسودات يحتاج اتصالًا بالسيرفر.');
      return;
    }
    if (!workspace.period.isLocked) {
      _message('يجب قفل دورة القراءة أولًا.');
      return;
    }
    if (!workspace.summary.canGenerate) {
      _message('أكمل تسعيرات جميع المولدات التي لديها قراءات مؤكدة.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توليد مسودات الفواتير'),
        content: const Text(
          'سيتم إنشاء مسودة لكل قراءة مؤكدة. لا ينشئ هذا الإجراء دينًا أو تحصيلًا ماليًا.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('توليد المسودات')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.repository.generateDrafts(workspace.period.id);
      await _loadPeriods();
      _message('تم توليد أو تثبيت المسودات بدون أي أثر على الذمم والتحصيل.');
    });
  }

  Future<void> _toggleReview(BillingDraft draft) async {
    if (!widget.online) {
      _message('تغيير حالة المراجعة يحتاج اتصالًا بالسيرفر.');
      return;
    }
    await _run(() async {
      await widget.repository.updateDraftStatus(
        draft.id,
        draft.isReviewed ? 'draft' : 'reviewed',
      );
      await _loadWorkspace();
      _message(draft.isReviewed ? 'أعيدت المسودة إلى قيد المراجعة.' : 'تم تعليم المسودة كمراجعة.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on DioException catch (error) {
      _message(_apiMessage(error));
    } catch (error) {
      _message(error.toString());
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
    return widget.online ? 'تعذر تنفيذ عملية الفوترة الآن.' : 'لا يوجد اتصال. تم عرض آخر نسخة مؤكدة محليًا.';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التسعير ومسودات الفواتير'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _working ? null : _loadPeriods,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPeriods,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _ConnectionBanner(online: widget.online),
            const SizedBox(height: 12),
            const _StageNotice(),
            const SizedBox(height: 16),
            _periodSelector(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(42),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selectedPeriod == null)
              const _EmptyCard(text: 'لا توجد دورات قراءة بعد. افتح دورة وسجل القراءات ثم اقفلها.')
            else if (_workspace == null)
              const _EmptyCard(text: 'تعذر تحميل مساحة الفوترة لهذه الدورة.')
            else ..._workspaceBody(_workspace!),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    if (_periods.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      value: _selectedPeriod?.id,
      decoration: const InputDecoration(
        labelText: 'دورة القراءة',
        prefixIcon: Icon(Icons.calendar_month_outlined),
      ),
      items: _periods
          .map(
            (period) => DropdownMenuItem(
              value: period.id,
              child: Text('${period.periodKey} • ${period.isLocked ? 'مقفلة' : 'مفتوحة'}'),
            ),
          )
          .toList(growable: false),
      onChanged: _working
          ? null
          : (id) {
              final period = _periods.firstWhere((item) => item.id == id);
              _selectPeriod(period);
            },
    );
  }

  List<Widget> _workspaceBody(BillingWorkspace workspace) => [
        _SummaryPanel(workspace: workspace),
        const SizedBox(height: 18),
        _SectionTitle(title: 'تسعيرات المولدات', icon: Icons.price_change_outlined),
        const SizedBox(height: 8),
        if (workspace.generators.isEmpty)
          const _EmptyCard(text: 'لا توجد قراءات مؤكدة مرتبطة بمولدات في هذه الدورة.')
        else
          ...workspace.generators.map(
            (item) => _TariffCard(
              item: item,
              enabled: !_working && workspace.period.isLocked,
              onEdit: () => _editTariff(item),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _working ? null : _generate,
            icon: _working
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long_outlined),
            label: Text(workspace.summary.draftCount == 0 ? 'توليد مسودات الفواتير' : 'تثبيت المسودات الموجودة'),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: 'مسودات الفواتير', icon: Icons.fact_check_outlined),
        const SizedBox(height: 8),
        if (workspace.drafts.isEmpty)
          const _EmptyCard(text: 'لم تُولد مسودات لهذه الدورة بعد.')
        else
          ...workspace.drafts.map(
            (draft) => _DraftCard(
              draft: draft,
              enabled: !_working,
              onToggleReview: () => _toggleReview(draft),
            ),
          ),
      ];
}
