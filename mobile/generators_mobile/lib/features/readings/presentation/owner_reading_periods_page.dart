import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/reading_repository.dart';
import '../domain/meter_reading_models.dart';

final class OwnerReadingPeriodsPage extends StatefulWidget {
  const OwnerReadingPeriodsPage({
    required this.repository,
    required this.tenantId,
    required this.online,
    super.key,
  });

  final ReadingRepository repository;
  final String tenantId;
  final bool online;

  @override
  State<OwnerReadingPeriodsPage> createState() => _OwnerReadingPeriodsPageState();
}

final class _OwnerReadingPeriodsPageState extends State<OwnerReadingPeriodsPage> {
  List<ReadingPeriod> _periods = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final periods = await widget.repository.getOwnerPeriods(tenantId: widget.tenantId);
      if (mounted) setState(() => _periods = periods);
    } on DioException catch (error) {
      _message(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (!widget.online) {
      _message('فتح دورة قراءة جديدة يحتاج اتصالًا بالسيرفر.');
      return;
    }
    final draft = await showDialog<_PeriodDraft>(
      context: context,
      builder: (_) => const _PeriodDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.repository.createOwnerPeriod(periodKey: draft.periodKey, title: draft.title);
      _message('تم فتح دورة القراءة الشهرية.');
      await _load();
    } on DioException catch (error) {
      _message(_apiMessage(error));
    }
  }

  Future<void> _lock(ReadingPeriod period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قفل دورة القراءة'),
        content: const Text('بعد القفل لن يقبل السيرفر قراءات جديدة لهذه الدورة. لا يتم إصدار فواتير في Stage04.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('قفل الدورة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.lockOwnerPeriod(period.id);
      _message('تم قفل دورة القراءة بدون أي أثر مالي.');
      await _load();
    } on DioException catch (error) {
      _message(_apiMessage(error));
    }
  }

  Future<void> _openDetails(ReadingPeriod period) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OwnerPeriodReadingsPage(repository: widget.repository, period: period),
      ),
    );
    await _load();
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['message']?.toString() ?? 'تعذر تنفيذ العملية.';
    }
    return 'تعذر تنفيذ العملية الآن.';
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دورات وقراءات العدادات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('فتح دورة'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.42)),
              ),
              child: const Text('Stage04 يثبت القراءة فقط. قفل الدورة لا ينشئ فاتورة ولا دينًا ولا جباية.'),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (_periods.isEmpty)
              const _Empty(text: 'لا توجد دورات قراءة. افتح أول دورة بصيغة الشهر والسنة.')
            else
              ..._periods.map(
                (period) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(period.isOpen ? Icons.lock_open_outlined : Icons.lock_outline, color: period.isOpen ? AppTheme.teal : AppTheme.orange),
                            const SizedBox(width: 8),
                            Expanded(child: Text(period.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                            Chip(label: Text(period.isOpen ? 'مفتوحة' : 'مقفلة')),
                          ],
                        ),
                        Text('${period.periodKey} • ${period.readingCount}/${period.activeSubscriberCount} قراءة'),
                        Text('${period.startsAt} — ${period.endsAt}'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openDetails(period),
                                icon: const Icon(Icons.list_alt_outlined),
                                label: const Text('عرض القراءات'),
                              ),
                            ),
                            if (period.isOpen) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _lock(period),
                                  icon: const Icon(Icons.lock_outline),
                                  label: const Text('قفل الدورة'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class OwnerPeriodReadingsPage extends StatefulWidget {
  const OwnerPeriodReadingsPage({required this.repository, required this.period, super.key});
  final ReadingRepository repository;
  final ReadingPeriod period;

  @override
  State<OwnerPeriodReadingsPage> createState() => _OwnerPeriodReadingsPageState();
}

final class _OwnerPeriodReadingsPageState extends State<OwnerPeriodReadingsPage> {
  List<OwnerMeterReading> _readings = const [];
  Map<String, dynamic> _summary = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.repository.getOwnerReadings(widget.period.id);
      if (mounted) setState(() {
        _readings = result.readings;
        _summary = result.summary;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.period.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _Summary(summary: _summary),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (_readings.isEmpty)
              const _Empty(text: 'لم تصل قراءات مؤكدة لهذه الدورة بعد.')
            else
              ..._readings.map(
                (reading) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.teal,
                      child: Icon(Icons.speed, color: Colors.black),
                    ),
                    title: Text(reading.subscriberName),
                    subtitle: Text(
                      '${reading.accountNumber} • الجابي: ${reading.collectorName}\n'
                      '${_format(reading.previousValue)} ← ${_format(reading.currentValue)} • الاستهلاك ${_format(reading.consumption)}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _PeriodDraft {
  const _PeriodDraft(this.periodKey, this.title);
  final String periodKey;
  final String? title;
}

final class _PeriodDialog extends StatefulWidget {
  const _PeriodDialog();
  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

final class _PeriodDialogState extends State<_PeriodDialog> {
  final _form = GlobalKey<FormState>();
  final _periodKey = TextEditingController();
  final _title = TextEditingController();
  @override
  void dispose() {
    _periodKey.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('فتح دورة قراءة'),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _periodKey,
                decoration: const InputDecoration(labelText: 'الشهر بصيغة YYYY-MM', hintText: '2026-07'),
                validator: (value) => RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value?.trim() ?? '') ? null : 'اكتب الشهر بصيغة صحيحة',
              ),
              const SizedBox(height: 12),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان اختياري')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(context, _PeriodDraft(_periodKey.text.trim(), _title.text.trim().isEmpty ? null : _title.text.trim()));
            },
            child: const Text('فتح'),
          ),
        ],
      );
}

final class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _SummaryItem(label: 'المقروء', value: summary['reading_count'])),
          const SizedBox(width: 8),
          Expanded(child: _SummaryItem(label: 'المتبقي', value: summary['remaining_count'])),
          const SizedBox(width: 8),
          Expanded(child: _SummaryItem(label: 'الاستهلاك', value: summary['total_consumption'])),
        ],
      );
}

final class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: [Text(value?.toString() ?? '0', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.teal)), Text(label, style: const TextStyle(fontSize: 12))]),
      );
}

final class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
        child: Text(text, textAlign: TextAlign.center),
      );
}

String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(3);
