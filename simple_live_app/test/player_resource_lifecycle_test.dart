import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/player_resource_lifecycle.dart';

void main() {
  test('native creation stays behind retirement, including immediate leave',
      () async {
    final coordinator = PlayerRetirementCoordinator();
    final release = Completer<void>();
    final cancelled = Completer<void>();
    coordinator.retire(1, release.future);
    var created = 0;
    var current = true;
    final startup = coordinator.initializeWhenReleased(
      instanceId: 2,
      timeout: const Duration(seconds: 1),
      isCurrent: () => current,
      initialize: () => created += 1,
      cancelled: cancelled.future,
    );
    await Future<void>.delayed(Duration.zero);
    expect(created, 0);
    current = false;
    cancelled.complete();
    expect(await startup, PlayerHandoffStatus.cancelled);
    release.complete();
    await Future<void>.delayed(Duration.zero);
    expect(created, 0);
  });

  test('native creation is admitted only after old dispose completion',
      () async {
    final coordinator = PlayerRetirementCoordinator();
    final release = Completer<void>();
    coordinator.retire(1, release.future);
    var created = false;
    final startup = coordinator.initializeWhenReleased(
      instanceId: 2,
      timeout: const Duration(seconds: 1),
      isCurrent: () => true,
      initialize: () => created = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(created, isFalse);
    release.complete();
    expect(await startup, PlayerHandoffStatus.ready);
    expect(created, isTrue);
  });

  test('a superseded native timeout cannot report an error for the new owner',
      () async {
    final queue = PlayerNativeOpenQueue();
    final nativeOpen = Completer<void>();
    var generation = 1;
    final oldOpening = queue.open(
      operation: () => nativeOpen.future,
      isCurrent: () => generation == 1,
      timeout: const Duration(milliseconds: 20),
      onPreviousError: (_, __) {},
    );
    await Future<void>.delayed(Duration.zero);
    generation = 2;
    expect(await oldOpening, PlayerOpenStatus.stale);

    var newerOpened = false;
    final newerOpening = queue.open(
      operation: () async {
        newerOpened = true;
      },
      isCurrent: () => generation == 2,
      timeout: const Duration(milliseconds: 20),
      onPreviousError: (_, __) {},
    );
    generation = 3;
    expect(await newerOpening, PlayerOpenStatus.stale);
    expect(newerOpened, isFalse);
    nativeOpen.complete();
    await queue.waitUntilIdle();
  });

  test('timed out native open still owns the handle until late completion',
      () async {
    final queue = PlayerNativeOpenQueue();
    final first = Completer<void>();
    var secondOpened = false;
    expect(
      await queue.open(
        operation: () => first.future,
        isCurrent: () => true,
        timeout: const Duration(milliseconds: 1),
        onPreviousError: (_, __) {},
      ),
      PlayerOpenStatus.timedOut,
    );
    var disposed = false;
    final disposal = queue.waitUntilIdle().then((_) => disposed = true);
    expect(
      await queue.open(
        operation: () async {
          secondOpened = true;
        },
        isCurrent: () => true,
        timeout: const Duration(milliseconds: 1),
        onPreviousError: (_, __) {},
      ),
      PlayerOpenStatus.timedOut,
    );
    expect(secondOpened, isFalse);
    expect(disposed, isFalse);
    first.complete();
    await disposal;
    expect(disposed, isTrue);
    expect(
      await queue.open(
        operation: () async {
          secondOpened = true;
        },
        isCurrent: () => true,
        timeout: const Duration(seconds: 1),
        onPreviousError: (_, __) {},
      ),
      PlayerOpenStatus.opened,
    );
    expect(secondOpened, isTrue);
  });

  test('a stale waiting selection never opens after the old operation finishes',
      () async {
    final queue = PlayerNativeOpenQueue();
    final first = Completer<void>();
    final opening = queue.open(
      operation: () => first.future,
      isCurrent: () => true,
      timeout: const Duration(seconds: 1),
      onPreviousError: (_, __) {},
    );
    var current = true;
    var staleOpened = false;
    final stale = queue.open(
      operation: () async {
        staleOpened = true;
      },
      isCurrent: () => current,
      timeout: const Duration(seconds: 1),
      onPreviousError: (_, __) {},
    );
    current = false;
    first.complete();
    await opening;
    expect(await stale, PlayerOpenStatus.stale);
    expect(staleOpened, isFalse);
  });

  test('next player waits for the retired native player to finish', () async {
    final coordinator = PlayerRetirementCoordinator();
    final release = Completer<void>();
    coordinator.retire(1, release.future);
    var opened = false;
    final opening = coordinator
        .waitUntilReleased(
          instanceId: 2,
          timeout: const Duration(seconds: 1),
        )
        .then((status) => opened = status == PlayerHandoffStatus.ready);
    await Future<void>.delayed(Duration.zero);
    expect(opened, isFalse);
    release.complete();
    await opening;
    expect(opened, isTrue);
    expect(coordinator.pendingCount, 0);
  });

  test('timeout keeps native resources quarantined and a later retry works',
      () async {
    final coordinator = PlayerRetirementCoordinator();
    final release = Completer<void>();
    coordinator.retire(1, release.future);
    expect(
      await coordinator.waitUntilReleased(
        instanceId: 2,
        timeout: const Duration(milliseconds: 1),
      ),
      PlayerHandoffStatus.timedOut,
    );
    expect(coordinator.pendingCount, 1);
    release.complete();
    expect(
      await coordinator.waitUntilReleased(
        instanceId: 2,
        timeout: const Duration(seconds: 1),
      ),
      PlayerHandoffStatus.ready,
    );
  });

  test('failed dispose blocks playback with an explicit failure', () async {
    final coordinator = PlayerRetirementCoordinator();
    final release = Completer<void>();
    coordinator.retire(1, release.future);
    release.completeError(StateError('dispose failed'));
    expect(
      await coordinator.waitUntilReleased(
        instanceId: 2,
        timeout: const Duration(seconds: 1),
      ),
      PlayerHandoffStatus.releaseFailed,
    );
    expect(coordinator.pendingCount, 1);
  });

  test('leaving a waiting room cancels its wait without releasing the old one',
      () async {
    final coordinator = PlayerRetirementCoordinator();
    final release = Completer<void>();
    final cancelled = Completer<void>();
    coordinator.retire(1, release.future);
    final waiting = coordinator.waitUntilReleased(
      instanceId: 2,
      timeout: const Duration(seconds: 1),
      cancelled: cancelled.future,
    );
    cancelled.complete();
    expect(await waiting, PlayerHandoffStatus.cancelled);
    expect(coordinator.pendingCount, 1);
    release.complete();
  });

  test('new retirements are included before playback is admitted', () async {
    final coordinator = PlayerRetirementCoordinator();
    final first = Completer<void>();
    final second = Completer<void>();
    coordinator.retire(1, first.future);
    var ready = false;
    final waiting = coordinator
        .waitUntilReleased(
          instanceId: 3,
          timeout: const Duration(seconds: 1),
        )
        .then((status) => ready = status == PlayerHandoffStatus.ready);
    coordinator.retire(2, second.future);
    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(ready, isFalse);
    second.complete();
    await waiting;
    expect(ready, isTrue);
  });

  test('stop and reset errors still run every cleanup step and dispose',
      () async {
    final calls = <String>[];
    final errors = <String>[];
    await releasePlayerResources(
      steps: [
        PlayerCleanupStep('stop', () {
          calls.add('stop');
          throw StateError('stop failed');
        }),
        PlayerCleanupStep('streams', () {
          calls.add('streams');
        }),
        PlayerCleanupStep('reset', () {
          calls.add('reset');
          throw StateError('reset failed');
        }),
      ],
      dispose: () async {
        calls.add('dispose');
      },
      onError: (step, error, stackTrace) => errors.add(step),
    );
    expect(calls, ['stop', 'streams', 'reset', 'dispose']);
    expect(errors, ['stop', 'reset']);
  });

  test('native dispose errors propagate to the retirement coordinator',
      () async {
    await expectLater(
      releasePlayerResources(
        steps: const [],
        dispose: () async => throw StateError('dispose failed'),
        onError: (_, __, ___) {},
      ),
      throwsStateError,
    );
  });
}
