import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/reading_repository.dart';
import '../domain/meter_reading_models.dart';

final class CollectorReadingsPage extends StatefulWidget {
  const CollectorReadingsPage({
    required this.repository,
    required this.tenantId,
    required this.collectorId,
    required this.online,
    required this.onManualSync,
    super.key,
  });

  final ReadingRepository repository;
  final String tenantId;
  final String collectorId;
  final bool online;
  final Future<void> Function() onManualSync;

  @override
  State<CollectorReadingsPage> createState() => _CollectorReadingsPageState();
}

final class _CollectorReadingsPageState extends State<CollectorReadingsPage> {
  CollectorReadingContext _context = const CollectorReadingContext(
    period: null,
    subscribers: [],
    readingEnabled: false,
  );
  Map<String, LocalMeterReading> _localBySubscriber = const {};
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final context = await widget.repository.getCollectorContext(
        tenantId: widget.tenantId,
        collectorId: widget.collectorId,
      );
      final period = context.period;
      final local = period == null
          ? const <LocalMeterReading>[]
          : await widget.repository.listLocalReadings(
              tenantId: widget.tenantId,
              periodId: period.id,
            );
      if (!mounted) return;
      setState(() {
        _context = context;
        _localBySubscriber = {for (final item in local) item.subscriberId: item};
      });
    } on DioException catch (error) {
      _message(_apiMessage(error));
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await widget.onManualSync();
      await _load();
      _message('اكتملت محاولة مزامنة القراءات.');
    } catch (_) {
      _message('تعذرت المزامنة الآن، وستبقى القراءات محفوظة محليًا.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _record(ReadingSubscriber subscriber) async {
    final period = _context.period;
    if (period == null || !period.isOpen) return;
    final draft = await showModalBottomSheet<_ReadingDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReadingSheet(subscriber: subscriber),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.repository.queueMeterReading(
        tenantId: widget.tenantId,
        period: period,
        subscriber: subscriber,
        currentValue: draft.currentValue,
        note: draft.note,
      );
      if (widget.online) await widget.onManualSync();
      await _load();
      _message(widget.online
          ? 'تم حفظ القراءة ومحاولة مزامنتها.'
          : 'تم حفظ القراءة محليًا وستُزامن عند رجوع الإنترنت.');
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['message']?.toString() ?? 'تعذر تحميل القراءات.';
    }
    return 'تعذر تحميل القراءات الآن.';
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final period = _context.period;
    return Scaffold(
      appBar: AppBar(
        title: const Text('قراءات العدادات'),
        actions: [
          IconButton(
            tooltip: 'مزامنة الآن',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _StatusStrip(online: widget.online),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (period == null)
              const _InfoCard(
                icon: Icons.event_busy_outlined,
                text: 'لا توجد دورة قراءة مفتوحة حاليًا. صاحب المولدة يفتح الدورة الشهرية.',
              )
            else ...[
              _PeriodCard(period: period),
              const SizedBox(height: 12),
              Text(
                'المشتركون المكلف بهم (${_context.subscribers.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (_context.subscribers.isEmpty)
                const _InfoCard(icon: Icons.people_outline, text: 'لا يوجد مشتركون مكلف بهم ضمن هذه الدورة.')
              else
                ..._context.subscribers.map(_subscriberCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subscriberCard(ReadingSubscriber subscriber) {
    final local = _localBySubscriber[subscriber.id];
    final serverDone = subscriber.serverCurrentValue != null;
    final disabled = serverDone || local != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.teal,
                  child: Icon(Icons.speed_outlined, color: Colors.black),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subscriber.fullName, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('${subscriber.accountNumber} • ${subscriber.meterNumber ?? 'بدون رقم عداد'}'),
                      Text('${subscriber.generatorName} • ${subscriber.routeName ?? 'بدون مسار'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ValueBox(label: 'السابقة', value: subscriber.previousValue)),
                const SizedBox(width: 8),
                Expanded(
                  child: _ValueBox(
                    label: 'الحالية',
                    value: local?.currentValue ?? subscriber.serverCurrentValue,
                  ),
                ),
              ],
            ),
            if (local != null) ...[
              const SizedBox(height: 10),
              _LocalStatus(reading: local),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: disabled ? null : () => _record(subscriber),
              icon: Icon(serverDone || local?.isSynced == true ? Icons.check_circle_outline : Icons.edit_note),
              label: Text(serverDone
                  ? 'قراءة مؤكدة'
                  : local == null
                      ? 'تسجيل القراءة'
                      : 'الحركة محفوظة محليًا'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReadingDraft {
  const _ReadingDraft(this.currentValue, this.note);
  final double currentValue;
  final String? note;
}

final class _ReadingSheet extends StatefulWidget {
  const _ReadingSheet({required this.subscriber});
  final ReadingSubscriber subscriber;
  @override
  State<_ReadingSheet> createState() => _ReadingSheetState();
}

final class _ReadingSheetState extends State<_ReadingSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.subscriber.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('القراءة السابقة: ${_format(widget.subscriber.previousValue)}'),
            const SizedBox(height: 14),
            TextFormField(
              controller: _current,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'القراءة الحالية', prefixIcon: Icon(Icons.speed)),
              validator: (value) {
                final number = double.tryParse(value?.trim() ?? '');
                if (number == null) return 'أدخل قراءة صحيحة';
                if (number < widget.subscriber.previousValue) return 'لا يمكن أن تقل عن القراءة السابقة';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _ReadingDraft(double.parse(_current.text.trim()), _note.text.trim().isEmpty ? null : _note.text.trim()),
                );
              },
              child: const Text('حفظ القراءة محليًا'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LocalStatus extends StatelessWidget {
  const _LocalStatus({required this.reading});
  final LocalMeterReading reading;
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (reading.status) {
      'synced' => ('تمت المزامنة', AppTheme.teal, Icons.cloud_done_outlined),
      'conflict' => ('يوجد تعارض', AppTheme.orange, Icons.warning_amber_outlined),
      'failed' => ('فشلت المزامنة', Colors.redAccent, Icons.error_outline),
      'sending' => ('جاري الإرسال', Colors.lightBlueAccent, Icons.cloud_upload_outlined),
      _ => ('بانتظار المزامنة', Colors.white70, Icons.schedule_outlined),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Expanded(child: Text(reading.errorMessage == null ? label : '$label — ${reading.errorMessage}')),
        ],
      ),
    );
  }
}

final class _ValueBox extends StatelessWidget {
  const _ValueBox({required this.label, required this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text(value == null ? '—' : _format(value!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

final class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.period});
  final ReadingPeriod period;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.teal.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.teal.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(period.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${period.startsAt} — ${period.endsAt}'),
            const Text('القرار المالي يعتمد وقت السيرفر؛ وقت الجهاز محفوظ للمعلومة فقط.'),
          ],
        ),
      );
}

final class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: [Icon(icon, size: 38, color: AppTheme.orange), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center)]),
      );
}

final class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(online ? 'متصل — المزامنة التلقائية واليدوية متاحة' : 'بدون إنترنت — التسجيل المحلي متاح'),
    );
  }
}

String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(3);
