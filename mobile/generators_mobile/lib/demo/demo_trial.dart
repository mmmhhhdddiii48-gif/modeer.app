import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class DemoTrialState {
  const DemoTrialState({
    required this.firstLaunchUtc,
    required this.expiresAtUtc,
    required this.lastSeenUtc,
    required this.expired,
    required this.clockRollbackDetected,
  });

  final DateTime firstLaunchUtc;
  final DateTime expiresAtUtc;
  final DateTime lastSeenUtc;
  final bool expired;
  final bool clockRollbackDetected;

  Duration remainingAt(DateTime now) {
    if (expired) return Duration.zero;
    final value = expiresAtUtc.difference(now.toUtc());
    return value.isNegative ? Duration.zero : value;
  }

  int remainingDaysAt(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining == Duration.zero) return 0;
    return math.max(1, (remaining.inMinutes / Duration.minutesPerDay).ceil());
  }
}

abstract final class DemoTrialPolicy {
  static const Duration duration = Duration(days: 7);
  static const Duration rollbackTolerance = Duration(minutes: 10);

  static DemoTrialState evaluate({
    required DateTime now,
    DateTime? firstLaunchUtc,
    DateTime? lastSeenUtc,
  }) {
    final current = now.toUtc();
    final first = (firstLaunchUtc ?? current).toUtc();
    final last = (lastSeenUtc ?? current).toUtc();
    final rollbackDetected = lastSeenUtc != null &&
        current.isBefore(last.subtract(rollbackTolerance));
    final expiresAt = first.add(duration);
    final expired = rollbackDetected || !current.isBefore(expiresAt);
    final nextLastSeen = current.isAfter(last) ? current : last;

    return DemoTrialState(
      firstLaunchUtc: first,
      expiresAtUtc: expiresAt,
      lastSeenUtc: nextLastSeen,
      expired: expired,
      clockRollbackDetected: rollbackDetected,
    );
  }
}

final class DemoTrialService {
  DemoTrialService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _firstLaunchKey = 'nukhba_generators_demo_first_launch_utc_v1';
  static const _lastSeenKey = 'nukhba_generators_demo_last_seen_utc_v1';

  final FlutterSecureStorage _storage;

  Future<DemoTrialState> load() async {
    final now = DateTime.now().toUtc();
    final firstLaunch = _tryParse(await _storage.read(key: _firstLaunchKey));
    final lastSeen = _tryParse(await _storage.read(key: _lastSeenKey));
    final state = DemoTrialPolicy.evaluate(
      now: now,
      firstLaunchUtc: firstLaunch,
      lastSeenUtc: lastSeen,
    );

    if (firstLaunch == null) {
      await _storage.write(
        key: _firstLaunchKey,
        value: state.firstLaunchUtc.toIso8601String(),
      );
    }

    if (!state.clockRollbackDetected) {
      await _storage.write(
        key: _lastSeenKey,
        value: state.lastSeenUtc.toIso8601String(),
      );
    }

    return state;
  }

  DateTime? _tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
