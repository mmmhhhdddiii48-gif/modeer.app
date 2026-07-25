part of 'domain_management_page.dart';

final class _GeneratorDialog extends StatefulWidget {
  const _GeneratorDialog({this.current});
  final GeneratorUnit? current;

  @override
  State<_GeneratorDialog> createState() => _GeneratorDialogState();
}

final class _GeneratorDialogState extends State<_GeneratorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _capacity;
  String _phase = 'unknown';

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _code = TextEditingController(text: current?.code);
    _name = TextEditingController(text: current?.name);
    _area = TextEditingController(text: current?.area);
    _capacity = TextEditingController(text: current?.capacityKva?.toString());
    _phase = current?.phaseType ?? 'unknown';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.current == null ? 'إضافة مولدة' : 'تعديل المولدة'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(_code, 'الرمز'),
                const SizedBox(height: 10),
                _requiredField(_name, 'اسم المولدة'),
                const SizedBox(height: 10),
                TextField(controller: _area, decoration: const InputDecoration(labelText: 'المنطقة')),
                const SizedBox(height: 10),
                TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعة KVA'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _phase,
                  decoration: const InputDecoration(labelText: 'نوع الطور'),
                  items: const [
                    DropdownMenuItem(value: 'unknown', child: Text('غير محدد')),
                    DropdownMenuItem(value: 'single', child: Text('أحادي')),
                    DropdownMenuItem(value: 'three', child: Text('ثلاثي')),
                  ],
                  onChanged: (value) => setState(() => _phase = value ?? 'unknown'),
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
                'capacity_kva': double.tryParse(_capacity.text.trim()),
                'phase_type': _phase,
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
    _capacity.dispose();
    super.dispose();
  }
}

