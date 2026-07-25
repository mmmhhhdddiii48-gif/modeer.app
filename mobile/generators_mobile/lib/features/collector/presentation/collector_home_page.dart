import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../../owner/data/collector_repository.dart';
import '../../owner/domain/collector_account.dart';

final class CollectorHomePage extends StatefulWidget {
  const CollectorHomePage({
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
  State<CollectorHomePage> createState() => _CollectorHomePageState();
}

final class _CollectorHomePageState extends State<CollectorHomePage> {
  List<CollectorAssignment> _assignments = const [];
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
      final assignments = await widget.repository.getOwnAssignments(
        tenantId: widget.session.tenantId,
        collectorId: widget.session.accountId,
      );
      if (!mounted) return;
      setState(() => _assignments = assignments);
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
      _showMessage('اكتملت محاولة المزامنة.');
    } catch (_) {
      _showMessage('تعذرت المزامنة الآن. ستبقى الحركات محفوظة محليًا.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'تعذر تحميل تخصيصاتك الآن.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب الجابي'),
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionStrip(online: widget.online),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.teal.withValues(alpha: 0.45)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.teal,
                    child: Icon(Icons.badge_outlined, color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.session.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(widget.session.tenantName, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.42)),
              ),
              child: const Text(
                'Stage02 يعرض التخصيصات فقط. تسجيل القراءة والجباية المالية غير مفعّل بعد.',
              ),
            ),
            const SizedBox(height: 18),
            Text('المهام والتخصيصات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_assignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 42, color: Colors.white38),
                    SizedBox(height: 10),
                    Text('لم يحدد صاحب المولدة تخصيصات لهذا الحساب بعد.'),
                  ],
                ),
              )
            else
              ..._assignments.map(
                (assignment) => Card(
                  child: ListTile(
                    leading: Icon(_iconForType(assignment.type), color: AppTheme.teal),
                    title: Text(assignment.label?.isNotEmpty == true ? assignment.label! : assignment.targetId),
                    subtitle: Text('${_labelForType(assignment.type)} • ${assignment.targetId}'),
                  ),
                ),
              ),
          ],
        ),
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
