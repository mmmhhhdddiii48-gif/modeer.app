part of 'domain_management_page.dart';

final class _SubscriberDialog extends StatefulWidget {
  const _SubscriberDialog({
    required this.generators,
    required this.routes,
    this.current,
  });

  final List<GeneratorUnit> generators;
  final List<GeneratorRoute> routes;
  final GeneratorSubscriber? current;

  @override
  State<_SubscriberDialog> createState() => _SubscriberDialogState();
}

final class _SubscriberDialogState extends State<_SubscriberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _account;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _area;
  late final TextEditingController _meter;
  late final TextEditingController _amperes;
  late String _generatorId;
  String? _routeId;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _account = TextEditingController(text: current?.accountNumber);
    _name = TextEditingController(text: current?.fullName);
    _phone = TextEditingController(text: current?.phone);
    _area = TextEditingController(text: current?.area);
    _meter = TextEditingController(text: current?.meterNumber);
    _amperes = TextEditingController(text: current?.contractedAmperes.toString() ?? '0');
    _generatorId = current?.generator.id ?? widget.generators.first.id;
    _routeId = current?.route?.id;
  }

  List<GeneratorRoute> get _availableRoutes => widget.routes
      .where((route) => route.generator == null || route.generator!.id == _generatorId)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.current == null ? 'إضافة مشترك' : 'تعديل المشترك'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(_account, 'رقم الحساب'),
                const SizedBox(height: 10),
                _requiredField(_name, 'اسم المشترك'),
                const SizedBox(height: 10),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 10),
                TextField(controller: _area, decoration: const InputDecoration(labelText: 'المنطقة')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _generatorId,
                  decoration: const InputDecoration(labelText: 'المولدة'),
                  items: widget.generators
                      .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _generatorId = value;
                      if (!_availableRoutes.any((route) => route.id == _routeId)) _routeId = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _routeId,
                  decoration: const InputDecoration(labelText: 'المسار'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('بدون مسار')),
                    ..._availableRoutes.map(
                      (item) => DropdownMenuItem<String?>(value: item.id, child: Text(item.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _routeId = value),
                ),
                const SizedBox(height: 10),
                TextField(controller: _meter, decoration: const InputDecoration(labelText: 'رقم العداد')),
                const SizedBox(height: 10),
                TextField(
                  controller: _amperes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الأمبير المتعاقد عليه'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, {
                'account_number': _account.text.trim(),
                'full_name': _name.text.trim(),
                'phone': _nullable(_phone.text),
                'area': _nullable(_area.text),
                'generator_id': _generatorId,
                'route_id': _routeId,
                'meter_number': _nullable(_meter.text),
                'contracted_amperes': int.tryParse(_amperes.text.trim()) ?? 0,
              });
            },
            child: const Text('حفظ'),
          ),
        ],
      );

  @override
  void dispose() {
    _account.dispose();
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _meter.dispose();
    _amperes.dispose();
    super.dispose();
  }
}

TextFormField _requiredField(TextEditingController controller, String label) => TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
    );

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

String _statusLabel(String status) => switch (status) {
      'active' => 'فعال',
      'inactive' => 'متوقف',
      'maintenance' => 'صيانة',
      'suspended' => 'معلق',
      'disconnected' => 'مقطوع',
      _ => status,
    };

String _apiMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['error'] is Map) {
    final message = (data['error'] as Map)['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return 'تعذر تنفيذ العملية الآن.';
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
