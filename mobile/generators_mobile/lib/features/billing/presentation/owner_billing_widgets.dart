part of 'owner_billing_page.dart';

final class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.workspace});
  final BillingWorkspace workspace;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(workspace.period.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(label: 'القراءات', value: workspace.summary.readingCount.toString()),
                _Pill(label: 'التسعيرات الناقصة', value: workspace.summary.missingTariffCount.toString()),
                _Pill(label: 'المسودات', value: workspace.summary.draftCount.toString()),
                _Pill(label: 'المراجعة', value: workspace.summary.reviewedCount.toString()),
              ],
            ),
            const Divider(height: 24),
            Text(
              'المجموع التقديري: ${_iqd(workspace.summary.totalAmountIqd)} د.ع',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.teal),
            ),
          ],
        ),
      );
}

final class _TariffCard extends StatelessWidget {
  const _TariffCard({required this.item, required this.enabled, required this.onEdit});
  final BillingGeneratorTariff item;
  final bool enabled;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tariff = item.tariff;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.teal,
          child: Icon(Icons.electrical_services, color: Colors.black),
        ),
        title: Text(item.generatorName),
        subtitle: Text(
          tariff == null
              ? '${item.generatorCode} • ${item.readingCount} قراءة • بدون تسعيرة'
              : '${item.generatorCode} • ${item.readingCount} قراءة\n'
                  '${_iqd(tariff.pricePerAmpIqd)} د.ع/أمبير + ${_iqd(tariff.fixedFeeIqd)} د.ع رسم ثابت',
        ),
        isThreeLine: tariff != null,
        trailing: IconButton(
          tooltip: item.tariffLocked ? 'التسعيرة مقفلة' : 'تعديل التسعيرة',
          onPressed: enabled && !item.tariffLocked ? onEdit : null,
          icon: Icon(item.tariffLocked ? Icons.lock_outline : Icons.edit_outlined),
        ),
      ),
    );
  }
}

final class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.enabled, required this.onToggleReview});
  final BillingDraft draft;
  final bool enabled;
  final VoidCallback onToggleReview;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(draft.subscriberName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                  _StatusBadge(reviewed: draft.isReviewed),
                ],
              ),
              const SizedBox(height: 5),
              Text('${draft.accountNumber} • ${draft.generatorName} • ${draft.contractedAmperes} أمبير'),
              const SizedBox(height: 7),
              Text(
                '${draft.contractedAmperes} × ${_iqd(draft.pricePerAmpIqd)} + ${_iqd(draft.fixedFeeIqd)} = ${_iqd(draft.amountIqd)} د.ع',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.teal),
              ),
              Text(
                'القراءة: ${draft.previousValue} ← ${draft.currentValue} • الاستهلاك ${draft.consumption}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: enabled ? onToggleReview : null,
                icon: Icon(draft.isReviewed ? Icons.undo : Icons.check_circle_outline),
                label: Text(draft.isReviewed ? 'إرجاع إلى قيد المراجعة' : 'تعليم كمراجعة'),
              ),
            ],
          ),
        ),
      );
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.reviewed});
  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final color = reviewed ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(reviewed ? 'مراجعة' : 'مسودة', style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

final class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$label: $value'),
      );
}

final class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        online ? 'متصل — تعديل التسعيرات والمراجعة متاح' : 'بدون إنترنت — عرض آخر بيانات مؤكدة فقط',
        textAlign: TextAlign.center,
      ),
    );
  }
}

final class _StageNotice extends StatelessWidget {
  const _StageNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.orange.withValues(alpha: 0.42)),
        ),
        child: const Text(
          'Stage05 ينشئ مسودات حسابية للمراجعة فقط. لا توجد ذمم أو قبض أو وصولات أو تأثير على الصندوق.',
        ),
      );
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTheme.teal),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      );
}

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );
}

String _iqd(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}
