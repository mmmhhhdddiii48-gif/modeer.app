part of 'domain_management_page.dart';

final class _RouteDialog extends StatefulWidget {
  const _RouteDialog({required this.generators, this.current});
  final List<GeneratorUnit> generators;
  final GeneratorRoute? current;

  @override
  State<_RouteDialog> createState() => _RouteDialogState();
}

final class _RouteDialogState extends State<_RouteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _area;
  String? _generatorId;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.current?.code);
    _name = TextEditingController(text: widget.current?.name);
    _area = TextEditingController(text: widget.current?.area);
    _generatorId = widget.current?.generator?.id;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.current == null ? 'إضافة مسار' : 'تعديل المسار'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(_code, 'رمز المسار'),
                const SizedBox(height: 10),
                _requiredField(_name, 'اسم المسار'),
                const SizedBox(height: 10),
                TextField(controller: _area, decoration: const InputDecoration(labelText: 'المنطقة')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _generatorId,
                  decoration: const InputDecoration(labelText: 'المولدة المرتبطة'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('بدون ربط')),
                    ...widget.generators.map(
                      (item) => DropdownMenuItem<String?>(value: item.id, child: Text(item.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _generatorId = value),
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
                'code': _code.text.trim(),
                'name': _name.text.trim(),
                'area': _nullable(_area.text),
                'generator_id': _generatorId,
              });
            },
            child: const Text('حفظ'),
          ),
        ],
      );

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _area.dispose();
    super.dispose();
  }
}

