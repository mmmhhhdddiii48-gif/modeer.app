import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_config.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_token_storage.dart';
import '../core/sync/sync_engine.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/domain/data/domain_repository.dart';
import '../features/owner/data/collector_repository.dart';
import '../features/readings/data/reading_repository.dart';
import '../features/readings/data/readings_api_client.dart';
import '../features/simple_billing/data/simple_billing_api_client.dart';
import '../features/simple_billing/data/simple_billing_repository.dart';

final class NukhbaGeneratorsApp extends StatefulWidget {
  const NukhbaGeneratorsApp({super.key});

  @override
  State<NukhbaGeneratorsApp> createState() => _NukhbaGeneratorsAppState();
}

final class _NukhbaGeneratorsAppState extends State<NukhbaGeneratorsApp> {
  late final AuthRepository _authRepository;
  late final CollectorRepository _collectorRepository;
  late final DomainRepository _domainRepository;
  late final ReadingRepository _readingRepository;
  late final SimpleBillingRepository _simpleBillingRepository;
  late final SyncEngine _syncEngine;
  AuthSession? _restoredSession;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    final tokens = SecureTokenStorage();
    final api = ApiClient(tokenStorage: tokens);
    _authRepository = AuthRepository(api: api, tokens: tokens);
    _collectorRepository = CollectorRepository(api: api, database: LocalDatabase.instance);
    _domainRepository = DomainRepository(api: api, database: LocalDatabase.instance);
    _readingRepository = ReadingRepository(
      api: ReadingsApiClient(tokenStorage: tokens),
      database: LocalDatabase.instance,
    );
    _simpleBillingRepository = SimpleBillingRepository(
      api: SimpleBillingApiClient(tokenStorage: tokens),
    );
    _syncEngine = SyncEngine(database: LocalDatabase.instance, api: api);
    _syncEngine.start();
    _restore();
  }

  Future<void> _restore() async {
    final session = await _authRepository.restore();
    if (!mounted) return;
    setState(() {
      _restoredSession = session;
      _restoring = false;
    });
  }

  @override
  void dispose() {
    _syncEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
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
      home: _restoring
          ? const SplashPage()
          : LoginPage(
              authRepository: _authRepository,
              collectorRepository: _collectorRepository,
              domainRepository: _domainRepository,
              readingRepository: _readingRepository,
              simpleBillingRepository: _simpleBillingRepository,
              restoredSession: _restoredSession,
              onManualSync: _syncEngine.flush,
            ),
    );
  }
}
