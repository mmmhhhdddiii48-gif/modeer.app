import 'package:flutter_test/flutter_test.dart';
import 'package:nukhba_generators_mobile/demo/demo_trial.dart';

void main() {
  group('DemoTrialPolicy', () {
    final first = DateTime.utc(2026, 7, 1, 12);

    test('starts with seven active days', () {
      final state = DemoTrialPolicy.evaluate(now: first);
      expect(state.expired, isFalse);
      expect(state.clockRollbackDetected, isFalse);
      expect(state.expiresAtUtc, first.add(const Duration(days: 7)));
      expect(state.remainingDaysAt(first), 7);
    });

    test('expires after exactly seven days', () {
      final state = DemoTrialPolicy.evaluate(
        now: first.add(const Duration(days: 7)),
        firstLaunchUtc: first,
        lastSeenUtc: first.add(const Duration(days: 6)),
      );
      expect(state.expired, isTrue);
      expect(state.remainingDaysAt(first.add(const Duration(days: 7))), 0);
    });

    test('detects meaningful clock rollback', () {
      final state = DemoTrialPolicy.evaluate(
        now: first.add(const Duration(hours: 2)),
        firstLaunchUtc: first,
        lastSeenUtc: first.add(const Duration(days: 1)),
      );
      expect(state.clockRollbackDetected, isTrue);
      expect(state.expired, isTrue);
    });

    test('allows a small clock correction inside tolerance', () {
      final state = DemoTrialPolicy.evaluate(
        now: first.add(const Duration(hours: 2, minutes: 55)),
        firstLaunchUtc: first,
        lastSeenUtc: first.add(const Duration(hours: 3)),
      );
      expect(state.clockRollbackDetected, isFalse);
      expect(state.expired, isFalse);
    });
  });
}
