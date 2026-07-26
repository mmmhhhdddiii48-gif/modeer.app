part of 'owner_home_page.dart';

final class _CollectorDraft {
  const _CollectorDraft({
    required this.fullName,
    required this.username,
    required this.phone,
    this.password,
  });

  final String fullName;
  final String username;
  final String? phone;
  final String? password;
}

final class _CollectorFormSheet extends StatefulWidget {
  const _CollectorFormSheet({this.collector});
  final CollectorAccount? collector;

  @override
  State<_CollectorFormSheet> createState() => _CollectorFormSheetState();
}

final class _CollectorFormSheetState extends State<_CollectorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  bool _obscure = true;

  bool get _isEdit => widget.collector != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.collector?.fullName ?? '');
    _usernameController = TextEditingController(text: widget.collector?.username ?? '');
    _phoneController = TextEditingController(text: widget.collector?.phone ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'تعديل بيانات الجابي' : 'إنشاء حساب جابي', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الجابي'),
                validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم الجابي' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم المستخدم' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف — اختياري'),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 8 ? 'كلمة المرور يجب ألا تقل عن 8 أحرف' : null,
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _CollectorDraft(
                      fullName: _nameController.text.trim(),
                      username: _usernameController.text.trim(),
                      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                      password: _isEdit ? null : _passwordController.text,
                    ),
                  );
                },
                child: Text(_isEdit ? 'حفظ التعديل' : 'إنشاء الحساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

final class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({required this.initial});
  final List<String> initial;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

final class _PermissionsDialogState extends State<_PermissionsDialog> {
  static const _options = <String, String>{
    'assignments.read': 'مشاهدة التخصيصات',
    'subscribers.assigned.read': 'مشاهدة المشتركين المكلف بهم',
    'readings.create': 'تسجيل قراءة العداد مستقبلًا',
    'collections.create': 'تسجيل الجباية مستقبلًا',
    'collections.own.read': 'مشاهدة سجل حركاته',
    'receipts.create': 'إصدار وصل مستقبلًا',
    'sync.own.read': 'مشاهدة حالة مزامنته',
  };

  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('صلاحيات الجابي'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: _options.entries.map((entry) {
            return CheckboxListTile(
              value: _selected.contains(entry.key),
              title: Text(entry.value),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(entry.key);
                  } else {
                    _selected.remove(entry.key);
                  }
                });
              },
            );
          }).toList(growable: false),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected.toList(growable: false)),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

final class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.collectorName});
  final String collectorName;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

final class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تغيير كلمة مرور ${widget.collectorName}'),
      content: TextField(
        controller: _controller,
        obscureText: _obscure,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'كلمة المرور الجديدة',
          helperText: '8 أحرف على الأقل',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _controller.text.length < 8 ? null : () => Navigator.pop(context, _controller.text),
          child: const Text('تغيير'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
