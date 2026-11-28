import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';

class _Streams implements PlayerStream {
  final errors = StreamController<String>.broadcast();
  final bufferingEvents = StreamController<bool>.broadcast();
  final completedEvents = StreamController<bool>.broadcast();
  @override
  Stream<String> get error => errors.stream;
  @override
  Stream<bool> get buffering => bufferingEvents.stream;
  @override
  Stream<bool> get completed => completedEvents.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => const Stream<Never>.empty();

  Future<void> close() async {
    await errors.close();
    await bufferingEvents.close();
    await completedEvents.close();
  }
}

class _Player implements Player {
  @override
  final _Streams stream = _Streams();
  final disposed = Completer<void>();
  @override
  Future<void> dispose() async => disposed.complete();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends PlayerController {
  final fake = _Player();
  @override
  _Player get player => fake;
  int errors = 0;
  int ends = 0;
  int bufferingChanges = 0;
  Future<void>? exitGate;
  bool failReset = false;
  @override
  void mediaError(String error) => errors++;
  @override
  void mediaEnd() => ends++;
  @override
  void mediaBuffering(bool buffering) => bufferingChanges++;
  @override
  Future<void> exitFull() async {
    await exitGate;
    fullScreenState.value = false;
  }

  @override
  Future<void> resetSystem() async {
    if (failReset) throw StateError('system reset failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('重复初始化不会重复派发播放器事件，释放后可以重新绑定', () async {
    final controller = _Controller();
    addTearDown(controller.player.stream.close);
    controller.initStream();
    controller.initStream();
    controller.player.stream.errors.add('broken stream');
    controller.player.stream.bufferingEvents.add(true);
    controller.player.stream.completedEvents.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(controller.errors, 1);
    expect(controller.bufferingChanges, 1);
    expect(controller.ends, 1);

    controller.disposeStream();
    controller.player.stream.errors.add('after disposal');
    await Future<void>.delayed(Duration.zero);
    expect(controller.errors, 1);

    controller.initStream();
    controller.player.stream.errors.add('rebound');
    await Future<void>.delayed(Duration.zero);
    expect(controller.errors, 2);
    controller.disposeStream();
  });

  test('退出全屏等待期间立即解绑事件，关闭过程中不再重新订阅', () async {
    final controller = _Controller();
    addTearDown(controller.player.stream.close);
    final gate = Completer<void>();
    controller.exitGate = gate.future;
    controller.fullScreenState.value = true;
    controller.initStream();
    controller.onClose();
    controller.initStream();
    controller.player.stream.errors.add('late error');
    await Future<void>.delayed(Duration.zero);
    final errorsWhileClosing = controller.errors;
    gate.complete();
    await controller.player.disposed.future;
    expect(errorsWhileClosing, 0);
  });

  test('系统状态恢复失败仍释放播放器，不掩盖恢复错误', () async {
    final controller = _Controller()..failReset = true;
    addTearDown(controller.player.stream.close);
    final failure = Completer<Object>();
    runZonedGuarded(controller.onClose, (error, stack) {
      failure.complete(error);
    });
    expect(await failure.future, isA<StateError>());
    expect(controller.player.disposed.isCompleted, isTrue);
  });

  test('退出全屏失败仍释放播放器，不掩盖窗口错误', () async {
    final controller = _Controller();
    addTearDown(controller.player.stream.close);
    controller.fullScreenState.value = true;
    final failure = Completer<Object>();
    runZonedGuarded(() {
      final gate = Completer<void>();
      controller.exitGate = gate.future;
      controller.onClose();
      gate.completeError(StateError('fullscreen exit failed'));
    }, (error, stack) {
      failure.complete(error);
    });
    expect(await failure.future, isA<StateError>());
    expect(controller.player.disposed.isCompleted, isTrue);
  });
}
