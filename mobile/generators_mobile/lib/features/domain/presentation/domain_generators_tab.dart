part of 'domain_management_page.dart';

final class _GeneratorsTab extends StatefulWidget {
  const _GeneratorsTab({required this.repository, required this.tenantId});
  final DomainRepository repository;
  final String tenantId;

  @override
  State<_GeneratorsTab> createState() => _GeneratorsTabState();
}

final class _GeneratorsTabState extends State<_GeneratorsTab> {
  List<GeneratorUnit> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.repository.listGenerators(widget.tenantId);
      if (mounted) setState(() => _items = result.items);
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([GeneratorUnit? current]) async {
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _GeneratorDialog(current: current),
    );
    if (input == null || !mounted) return;
    try {
      await widget.repository.saveGenerator(id: current?.id, input: input);
      _message(context, current == null ? 'تمت إضافة المولدة.' : 'تم تعديل المولدة.');
      await _load();
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    }
  }

  Future<void> _status(GeneratorUnit item, String status) async {
    try {
      await widget.repository.setGeneratorStatus(item.id, status);
      await _load();
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DomainListShell(
      loading: _loading,
      onRefresh: _load,
      onAdd: () => _edit(),
      addLabel: 'إضافة مولدة',
      emptyLabel: 'لا توجد مولدات مسجلة.',
      children: _items
          .map(
            (item) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.teal,
                  child: Icon(Icons.electrical_services, color: Colors.black),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.code} • ${item.area ?? 'بدون منطقة'}\n'
                  '${item.routeCount} مسار • ${item.subscriberCount} مشترك • ${_statusLabel(item.status)}',
                ),
                isThreeLine: true,
                onTap: () => _edit(item),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? _edit(item) : _status(item, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'active', child: Text('تفعيل')),
                    PopupMenuItem(value: 'maintenance', child: Text('صيانة')),
                    PopupMenuItem(value: 'inactive', child: Text('إيقاف')),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

