import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

final class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoMark(),
            SizedBox(height: 22),
            Text(
              'النخبة لإدارة المولدات والجباية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10),
            Text('Mobile', style: TextStyle(color: AppTheme.orange, letterSpacing: 2)),
            SizedBox(height: 28),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
          ],
        ),
      ),
    );
  }
}

final class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.7)),
      ),
      child: const Text('ن', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: AppTheme.teal)),
    );
  }
}
