import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../../domain/data/domain_repository.dart';
import '../../domain/domain/generator_domain.dart';

final class CollectorHomePage extends StatefulWidget {
  const CollectorHomePage({
    required this.session,
    required this.domainRepository,
    required this.online,
    required this.onLogout,
    required this.onManualSync,
    super.key,
  });

  final AuthSession session;
  final DomainRepository domainRepository;
  final bool online;
  final Future<void> Function() onLogout;
  final Future<void> Function() onManualSync;

  @override
  State<CollectorHomePage> createState() => _CollectorHomePageState();
}

final class _CollectorHomePageState extends State<CollectorHomePage> {
  AssignedDomain _domain = const AssignedDomain(
    generators: [],
    routes: [],
    subscribers: [],
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
      final data = await widget.domainRepository.getCollectorAssignedDomain(
        tenantId: widget.session.tenantId,
        collectorId: widget.session.accountId,
      );
      if (mounted) setState(() => _domain = data);
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
      await _load();
      if (mounted) _showMessage('اكتملت محاولة المزامنة وتحديث المهام.');
    } catch (_) {
      _showMessage('تعذرت المزامنة الآن. ستبقى آخر بيانات مؤكدة محفوظة محليًا.');
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
    return 'تعذر تحميل المهام الآن.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المهام والتخصيصات'),
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
            _ProfileCard(session: widget.session),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.42)),
              ),
              child: const Text(
                'Stage03 يعرض بيانات التكليف الحقيقية فقط. تسجيل القراءة والجباية المالية غير مفعّل بعد.',
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(42),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _CountStrip(domain: _domain),
              const SizedBox(height: 18),
              _SectionTitle(icon: Icons.people_outline, title: 'المشتركين المكلف بهم'),
              const SizedBox(height: 8),
              if (_domain.subscribers.isEmpty)
                const _EmptyCard(text: 'لا يوجد مشتركون مكلف بهم حاليًا.')
              else
                ..._domain.subscribers.map(
                  (item) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.isActive ? AppTheme.teal : AppTheme.orange,
                        child: const Icon(Icons.person_outline, color: Colors.black),
                      ),
                      title: Text(item.fullName),
                      subtitle: Text(
                        '${item.accountNumber} • ${item.phone ?? 'بدون هاتف'}\n'
                        '${item.generator.name} • ${item.route?.name ?? 'بدون مسار'} • ${item.area ?? 'بدون منطقة'}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _SectionTitle(icon: Icons.route_outlined, title: 'المسارات المكلف بها'),
              const SizedBox(height: 8),
              if (_domain.routes.isEmpty)
                const _EmptyCard(text: 'لا توجد مسارات مكلف بها.')
              else
                ..._domain.routes.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.route_outlined, color: AppTheme.teal),
                      title: Text(item.name),
                      subtitle: Text('${item.code} • ${item.generator?.name ?? 'غير مربوط بمولدة'} • ${item.subscriberCount} مشترك'),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _SectionTitle(icon: Icons.electrical_services_outlined, title: 'المولدات المكلف بها'),
              const SizedBox(height: 8),
              if (_domain.generators.isEmpty)
                const _EmptyCard(text: 'لا توجد مولدات مكلف بها.')
              else
                ..._domain.generators.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.electrical_services, color: AppTheme.teal),
                      title: Text(item.name),
                      subtitle: Text('${item.code} • ${item.area ?? 'بدون منطقة'}'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) => Container(
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
            Text(session.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(session.tenantName, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

final class _CountStrip extends StatelessWidget {
  const _CountStrip({required this.domain});
  final AssignedDomain domain;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _CountCard(label: 'مشتركون', value: domain.subscribers.length)),
          const SizedBox(width: 8),
          Expanded(child: _CountCard(label: 'مسارات', value: domain.routes.length)),
          const SizedBox(width: 8),
          Expanded(child: _CountCard(label: 'مولدات', value: domain.generators.length)),
        ],
      );
}

final class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.teal)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTheme.teal),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      );
}

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );
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
          Text(online ? 'متصل — المزامنة متاحة' : 'بدون إنترنت — آخر بيانات مؤكدة متاحة'),
        ],
      ),
    );
  }
}
