import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

final class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authRepository,
    required this.onManualSync,
    this.restoredSession,
    super.key,
  });

  final AuthRepository authRepository;
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
                        const Text(
                          'النخبة لإدارة المولدات والجباية',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        _ConnectionBanner(online: _online),
                        const SizedBox(height: 24),
                        if (_session != null)
                          _SignedInCard(
                            session: _session!,
                            onLogout: _logout,
                            onManualSync: widget.onManualSync,
                          )
                        else
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
              decoration: const InputDecoration(labelText: 'رقم الهاتف أو اسم المستخدم', prefixIcon: Icon(Icons.person_outline)),
              validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم المستخدم أو رقم الهاتف' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _loading ? null : _submit(),
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
              'لا يوجد تسجيل ذاتي. الحساب يُنشأ من إدارة النظام فقط.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.authRepository.clearSession();
    if (mounted) setState(() => _session = null);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (online ? AppTheme.teal : AppTheme.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (online ? AppTheme.teal : AppTheme.orange).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 19, color: online ? AppTheme.teal : AppTheme.orange),
          const SizedBox(width: 8),
          Text(online ? 'متصل — المزامنة متاحة' : 'بدون إنترنت — الحركات ستبقى محليًا', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

final class _SignedInCard extends StatefulWidget {
  const _SignedInCard({
    required this.session,
    required this.onLogout,
    required this.onManualSync,
  });

  final AuthSession session;
  final VoidCallback onLogout;
  final Future<void> Function() onManualSync;

  @override
  State<_SignedInCard> createState() => _SignedInCardState();
}

final class _SignedInCardState extends State<_SignedInCard> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await widget.onManualSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتملت محاولة المزامنة. الحركات المؤكدة فقط تُعلَّم كمستلمة.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذرت المزامنة الآن. ستبقى الحركات محفوظة محليًا.')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user_outlined, size: 46, color: AppTheme.teal),
          const SizedBox(height: 12),
          Text(widget.session.fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(widget.session.tenantName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          Text(
            'نوع الحساب: ${widget.session.isOwner ? 'صاحب المولدة' : 'الجابي'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Stage01: تم تثبيت الدخول والعزل فقط. الوظائف المالية غير مفعلة بعد.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            label: const Text('مزامنة الآن'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: widget.onLogout, child: const Text('تسجيل الخروج')),
        ],
      ),
    );
  }
}
