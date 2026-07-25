part of 'owner_invoices_page.dart';

final class _StageNotice extends StatelessWidget {
  const _StageNotice({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.orange.withValues(alpha: 0.42)),
        ),
        child: Text(
          online
              ? 'Stage06 يعتمد الفاتورة ويفتح الذمة فقط. لا قبض، لا وصولات، ولا تأثير على الصندوق.'
              : 'بدون إنترنت — تعرض آخر بيانات مؤكدة. اعتماد الفاتورة يحتاج اتصالًا بالسيرفر.',
        ),
      );
}

final class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.invoiceSummary, required this.debtSummary});
  final InvoiceSummary invoiceSummary;
  final DebtSummary debtSummary;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Metric(label: 'الفواتير', value: '${invoiceSummary.invoiceCount}'),
          _Metric(label: 'مجموع الفواتير', value: _money(invoiceSummary.totalAmountIqd)),
          _Metric(label: 'الذمم المفتوحة', value: '${invoiceSummary.openDebtCount}'),
          _Metric(label: 'إجمالي المتبقي', value: _money(debtSummary.totalReceivablesIqd)),
        ],
      );
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 165,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.teal)),
        ]),
      );
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppTheme.teal),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
      ]);
}

final class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.draft, required this.loading, required this.onApprove});
  final BillingDraft draft;
  final bool loading;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(draft.subscriberName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            Text('${draft.accountNumber} • ${draft.generatorName}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('المبلغ: ${_money(draft.amountIqd)}'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onApprove,
                icon: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified_outlined),
                label: const Text('اعتماد الفاتورة وفتح الذمة'),
              ),
            ),
          ]),
        ),
      );
}

final class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final ApprovedInvoice invoice;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: AppTheme.teal, child: Icon(Icons.receipt, color: Colors.black)),
          title: Text(invoice.subscriberName, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${invoice.invoiceNumber}\n${invoice.accountNumber} • ${invoice.generatorName}\nالمبلغ ${_money(invoice.amountIqd)} • المتبقي ${_money(invoice.remainingAmountIqd)}'),
          isThreeLine: true,
          trailing: const Chip(label: Text('معتمدة')),
        ),
      );
}

final class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.entry});
  final DebtLedgerEntry entry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.orange),
          title: Text(entry.subscriberName, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${entry.invoiceNumber ?? 'بدون فاتورة'} • ${entry.accountNumber}\nمدين ${_money(entry.debitIqd)} • الرصيد بعد القيد ${_money(entry.balanceAfterIqd)}'),
          isThreeLine: true,
        ),
      );
}

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );
}
