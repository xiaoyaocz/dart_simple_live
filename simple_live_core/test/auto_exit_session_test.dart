import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test('keeps global deadline while applying room override', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = AutoExitSession()
      ..startGlobal(now: now, minutes: 60)
      ..startRoomOverride(now: now, minutes: 10);

    expect(session.source, AutoExitSource.roomOverride);
    expect(session.remaining(now), const Duration(minutes: 10));
    expect(session.globalRemaining(now), const Duration(minutes: 60));
    expect(session.isDue(now), isFalse);
  });

  test('stop clears both the active and preserved global deadlines', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = AutoExitSession()
      ..startGlobal(now: now, minutes: 60)
      ..startRoomOverride(now: now, minutes: 10)
      ..stop();

    expect(session.source, AutoExitSource.none);
    expect(session.enabled, isFalse);
    expect(session.deadline, isNull);
    expect(session.globalDeadline, isNull);
    expect(session.remaining(now), Duration.zero);
    expect(session.globalRemaining(now), Duration.zero);
  });

  test('is due at and after the deadline', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = AutoExitSession()..startGlobal(now: now, minutes: 1);

    expect(session.isDue(now), isFalse);
    expect(session.isDue(now.add(const Duration(seconds: 59))), isFalse);
    expect(session.isDue(now.add(const Duration(minutes: 1))), isTrue);
    expect(session.isDue(now.add(const Duration(minutes: 2))), isTrue);
  });

  test('normalizes durations to one day and at least one minute', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = AutoExitSession()..startGlobal(now: now, minutes: 0);
    expect(session.globalRemaining(now), const Duration(minutes: 1));

    session.startGlobal(now: now, minutes: 24 * 60 + 30);
    expect(session.globalRemaining(now), const Duration(hours: 24));
  });

  test('starting global timing replaces a previous room override', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = AutoExitSession()
      ..startGlobal(now: now, minutes: 30)
      ..startRoomOverride(now: now, minutes: 5)
      ..startGlobal(now: now, minutes: 45);

    expect(session.source, AutoExitSource.global);
    expect(session.remaining(now), const Duration(minutes: 45));
    expect(session.globalRemaining(now), const Duration(minutes: 45));
  });
}
