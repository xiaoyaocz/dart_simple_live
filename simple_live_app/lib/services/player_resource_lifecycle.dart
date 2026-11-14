import 'dart:async';

enum PlayerHandoffStatus { ready, timedOut, releaseFailed, cancelled }

enum PlayerOpenStatus { opened, stale, timedOut }

/// Serializes native opens without confusing a Dart timeout with cancellation.
class PlayerNativeOpenQueue {
  Future<void>? _active;

  Future<PlayerOpenStatus> open({
    required Future<void> Function() operation,
    required bool Function() isCurrent,
    required Duration timeout,
    required void Function(Object, StackTrace) onPreviousError,
  }) async {
    while (true) {
      if (!isCurrent()) return PlayerOpenStatus.stale;
      final active = _active;
      if (active == null) break;
      try {
        await active.timeout(timeout);
      } on TimeoutException {
        return isCurrent() ? PlayerOpenStatus.timedOut : PlayerOpenStatus.stale;
      } catch (error, stackTrace) {
        onPreviousError(error, stackTrace);
      }
    }
    if (!isCurrent()) return PlayerOpenStatus.stale;
    final opening = Future<void>.microtask(() async {
      if (!isCurrent()) return;
      await operation();
    });
    _active = opening;
    void clear() {
      if (identical(_active, opening)) _active = null;
    }

    opening.then((_) => clear(),
        onError: (Object error, StackTrace stackTrace) {
      clear();
    });
    try {
      await opening.timeout(timeout);
      return isCurrent() ? PlayerOpenStatus.opened : PlayerOpenStatus.stale;
    } on TimeoutException {
      return isCurrent() ? PlayerOpenStatus.timedOut : PlayerOpenStatus.stale;
    }
  }

  Future<void> waitUntilIdle() async {
    final active = _active;
    if (active != null) await active;
  }
}

/// Keeps native resources quarantined until their real release completes.
/// A timeout only ends a caller's wait; it never pretends a release succeeded.
class PlayerRetirementCoordinator {
  final Map<int, _PlayerRetirement> _retiring = {};

  int get pendingCount => _retiring.length;

  Future<PlayerHandoffStatus> initializeWhenReleased({
    required int instanceId,
    required Duration timeout,
    required bool Function() isCurrent,
    required void Function() initialize,
    Future<void>? cancelled,
  }) async {
    final status = await waitUntilReleased(
      instanceId: instanceId,
      timeout: timeout,
      cancelled: cancelled,
    );
    if (!isCurrent()) return PlayerHandoffStatus.cancelled;
    if (status != PlayerHandoffStatus.ready) return status;
    initialize();
    return PlayerHandoffStatus.ready;
  }

  void retire(int instanceId, Future<void> release) {
    if (_retiring.containsKey(instanceId)) return;
    final retirement = _PlayerRetirement();
    _retiring[instanceId] = retirement;
    release.then((_) {
      if (identical(_retiring[instanceId], retirement)) {
        _retiring.remove(instanceId);
      }
      retirement.completed.complete();
    }, onError: (Object error, StackTrace stackTrace) {
      retirement.failed = true;
      retirement.completed.complete();
    });
  }

  Future<PlayerHandoffStatus> waitUntilReleased({
    required int instanceId,
    required Duration timeout,
    Future<void>? cancelled,
  }) async {
    final deadline = Stopwatch()..start();
    while (true) {
      final pending = _retiring.entries
          .where((entry) => entry.key != instanceId)
          .map((entry) => entry.value)
          .toList();
      if (pending.any((entry) => entry.failed)) {
        return PlayerHandoffStatus.releaseFailed;
      }
      if (pending.isEmpty) return PlayerHandoffStatus.ready;
      final remaining = timeout - deadline.elapsed;
      if (remaining <= Duration.zero) return PlayerHandoffStatus.timedOut;
      final released = Future.wait(
        pending.map((entry) => entry.completed.future),
      ).then((_) => PlayerHandoffStatus.ready);
      final status = await Future.any<PlayerHandoffStatus>([
        released,
        if (cancelled != null)
          cancelled.then((_) => PlayerHandoffStatus.cancelled),
      ]).timeout(remaining, onTimeout: () => PlayerHandoffStatus.timedOut);
      if (status != PlayerHandoffStatus.ready) return status;
      // Include retirements registered while this snapshot was being awaited.
    }
  }
}

class _PlayerRetirement {
  final completed = Completer<void>();
  bool failed = false;
}

class PlayerCleanupStep {
  const PlayerCleanupStep(this.name, this.run);

  final String name;
  final FutureOr<void> Function() run;
}

/// A failed stop/system reset must not skip the final native dispose.
/// In-flight native operations must be awaited before entering this sequence.
Future<void> releasePlayerResources({
  required List<PlayerCleanupStep> steps,
  required Future<void> Function() dispose,
  required void Function(String, Object, StackTrace) onError,
}) async {
  for (final step in steps) {
    try {
      await step.run();
    } catch (error, stackTrace) {
      onError(step.name, error, stackTrace);
    }
  }
  // A dispose failure remains a failure, so later playback cannot reuse the
  // native resources that may still belong to the retired player.
  await dispose();
}
