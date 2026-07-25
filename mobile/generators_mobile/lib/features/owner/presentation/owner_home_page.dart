import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../data/collector_repository.dart';
import '../domain/collector_account.dart';
import 'collector_assignments_page.dart';

final class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({
    required this.session,
    required this.repository,
    required this.online,
    required this.onLogout,
    required this.onManualSync,
    super.key,
  });

  final AuthSession session;
  final CollectorRepository repository;
  final bool online;
  final Future<void> Function() onLogout;
  final Future<void> Function() onManualSync;

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

final class _OwnerHomePageState extends State<OwnerHomePage> {
  List<CollectorAccount> _collectors = const [];
  CollectorUsage _usage = const CollectorUsage(
    limit: 0,
    usedSlots: 0,
    remainingSlots: 0,
    activeCount: 0,
    suspendedCount: 0,
    disabledCount: 0,
  );
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.repository.listCollectors(widget.session.tenantId);
      if (!mounted) return;
      setState(() {
        _collectors = result.collectors;
        _usage = result.usage;
      });
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await widget.onManualSync();
      if (!mounted) return;
      _showMessage('اكتملت محاولة المزامنة الآمنة.');
    } catch (_) {
      _showMessage('تعذرت المزامنة الآن، وستبقى الحركات المحلية محفوظة.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _createCollector() async {
    if (_usage.remainingSlots <= 0) {
      _showMessage('وصلت إلى الحد المسموح للجباة في الاشتراك.');
      return;
    }
    final draft = await showModalBottomSheet<_CollectorDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _CollectorFormSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.repository.createCollector(
        fullName: draft.fullName,
        username: draft.username,
        phone: draft.phone,
        password: draft.password!,
      );
      _showMessage('تم إنشاء حساب الجابي.');
      await _load();
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _editCollector(CollectorAccount collector) async {
    final draft = await showModalBottomSheet<_CollectorDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CollectorFormSheet(collector: collector),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.repository.updateCollectorProfile(
        collectorId: collector.id,
        fullName: draft.fullName,
        username: draft.username,
        phone: draft.phone,
      );
      _showMessage('تم تعديل بيانات الجابي.');
      await _load();
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _changeStatus(CollectorAccount collector, String status) async {
    try {
      await widget.repository.updateStatus(collector.id, status);
      _showMessage('تم تحديث حالة الجابي.');
      await _load();
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _editPermissions(CollectorAccount collector) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _PermissionsDialog(initial: collector.permissions),
    );
    if (selected == null || !mounted) return;
    try {
      await widget.repository.updatePermissions(collector.id, selected);
      _showMessage('تم حفظ الصلاحيات وإبطال الجلسات القديمة للجابي.');
      await _load();
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _resetPassword(CollectorAccount collector) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordResetDialog(collectorName: collector.fullName),
    );
    if (password == null || !mounted) return;
    try {
      await widget.repository.resetPassword(collector.id, password);
      _showMessage('تم تغيير كلمة المرور وإبطال جلسات الجابي القديمة.');
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    }
  }

  Future<void> _openAssignments(CollectorAccount collector) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectorAssignmentsPage(
          repository: widget.repository,
          tenantId: widget.session.tenantId,
          collector: collector,
        ),
      ),
    );
    await _load();
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'تعذر تنفيذ العملية الآن.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الجباة'),
        actions: [
          IconButton(
            tooltip: 'مزامنة الآن',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createCollector,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة جابي'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _ConnectionStrip(online: widget.online),
            const SizedBox(height: 12),
            _OwnerHeader(session: widget.session),
            const SizedBox(height: 14),
            _UsagePanel(usage: _usage),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.42)),
              ),
              child: const Text(
                'Stage02 يفعّل إدارة حسابات الجباة والتخصيصات فقط. القراءات والجبايات والفواتير المالية ما زالت مقفلة.',
              ),
            ),
            const SizedBox(height: 18),
            Text('الجباة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_collectors.isEmpty)
              const _EmptyCollectors()
            else
              ..._collectors.map(
                (collector) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CollectorCard(
                    collector: collector,
                    onEdit: () => _editCollector(collector),
                    onPermissions: () => _editPermissions(collector),
                    onResetPassword: () => _resetPassword(collector),
                    onAssignments: () => _openAssignments(collector),
                    onStatus: (status) => _changeStatus(collector, status),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 18, color: color),
          const SizedBox(width: 7),
          Text(online ? 'متصل — المزامنة متاحة' : 'بدون إنترنت — البيانات المحلية محفوظة'),
        ],
      ),
    );
  }
}

final class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.teal,
            child: Icon(Icons.electrical_services, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(session.tenantName, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _UsagePanel extends StatelessWidget {
  const _UsagePanel({required this.usage});
  final CollectorUsage usage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _UsageChip(label: 'المسموح', value: usage.limit, icon: Icons.group_outlined),
        _UsageChip(label: 'المستخدم', value: usage.usedSlots, icon: Icons.badge_outlined),
        _UsageChip(label: 'المتبقي', value: usage.remainingSlots, icon: Icons.person_add_alt),
        _UsageChip(label: 'الفعال', value: usage.activeCount, icon: Icons.check_circle_outline),
      ],
    );
  }
}

final class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.teal),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

final class _CollectorCard extends StatelessWidget {
  const _CollectorCard({
    required this.collector,
    required this.onEdit,
    required this.onPermissions,
    required this.onResetPassword,
    required this.onAssignments,
    required this.onStatus,
  });

  final CollectorAccount collector;
  final VoidCallback onEdit;
  final VoidCallback onPermissions;
  final VoidCallback onResetPassword;
  final VoidCallback onAssignments;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(collector.status).withValues(alpha: 0.16),
                  child: Icon(Icons.person_outline, color: _statusColor(collector.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(collector.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('@${collector.username}${collector.phone == null ? '' : ' • ${collector.phone}'}', style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'permissions':
                        onPermissions();
                        break;
                      case 'password':
                        onResetPassword();
                        break;
                      case 'assignments':
                        onAssignments();
                        break;
                      case 'active':
                      case 'suspended':
                      case 'disabled':
                        onStatus(value);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                    PopupMenuItem(value: 'permissions', child: Text('الصلاحيات')),
                    PopupMenuItem(value: 'assignments', child: Text('التخصيصات')),
                    PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'active', child: Text('تفعيل الحساب')),
                    PopupMenuItem(value: 'suspended', child: Text('إيقاف مؤقت')),
                    PopupMenuItem(value: 'disabled', child: Text('تعطيل الحساب')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusBadge(status: collector.status),
                const SizedBox(width: 8),
                Text('التخصيصات: ${collector.assignmentCount}'),
                const Spacer(),
                Text(
                  collector.lastServerSyncAt == null
                      ? 'لا توجد مزامنة'
                      : 'آخر مزامنة: ${_formatDate(collector.lastServerSyncAt!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) => switch (status) {
        'active' => AppTheme.teal,
        'suspended' => AppTheme.orange,
        _ => Colors.redAccent,
      };

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppTheme.teal,
      'suspended' => AppTheme.orange,
      _ => Colors.redAccent,
    };
    final label = switch (status) {
      'active' => 'فعال',
      'suspended' => 'موقوف مؤقتًا',
      _ => 'معطل',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}

final class _EmptyCollectors extends StatelessWidget {
  const _EmptyCollectors();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_off_outlined, size: 44, color: Colors.white38),
          SizedBox(height: 10),
          Text('لا توجد حسابات جباة حتى الآن.'),
        ],
      ),
    );
  }
}

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
