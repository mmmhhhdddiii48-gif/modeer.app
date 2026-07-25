import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../collector/presentation/collector_home_page.dart';
import '../../domain/data/domain_repository.dart';
import '../../owner/data/collector_repository.dart';
import '../../owner/presentation/owner_home_page.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

final class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authRepository,
    required this.collectorRepository,
    required this.domainRepository,
    required this.onManualSync,
    this.restoredSession,
    super.key,
  });

  final AuthRepository authRepository;
  final CollectorRepository collectorRepository;
  final DomainRepository domainRepository;
  final Future<void> Function() onManualSync;
  final AuthSession? restoredSession;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _online = false;
  bool _loading = false;
  bool _obscurePassword = true;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _session = widget.restoredSession;
    _readConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_setConnectivity);
  }

  Future<void> _readConnectivity() async {
    _setConnectivity(await Connectivity().checkConnectivity());
  }

  void _setConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() => _online = results.any((result) => result != ConnectivityResult.none));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final session = await widget.authRepository.login(
        login: _loginController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _session = session);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تسجيل الدخول بصفة ${session.isOwner ? 'صاحب مولدة' : 'جابي'}')),
      );
    } on DioException catch (error) {
      _showError(_apiMessage(error));
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await widget.authRepository.clearSession();
    if (mounted) setState(() => _session = null);
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (!_online) return 'لا يوجد اتصال حاليًا. تسجيل الدخول الأول يحتاج اتصالًا بالسيرفر.';
    return 'تعذر الاتصال بالسيرفر. تحقق من البيانات وحاول مجددًا.';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) {
      if (session.isOwner) {
        return OwnerHomePage(
          session: session,
          repository: widget.collectorRepository,
          domainRepository: widget.domainRepository,
          online: _online,
          onLogout: _logout,
          onManualSync: widget.onManualSync,
        );
      }
      return CollectorHomePage(
        session: session,
        domainRepository: widget.domainRepository,
        online: _online,
        onLogout: _logout,
        onManualSync: widget.onManualSync,
      );
    }

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
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.electrical_services, size: 58, color: AppTheme.teal),
                        const SizedBox(height: 12),
                        const Text(
                          'النخبة لإدارة المولدات والجباية',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        _ConnectionBanner(online: _online),
                        const SizedBox(height: 24),
                        _loginForm(),
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

  Widget _loginForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تسجيل الدخول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('لحساب صاحب المولدة أو الجابي', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _loginController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف أو اسم المستخدم',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم المستخدم أو رقم الهاتف' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!_loading) _submit();
              },
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? 'أدخل كلمة المرور' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('دخول'),
            ),
            const SizedBox(height: 12),
            const Text(
              'حساب صاحب المولدة ينشئه مالك النظام، وحساب الجابي ينشئه صاحب المولدة ضمن الحد المسموح.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

final class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 19, color: color),
          const SizedBox(width: 8),
          Text(
            online ? 'متصل — المزامنة متاحة' : 'بدون إنترنت — الحركات ستبقى محليًا',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
