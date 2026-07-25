part of 'domain_management_page.dart';

final class _RoutesTab extends StatefulWidget {
  const _RoutesTab({required this.repository, required this.tenantId});
  final DomainRepository repository;
  final String tenantId;

  @override
  State<_RoutesTab> createState() => _RoutesTabState();
}

final class _RoutesTabState extends State<_RoutesTab> {
  List<GeneratorRoute> _items = const [];
  List<GeneratorUnit> _generators = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final routes = await widget.repository.listRoutes(widget.tenantId);
      final generators = await widget.repository.listGenerators(widget.tenantId);
      if (mounted) {
        setState(() {
          _items = routes.items;
          _generators = generators.items;
        });
      }
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([GeneratorRoute? current]) async {
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RouteDialog(current: current, generators: _generators),
    );
    if (input == null || !mounted) return;
    try {
      await widget.repository.saveRoute(id: current?.id, input: input);
      _message(context, current == null ? 'تمت إضافة المسار.' : 'تم تعديل المسار.');
      await _load();
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    }
  }

  Future<void> _status(GeneratorRoute item, String status) async {
    try {
      await widget.repository.setRouteStatus(item.id, status);
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
      addLabel: 'إضافة مسار',
      emptyLabel: 'لا توجد مسارات مسجلة.',
      children: _items
          .map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.route_outlined, color: AppTheme.teal),
                title: Text(item.name),
                subtitle: Text(
                  '${item.code} • ${item.area ?? 'بدون منطقة'}\n'
                  '${item.generator?.name ?? 'غير مربوط بمولدة'} • ${item.subscriberCount} مشترك • ${_statusLabel(item.status)}',
                ),
                isThreeLine: true,
                onTap: () => _edit(item),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? _edit(item) : _status(item, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'active', child: Text('تفعيل')),
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

