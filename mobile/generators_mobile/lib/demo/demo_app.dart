import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import 'demo_store.dart';
import 'demo_trial.dart';

final class DemoGeneratorsApp extends StatefulWidget {
  const DemoGeneratorsApp({super.key});

  @override
  State<DemoGeneratorsApp> createState() => _DemoGeneratorsAppState();
}

final class _DemoGeneratorsAppState extends State<DemoGeneratorsApp> {
  late final DemoStore _store;
  late final DemoTrialService _trialService;
  late final Future<_DemoBootstrap> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _store = DemoStore();
    _trialService = DemoTrialService();
    _bootstrapFuture = _bootstrap();
  }

  Future<_DemoBootstrap> _bootstrap() async {
    final trial = await _trialService.load();
    await _store.load();
    return _DemoBootstrap(trial: trial);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'النخبة — تجربة 7 أيام',
      theme: AppTheme.dark(),
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: FutureBuilder<_DemoBootstrap>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DemoSplashPage();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _DemoErrorPage(error: snapshot.error);
          }
          final trial = snapshot.data!.trial;
          if (trial.expired) {
            return _TrialExpiredPage(trial: trial);
          }
          return _DemoRoleRouter(store: _store, trial: trial);
        },
      ),
    );
  }
}

final class _DemoBootstrap {
  const _DemoBootstrap({required this.trial});
  final DemoTrialState trial;
}

final class _DemoSplashPage extends StatelessWidget {
  const _DemoSplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.electrical_services, size: 66, color: AppTheme.teal),
            SizedBox(height: 18),
            Text(
              'النخبة لإدارة المولدات والجباية',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 22),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

final class _DemoErrorPage extends StatelessWidget {
  const _DemoErrorPage({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 18),
                const Text(
                  'تعذر تشغيل النسخة التجريبية',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  error?.toString() ?? 'حدث خطأ غير معروف.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _TrialExpiredPage extends StatelessWidget {
  const _TrialExpiredPage({required this.trial});
  final DemoTrialState trial;

  @override
  Widget build(BuildContext context) {
    final rollback = trial.clockRollbackDetected;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_outlined, size: 68, color: AppTheme.orange),
                    const SizedBox(height: 16),
                    Text(
                      rollback ? 'تم إيقاف النسخة التجريبية' : 'انتهت مدة التجربة',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rollback
                          ? 'تم رصد تغيير غير طبيعي في وقت الجهاز. أعد الوقت الصحيح ثم تواصل مع النخبة.'
                          : 'انتهت مدة التجربة البالغة 7 أيام. النسخة الكاملة ترتبط بحسابك وسيرفرك الخاص.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    const _ContactCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _DemoRoleRouter extends StatefulWidget {
  const _DemoRoleRouter({required this.store, required this.trial});
  final DemoStore store;
  final DemoTrialState trial;

  @override
  State<_DemoRoleRouter> createState() => _DemoRoleRouterState();
}

final class _DemoRoleRouterState extends State<_DemoRoleRouter> {
  _DemoRole? _role;

  @override
  Widget build(BuildContext context) {
    final role = _role;
    if (role == null) {
      return _DemoLoginPage(
        trial: widget.trial,
        onSelectRole: (value) => setState(() => _role = value),
      );
    }
    return _DemoShell(
      role: role,
      store: widget.store,
      trial: widget.trial,
      onLogout: () => setState(() => _role = null),
    );
  }
}

enum _DemoRole { owner, collector }

final class _DemoLoginPage extends StatelessWidget {
  const _DemoLoginPage({required this.trial, required this.onSelectRole});

  final DemoTrialState trial;
  final ValueChanged<_DemoRole> onSelectRole;

  @override
  Widget build(BuildContext context) {
    final remainingDays = trial.remainingDaysAt(DateTime.now());
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.electrical_services, size: 70, color: AppTheme.teal),
                        const SizedBox(height: 14),
                        const Text(
                          'النخبة لإدارة المولدات والجباية',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'نسخة تجريبية محلية — متبقي $remainingDays أيام',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 24),
                        _RoleCard(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'الدخول كصاحب مولدة',
                          description: 'تصفح الداشبورد والمشتركين والفواتير والجباة وسجل الوصولات.',
                          buttonLabel: 'دخول صاحب المولدة',
                          color: AppTheme.teal,
                          onPressed: () => onSelectRole(_DemoRole.owner),
                        ),
                        const SizedBox(height: 14),
                        _RoleCard(
                          icon: Icons.badge_outlined,
                          title: 'الدخول كجابي',
                          description: 'تجربة تحصيل الفواتير وتسجيل القراءات للمسارات المخصصة فقط.',
                          buttonLabel: 'دخول الجابي',
                          color: AppTheme.orange,
                          onPressed: () => onSelectRole(_DemoRole.collector),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا تحتاج هذه النسخة إلى إنترنت أو Render. جميع البيانات نموذجية وتُحفظ داخل الجهاز فقط.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(description, style: const TextStyle(color: Colors.white70, height: 1.55)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

final class _DemoShell extends StatefulWidget {
  const _DemoShell({
    required this.role,
    required this.store,
    required this.trial,
    required this.onLogout,
  });

  final _DemoRole role;
  final DemoStore store;
  final DemoTrialState trial;
  final VoidCallback onLogout;

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

final class _DemoShellState extends State<_DemoShell> {
  int _index = 0;

  bool get _isOwner => widget.role == _DemoRole.owner;

  @override
  Widget build(BuildContext context) {
    final pages = _isOwner
        ? <Widget>[
            _OwnerDashboardPage(store: widget.store),
            _SubscribersPage(store: widget.store),
            _InvoicesPage(store: widget.store, actorName: 'صاحب المولدة'),
            _CollectorsPage(store: widget.store),
          ]
        : <Widget>[
            _CollectorCollectionsPage(store: widget.store),
            _CollectorReadingsPage(store: widget.store),
            _DemoInfoPage(
              store: widget.store,
              trial: widget.trial,
              role: widget.role,
              onLogout: widget.onLogout,
            ),
          ];

    final destinations = _isOwner
        ? const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'المشتركون'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'الفواتير'),
            NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'الجباة'),
          ]
        : const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'الجباية'),
            NavigationDestination(icon: Icon(Icons.speed_outlined), selectedIcon: Icon(Icons.speed), label: 'القراءات'),
            NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'الحساب'),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwner ? 'صاحب المولدة — نسخة تجريبية' : 'الجابي أحمد كريم — نسخة تجريبية'),
        actions: [
          IconButton(
            tooltip: 'تبديل الحساب',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.switch_account_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _TrialBanner(trial: widget.trial),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) => IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

final class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.trial});
  final DemoTrialState trial;

  @override
  Widget build(BuildContext context) {
    final days = trial.remainingDaysAt(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: AppTheme.orange.withOpacity(0.13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.science_outlined, size: 18, color: AppTheme.orange),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'نسخة تجريبية — بيانات نموذجية — متبقي $days أيام',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

final class _OwnerDashboardPage extends StatelessWidget {
  const _OwnerDashboardPage({required this.store});
  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    final data = store.snapshot;
    final recentReceipts = data.receipts.take(4).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ملخص العمل', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('أرقام نموذجية توضح طريقة عمل البرنامج.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _StatCard(icon: Icons.people, label: 'المشتركون', value: '${data.subscribers.length}', color: AppTheme.teal),
            _StatCard(icon: Icons.receipt_long, label: 'فواتير الشهر', value: '${data.invoices.length}', color: AppTheme.orange),
            _StatCard(icon: Icons.account_balance_wallet_outlined, label: 'المبالغ المحصلة', value: _formatIqd(data.collectedIqd), color: Colors.lightGreenAccent),
            _StatCard(icon: Icons.pending_actions_outlined, label: 'المتبقي', value: _formatIqd(data.remainingIqd), color: Colors.redAccent),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: Icons.electrical_services, title: 'المولدات'),
        const SizedBox(height: 10),
        ...data.generators.map((generator) {
          final routes = data.routes.where((item) => item.generatorId == generator.id).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SurfaceCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0x2520B8A6),
                    child: Icon(Icons.bolt, color: AppTheme.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(generator.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${generator.location} • $routes مسارات', style: const TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                  Text('${generator.capacityAmps} A', style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const _SectionTitle(icon: Icons.history, title: 'آخر الوصولات'),
        const SizedBox(height: 10),
        if (recentReceipts.isEmpty)
          const _EmptyState(icon: Icons.receipt_long_outlined, text: 'لا توجد وصولات')
        else
          ...recentReceipts.map((receipt) {
            final invoice = store.invoiceById(receipt.invoiceId);
            final subscriber = store.subscriberById(invoice.subscriberId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SurfaceCard(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.lightGreenAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${receipt.number} — ${subscriber.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('${receipt.receivedBy} • ${receipt.paymentMethod}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(_formatIqd(receipt.amountIqd), style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.teal)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

final class _SubscribersPage extends StatefulWidget {
  const _SubscribersPage({required this.store});
  final DemoStore store;

  @override
  State<_SubscribersPage> createState() => _SubscribersPageState();
}

final class _SubscribersPageState extends State<_SubscribersPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final subscribers = widget.store.snapshot.subscribers.where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.phone.contains(query) ||
          item.accountNumber.toLowerCase().contains(query) ||
          item.meterNumber.toLowerCase().contains(query);
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('المشتركون', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSubscriberDialog(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('إضافة'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'بحث بالاسم أو الهاتف أو الحساب أو العداد',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: subscribers.isEmpty
              ? const _EmptyState(icon: Icons.people_outline, text: 'لا توجد نتائج')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  itemCount: subscribers.length,
                  itemBuilder: (context, index) {
                    final subscriber = subscribers[index];
                    final route = widget.store.routeById(subscriber.routeId);
                    final generator = widget.store.generatorById(route.generatorId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.teal.withOpacity(0.13),
                                  child: Text(subscriber.name.characters.first, style: const TextStyle(color: AppTheme.teal, fontWeight: FontWeight.w900)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(subscriber.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      Text('${subscriber.accountNumber} • ${subscriber.meterNumber}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                _SmallPill(text: '${subscriber.amperage} أمبير', color: AppTheme.orange),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(icon: Icons.phone_outlined, text: subscriber.phone),
                            _InfoRow(icon: Icons.route_outlined, text: '${route.name} — ${generator.name}'),
                            _InfoRow(icon: Icons.speed_outlined, text: 'آخر قراءة: ${subscriber.lastReading}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddSubscriberDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final ampController = TextEditingController(text: '10');
    String routeId = widget.store.snapshot.routes.first.id;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مشترك تجريبي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المشترك')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 12),
                TextField(controller: ampController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الأمبيرات')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: routeId,
                  decoration: const InputDecoration(labelText: 'المسار'),
                  items: widget.store.snapshot.routes
                      .map((route) => DropdownMenuItem(value: route.id, child: Text(route.name)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => routeId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        await widget.store.addSubscriber(
          name: nameController.text,
          phone: phoneController.text,
          routeId: routeId,
          amperage: int.tryParse(ampController.text) ?? 0,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المشترك داخل البيانات التجريبية')));
        }
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    nameController.dispose();
    phoneController.dispose();
    ampController.dispose();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

final class _InvoicesPage extends StatefulWidget {
  const _InvoicesPage({required this.store, required this.actorName});
  final DemoStore store;
  final String actorName;

  @override
  State<_InvoicesPage> createState() => _InvoicesPageState();
}

final class _InvoicesPageState extends State<_InvoicesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final invoices = widget.store.snapshot.invoices.where((invoice) {
      final subscriber = widget.store.subscriberById(invoice.subscriberId);
      final query = _query.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          subscriber.name.toLowerCase().contains(query) ||
          subscriber.accountNumber.toLowerCase().contains(query) ||
          invoice.number.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        'unpaid' => !invoice.isPaid && !invoice.isPartial,
        'partial' => invoice.isPartial,
        'paid' => invoice.isPaid,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('فواتير الشهر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(hintText: 'بحث باسم المشترك أو رقم الفاتورة', prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(label: 'الكل', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                    _FilterChipButton(label: 'غير مسددة', selected: _filter == 'unpaid', onTap: () => setState(() => _filter = 'unpaid')),
                    _FilterChipButton(label: 'جزئي', selected: _filter == 'partial', onTap: () => setState(() => _filter = 'partial')),
                    _FilterChipButton(label: 'مسددة', selected: _filter == 'paid', onTap: () => setState(() => _filter = 'paid')),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: invoices.isEmpty
              ? const _EmptyState(icon: Icons.receipt_long_outlined, text: 'لا توجد فواتير مطابقة')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InvoiceCard(
                      store: widget.store,
                      invoice: invoices[index],
                      actorName: widget.actorName,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

final class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.store,
    required this.invoice,
    required this.actorName,
  });

  final DemoStore store;
  final DemoInvoice invoice;
  final String actorName;

  @override
  Widget build(BuildContext context) {
    final subscriber = store.subscriberById(invoice.subscriberId);
    final progress = invoice.totalIqd == 0 ? 0.0 : invoice.paidIqd / invoice.totalIqd;
    final statusColor = invoice.isPaid ? Colors.lightGreenAccent : invoice.isPartial ? AppTheme.orange : Colors.redAccent;
    final receipts = store.snapshot.receipts.where((item) => item.invoiceId == invoice.id).toList(growable: false);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subscriber.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${invoice.number} • ${subscriber.accountNumber}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              _SmallPill(text: invoice.statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppTheme.border,
            color: statusColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MoneyBox(label: 'الإجمالي', value: invoice.totalIqd)),
              const SizedBox(width: 8),
              Expanded(child: _MoneyBox(label: 'المدفوع', value: invoice.paidIqd)),
              const SizedBox(width: 8),
              Expanded(child: _MoneyBox(label: 'المتبقي', value: invoice.remainingIqd, highlight: true)),
            ],
          ),
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('آخر وصل: ${receipts.first.number} — ${_formatIqd(receipts.first.amountIqd)}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: invoice.isPaid ? null : () => _showPaymentDialog(context, store, invoice, actorName),
            icon: const Icon(Icons.payments_outlined),
            label: Text(invoice.isPaid ? 'مسددة بالكامل' : 'تسجيل دفعة'),
          ),
        ],
      ),
    );
  }
}

final class _CollectorsPage extends StatelessWidget {
  const _CollectorsPage({required this.store});
  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    final collectors = store.snapshot.collectors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('حسابات الجباة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('كل جابي يشاهد فقط المسارات والمشتركين المخصصين له.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        ...collectors.map((collector) {
          final routes = store.snapshot.routes.where((route) => collector.assignedRouteIds.contains(route.id)).toList(growable: false);
          final subscriberCount = store.subscribersForCollector(collector).length;
          final invoiceCount = store.invoicesForCollector(collector).where((item) => !item.isPaid).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.orange.withOpacity(0.15),
                        child: const Icon(Icons.badge_outlined, color: AppTheme.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(collector.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text(collector.phone, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      _SmallPill(text: 'نشط', color: Colors.lightGreenAccent),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: routes.map((route) => _SmallPill(text: route.name, color: AppTheme.teal)).toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _TinyStat(label: 'المشتركون', value: '$subscriberCount')),
                      const SizedBox(width: 10),
                      Expanded(child: _TinyStat(label: 'فواتير للتحصيل', value: '$invoiceCount')),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

final class _CollectorCollectionsPage extends StatefulWidget {
  const _CollectorCollectionsPage({required this.store});
  final DemoStore store;

  @override
  State<_CollectorCollectionsPage> createState() => _CollectorCollectionsPageState();
}

final class _CollectorCollectionsPageState extends State<_CollectorCollectionsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  DemoCollector get _collector => widget.store.snapshot.collectors.first;

  @override
  Widget build(BuildContext context) {
    final invoices = widget.store.invoicesForCollector(_collector).where((invoice) {
      final subscriber = widget.store.subscriberById(invoice.subscriberId);
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          subscriber.name.toLowerCase().contains(query) ||
          subscriber.phone.contains(query) ||
          subscriber.accountNumber.toLowerCase().contains(query) ||
          subscriber.meterNumber.toLowerCase().contains(query) ||
          invoice.number.toLowerCase().contains(query);
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تحصيل الفواتير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('المسارات المخصصة: ${_collector.assignedRouteIds.map(widget.store.routeById).map((item) => item.name).join('، ')}', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(hintText: 'بحث بالاسم أو الحساب أو العداد أو الفاتورة', prefixIcon: Icon(Icons.search)),
              ),
            ],
          ),
        ),
        Expanded(
          child: invoices.isEmpty
              ? const _EmptyState(icon: Icons.payments_outlined, text: 'لا توجد فواتير ضمن تخصيصات الجابي')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InvoiceCard(
                      store: widget.store,
                      invoice: invoices[index],
                      actorName: '${_collector.name} — جابي',
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

final class _CollectorReadingsPage extends StatelessWidget {
  const _CollectorReadingsPage({required this.store});
  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    final collector = store.snapshot.collectors.first;
    final subscribers = store.subscribersForCollector(collector);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('قراءات العدادات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('القراءة الجديدة تُحفظ محليًا داخل النسخة التجريبية.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        ...subscribers.map((subscriber) {
          final route = store.routeById(subscriber.routeId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SurfaceCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.speed, color: AppTheme.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subscriber.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${route.name} • ${subscriber.meterNumber}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        Text('القراءة السابقة: ${subscriber.lastReading}', style: const TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'تسجيل قراءة',
                    onPressed: () => _showReadingDialog(context, store, subscriber, collector.name),
                    icon: const Icon(Icons.edit_note),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

final class _DemoInfoPage extends StatelessWidget {
  const _DemoInfoPage({
    required this.store,
    required this.trial,
    required this.role,
    required this.onLogout,
  });

  final DemoStore store;
  final DemoTrialState trial;
  final _DemoRole role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final days = trial.remainingDaysAt(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('معلومات النسخة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _SurfaceCard(
          child: Column(
            children: [
              const Icon(Icons.science_outlined, size: 54, color: AppTheme.orange),
              const SizedBox(height: 12),
              const Text('نسخة تجريبية محلية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('متبقي $days أيام من مدة التجربة', style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text(
                'هذه البيانات نموذجية ولا تُرفع إلى الإنترنت. النسخة الكاملة ترتبط بحساب المؤسسة وسيرفر النخبة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _ContactCard(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.switch_account_outlined),
          label: Text(role == _DemoRole.owner ? 'الدخول كجابي' : 'الدخول كصاحب مولدة'),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => _confirmReset(context),
          icon: const Icon(Icons.restart_alt),
          label: const Text('إعادة البيانات النموذجية'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
        ),
        const SizedBox(height: 8),
        const Text(
          'إعادة البيانات لا تعيد مدة التجربة.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة البيانات التجريبية'),
        content: const Text('سيتم حذف التغييرات المحلية وإرجاع المشتركين والفواتير والوصولات النموذجية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إعادة الآن')),
        ],
      ),
    );
    if (confirmed == true) {
      await store.reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إعادة البيانات النموذجية')));
      }
    }
  }
}

Future<void> _showPaymentDialog(
  BuildContext context,
  DemoStore store,
  DemoInvoice invoice,
  String actorName,
) async {
  final amountController = TextEditingController(text: invoice.remainingIqd.toString());
  String method = 'نقد';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('تسجيل دفعة تجريبية'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('المتبقي: ${_formatIqd(invoice.remainingIqd)}', style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مبلغ الدفعة بالدينار'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: const [
                  DropdownMenuItem(value: 'نقد', child: Text('نقد')),
                  DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => method = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد الدفعة')),
        ],
      ),
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      final receipt = await store.recordPayment(
        invoiceId: invoice.id,
        amountIqd: int.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0,
        paymentMethod: method,
        receivedBy: actorName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تسجيل الدفعة — رقم الوصل ${receipt.number}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
  amountController.dispose();
}

Future<void> _showReadingDialog(
  BuildContext context,
  DemoStore store,
  DemoSubscriber subscriber,
  String collectorName,
) async {
  final controller = TextEditingController(text: '${subscriber.lastReading + 100}');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('قراءة عداد ${subscriber.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('القراءة السابقة: ${subscriber.lastReading}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'القراءة الجديدة'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ القراءة')),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await store.recordReading(
        subscriberId: subscriber.id,
        value: int.tryParse(controller.text.trim()) ?? -1,
        recordedBy: '$collectorName — جابي',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القراءة محليًا')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
  controller.dispose();
}

final class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

final class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.teal),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

final class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

final class _MoneyBox extends StatelessWidget {
  const _MoneyBox({required this.label, required this.value, this.highlight = false});
  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.orange.withOpacity(0.1) : AppTheme.background.withOpacity(0.55),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_formatIqd(value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: highlight ? AppTheme.orange : Colors.white)),
          ),
        ],
      ),
    );
  }
}

final class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.background.withOpacity(0.55), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.teal)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
    );
  }
}

final class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.white24),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

final class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.teal.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.teal.withOpacity(0.35)),
      ),
      child: const Column(
        children: [
          Text('النخبة ERP للحلول الإدارية والمحاسبية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text('واتساب: 0774 541 3212', style: TextStyle(color: AppTheme.teal, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Instagram: lnkhberp', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

String _formatIqd(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}${buffer.toString()} د.ع';
}
