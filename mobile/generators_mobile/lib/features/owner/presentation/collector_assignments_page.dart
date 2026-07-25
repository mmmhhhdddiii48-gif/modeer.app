import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/collector_repository.dart';
import '../domain/collector_account.dart';

final class CollectorAssignmentsPage extends StatefulWidget {
  const CollectorAssignmentsPage({
    required this.repository,
    required this.tenantId,
    required this.collector,
    super.key,
  });

  final CollectorRepository repository;
  final String tenantId;
  final CollectorAccount collector;

  @override
  State<CollectorAssignmentsPage> createState() => _CollectorAssignmentsPageState();
}

final class _CollectorAssignmentsPageState extends State<CollectorAssignmentsPage> {
  List<CollectorAssignment> _assignments = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final assignments = await widget.repository.getAssignments(
        tenantId: widget.tenantId,
        collectorId: widget.collector.id,
      );
      if (!mounted) return;
      setState(() => _assignments = assignments);
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAssignment() async {
    final assignment = await showDialog<CollectorAssignment>(
      context: context,
      builder: (context) => const _AssignmentDialog(),
    );
    if (assignment == null || !mounted) return;
    final duplicate = _assignments.any(
      (item) => item.type == assignment.type && item.targetId == assignment.targetId,
    );
    if (duplicate) {
      _showMessage('هذا التخصيص موجود بالفعل.');
      return;
    }
    setState(() => _assignments = [..._assignments, assignment]);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.replaceAssignments(
        tenantId: widget.tenantId,
        collectorId: widget.collector.id,
        assignments: _assignments,
      );
      if (!mounted) return;
      _showMessage('تم حفظ تخصيصات الجابي.');
      await _load();
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      appBar: AppBar(title: Text('تخصيصات ${widget.collector.fullName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAssignment,
        icon: const Icon(Icons.add),
        label: const Text('إضافة تخصيص'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.orange.withValues(alpha: 0.45)),
                  ),
                  child: const Text(
                    'Stage02: هذه مراجع تخصيص للمولدات أو المشتركين أو المسارات فقط. لا تنفذ قراءة أو جباية مالية.',
                  ),
                ),
                Expanded(
                  child: _assignments.isEmpty
                      ? const Center(child: Text('لا توجد تخصيصات لهذا الجابي.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _assignments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final assignment = _assignments[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(_iconForType(assignment.type), color: AppTheme.teal),
                                title: Text(assignment.label?.isNotEmpty == true ? assignment.label! : assignment.targetId),
                                subtitle: Text('${_labelForType(assignment.type)} • ${assignment.targetId}'),
                                trailing: IconButton(
                                  tooltip: 'إزالة',
                                  onPressed: () => setState(
                                    () => _assignments = [
                                      for (var i = 0; i < _assignments.length; i++)
                                        if (i != index) _assignments[i],
                                    ],
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('حفظ التخصيصات'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static IconData _iconForType(String type) => switch (type) {
        'generator' => Icons.electrical_services_outlined,
        'subscriber' => Icons.person_outline,
        _ => Icons.route_outlined,
      };

  static String _labelForType(String type) => switch (type) {
        'generator' => 'مولدة',
        'subscriber' => 'مشترك',
        _ => 'مسار',
      };
}

final class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog();

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

final class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _labelController = TextEditingController();
  String _type = 'route';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة تخصيص'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع التخصيص'),
                items: const [
                  DropdownMenuItem(value: 'route', child: Text('مسار')),
                  DropdownMenuItem(value: 'generator', child: Text('مولدة')),
                  DropdownMenuItem(value: 'subscriber', child: Text('مشترك')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'route'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetController,
                decoration: const InputDecoration(labelText: 'المعرّف المرجعي'),
                validator: (value) => value == null || value.trim().isEmpty ? 'أدخل المعرّف المرجعي' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'الاسم الظاهر'),
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
            Navigator.pop(
              context,
              CollectorAssignment(
                id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                type: _type,
                targetId: _targetController.text.trim(),
                label: _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
                metadata: const {},
              ),
            );
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    _labelController.dispose();
    super.dispose();
  }
}
