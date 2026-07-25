import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../domain/data/domain_repository.dart';
import '../../domain/domain/generator_domain.dart';
import '../data/collector_repository.dart';
import '../domain/collector_account.dart';

final class CollectorAssignmentsPage extends StatefulWidget {
  const CollectorAssignmentsPage({
    required this.repository,
    required this.domainRepository,
    required this.tenantId,
    required this.collector,
    super.key,
  });

  final CollectorRepository repository;
  final DomainRepository domainRepository;
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
      if (mounted) setState(() => _assignments = assignments);
    } on DioException catch (error) {
      _showMessage(_apiMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAssignment() async {
    final assignment = await showDialog<CollectorAssignment>(
      context: context,
      builder: (_) => _AssignmentCatalogDialog(repository: widget.domainRepository),
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
      _showMessage('تم حفظ تخصيصات الجابي والتحقق منها في السيرفر.');
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
                    'Stage03: لا يمكن كتابة معرف يدوي. اختر مولدة أو مسارًا أو مشتركًا حقيقيًا من نفس المؤسسة.',
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
                                subtitle: Text(_labelForType(assignment.type)),
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

final class _AssignmentCatalogDialog extends StatefulWidget {
  const _AssignmentCatalogDialog({required this.repository});
  final DomainRepository repository;

  @override
  State<_AssignmentCatalogDialog> createState() => _AssignmentCatalogDialogState();
}

final class _AssignmentCatalogDialogState extends State<_AssignmentCatalogDialog> {
  String _type = 'route';
  List<AssignmentCatalogItem> _items = const [];
  AssignmentCatalogItem? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected = null;
    });
    try {
      final items = await widget.repository.assignmentCatalog(_type);
      if (mounted) setState(() => _items = items);
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_apiMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار تخصيص حقيقي'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'نوع التخصيص'),
              items: const [
                DropdownMenuItem(value: 'generator', child: Text('مولدة')),
                DropdownMenuItem(value: 'route', child: Text('مسار')),
                DropdownMenuItem(value: 'subscriber', child: Text('مشترك')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('لا توجد سجلات فعالة من هذا النوع.'),
              )
            else
              DropdownButtonFormField<AssignmentCatalogItem>(
                value: _selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'السجل'),
                items: _items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text('${item.label}${item.code == null ? '' : ' • ${item.code}'}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _selected = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(
                    context,
                    CollectorAssignment(
                      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                      type: _selected!.type,
                      targetId: _selected!.id,
                      label: _selected!.label,
                      metadata: const {},
                    ),
                  ),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

String _apiMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['error'] is Map) {
    final message = (data['error'] as Map)['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return 'تعذر تحميل قائمة التخصيصات.';
}
