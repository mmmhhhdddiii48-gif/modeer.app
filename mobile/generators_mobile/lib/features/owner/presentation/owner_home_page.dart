import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../../domain/data/domain_repository.dart';
import '../../domain/presentation/domain_management_page.dart';
import '../../readings/data/reading_repository.dart';
import '../../readings/presentation/owner_reading_periods_page.dart';
import '../../simple_billing/data/simple_billing_repository.dart';
import '../../simple_billing/presentation/owner_simple_billing_page.dart';
import '../data/collector_repository.dart';
import '../domain/collector_account.dart';
import 'collector_assignments_page.dart';

part 'owner_home_widgets.dart';
part 'owner_home_forms.dart';

final class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({
    required this.session,
    required this.repository,
    required this.domainRepository,
    required this.readingRepository,
    required this.simpleBillingRepository,
    required this.online,
    required this.onLogout,
    required this.onManualSync,
    super.key,
  });

  final AuthSession session;
  final CollectorRepository repository;
  final DomainRepository domainRepository;
  final ReadingRepository readingRepository;
  final SimpleBillingRepository simpleBillingRepository;
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
      _showMessage('تعذرت المزامنة الآن، وستبقى القراءات المحلية محفوظة.');
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
          domainRepository: widget.domainRepository,
          tenantId: widget.session.tenantId,
          collector: collector,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openDomainManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DomainManagementPage(
          repository: widget.domainRepository,
          tenantId: widget.session.tenantId,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openReadingPeriods() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OwnerReadingPeriodsPage(
          repository: widget.readingRepository,
          tenantId: widget.session.tenantId,
          online: widget.online,
        ),
      ),
    );
  }

  Future<void> _openMonthlyBilling() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OwnerSimpleBillingPage(
          repository: widget.simpleBillingRepository,
          online: widget.online,
        ),
      ),
    );
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
        title: const Text('إدارة المولدة'),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openDomainManagement,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('المولدات والمسارات والمشتركون'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openReadingPeriods,
                icon: const Icon(Icons.speed_outlined),
                label: const Text('قراءات العدادات'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMonthlyBilling,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('فواتير الشهر'),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.teal.withValues(alpha: 0.42)),
              ),
              child: const Text(
                'الطريقة: سجل القراءات، اقفل الشهر، حدد سعر الأمبير، ثم أنشئ الفواتير. '
                'الفاتورة غير المسددة هي الدين نفسه؛ لا توجد مسودات أو مراجعة أو اعتماد منفصل.',
              ),
            ),
            const SizedBox(height: 14),
            _UsagePanel(usage: _usage),
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
