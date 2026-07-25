part of 'domain_management_page.dart';

final class _SubscribersTab extends StatefulWidget {
  const _SubscribersTab({required this.repository, required this.tenantId});
  final DomainRepository repository;
  final String tenantId;

  @override
  State<_SubscribersTab> createState() => _SubscribersTabState();
}

final class _SubscribersTabState extends State<_SubscribersTab> {
  List<GeneratorSubscriber> _items = const [];
  List<GeneratorUnit> _generators = const [];
  List<GeneratorRoute> _routes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final subscribers = await widget.repository.listSubscribers(widget.tenantId);
      final generators = await widget.repository.listGenerators(widget.tenantId);
      final routes = await widget.repository.listRoutes(widget.tenantId);
      if (mounted) {
        setState(() {
          _items = subscribers.items;
          _generators = generators.items;
          _routes = routes.items;
        });
      }
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([GeneratorSubscriber? current]) async {
    if (_generators.isEmpty) {
      _message(context, 'أضف مولدة أولًا قبل إضافة المشتركين.');
      return;
    }
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SubscriberDialog(
        current: current,
        generators: _generators,
        routes: _routes,
      ),
    );
    if (input == null || !mounted) return;
    try {
      await widget.repository.saveSubscriber(id: current?.id, input: input);
      _message(context, current == null ? 'تمت إضافة المشترك.' : 'تم تعديل المشترك.');
      await _load();
    } on DioException catch (error) {
      _message(context, _apiMessage(error));
    }
  }

  Future<void> _status(GeneratorSubscriber item, String status) async {
    try {
      await widget.repository.setSubscriberStatus(item.id, status);
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
      addLabel: 'إضافة مشترك',
      emptyLabel: 'لا يوجد مشتركون مسجلون.',
      children: _items
          .map(
            (item) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item.fullName),
                subtitle: Text(
                  '${item.accountNumber} • ${item.phone ?? 'بدون هاتف'}\n'
                  '${item.generator.name} • ${item.route?.name ?? 'بدون مسار'} • ${item.contractedAmperes} أمبير\n'
                  '${_statusLabel(item.status)}',
                ),
                isThreeLine: true,
                onTap: () => _edit(item),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? _edit(item) : _status(item, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'active', child: Text('تفعيل')),
                    PopupMenuItem(value: 'suspended', child: Text('تعليق')),
                    PopupMenuItem(value: 'disconnected', child: Text('قطع')),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

