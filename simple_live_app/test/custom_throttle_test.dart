import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/custom_throttle.dart';

void main() {
  testWidgets('releases the throttle after a task fails', (tester) async {
    final errors = <Object>[];
    final throttle = DelayedThrottle(
      100,
      onError: (error, _) => errors.add(error),
    );

    throttle.invoke(() async {
      throw StateError('volume write failed');
    });

    expect(throttle.isInvoking, isTrue);
    await tester.pump();
    expect(errors, hasLength(1));
    expect(throttle.isInvoking, isTrue);

    await tester.pump(const Duration(milliseconds: 100));
    expect(throttle.isInvoking, isFalse);
  });

  testWidgets('runs the pending task after a failed task', (tester) async {
    final firstTask = Completer<void>();
    final calls = <int>[];
    final throttle = DelayedThrottle(
      100,
      onError: (_, __) {},
    );

    throttle.invoke(() async {
      calls.add(1);
      await firstTask.future;
      throw StateError('first task failed');
    });
    throttle.invoke(() async {
      calls.add(2);
    });

    firstTask.complete();
    await tester.pump();
    expect(calls, [1]);

    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, [1, 2]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(throttle.isInvoking, isFalse);
  });

  testWidgets('releases the throttle when the error handler fails',
      (tester) async {
    final reportedErrors = <Object>[];
    late DelayedThrottle throttle;

    runZonedGuarded(() {
      throttle = DelayedThrottle(
        100,
        onError: (_, __) => throw StateError('error handler failed'),
      );
      throttle.invoke(() async {
        throw StateError('volume write failed');
      });
    }, (error, _) => reportedErrors.add(error));

    await tester.pump();
    expect(reportedErrors, hasLength(1));
    expect(throttle.isInvoking, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(throttle.isInvoking, isFalse);
  });

  testWidgets('cancel invalidates an unfinished task', (tester) async {
    final task = Completer<void>();
    var pendingCalls = 0;
    final throttle = DelayedThrottle(100, onError: (_, __) {});

    throttle.invoke(() async {
      await task.future;
    });
    throttle.invoke(() async {
      pendingCalls += 1;
    });
    throttle.cancel();
    task.complete();
    await tester.pump();

    expect(pendingCalls, 0);
    expect(throttle.isInvoking, isFalse);
    expect(throttle.storeFunc, isNull);
  });
}
