part of 'domain_management_page.dart';

final class _DomainListShell extends StatelessWidget {
  const _DomainListShell({
    required this.loading,
    required this.onRefresh,
    required this.onAdd,
    required this.addLabel,
    required this.emptyLabel,
    required this.children,
  });

  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final String addLabel;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.40)),
            ),
            child: const Text(
              'Stage03 يثبت بيانات التشغيل والتخصيص فقط. القراءات والجباية والفواتير ما زالت مقفلة.',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(42),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(42),
              child: Center(child: Text(emptyLabel)),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

