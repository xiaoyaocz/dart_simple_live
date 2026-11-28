import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:window_manager/window_manager.dart';

class _TestPlayer
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  var maximized = false;
  var nativeFullscreen = false;

  setUp(() {
    calls = [];
    maximized = false;
    nativeFullscreen = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'isFullScreen') return nativeFullscreen;
      if (call.method == 'setFullScreen') {
        nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      if (call.method == 'isMaximized') return maximized;
      if (call.method == 'unmaximize') maximized = false;
      if (call.method == 'maximize') maximized = true;
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('切换查询异常后释放锁，后续双击仍能切换', () async {
    var fail = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isFullScreen') {
        if (fail) throw PlatformException(code: 'query-failed');
        return nativeFullscreen;
      }
      if (call.method == 'setFullScreen') {
        nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      return null;
    });
    final controller = _TestPlayer();
    await expectLater(
        controller.onDoubleTap(), throwsA(isA<PlatformException>()));
    fail = false;
    await controller.onDoubleTap();
    expect(nativeFullscreen, isTrue);
    await controller.onDoubleTap();
    expect(nativeFullscreen, isFalse);
  });

  test('查询尚未完成时连续双击不会交叉发出全屏请求', () async {
    final queried = Completer<void>();
    var requests = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isFullScreen') {
        await queried.future;
        return nativeFullscreen;
      }
      if (call.method == 'setFullScreen') {
        requests++;
        nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      return null;
    });
    final controller = _TestPlayer();
    final first = controller.onDoubleTap();
    await controller.onDoubleTap();
    await controller.onDoubleTap();
    queried.complete();
    await first;
    expect(requests, 1);
    expect(controller.fullScreenState.value, nativeFullscreen);
    await controller.onDoubleTap();
    expect(requests, 2);
    expect(nativeFullscreen, isFalse);
  });

  for (final native in [false, true]) {
    test('双击以实际窗口状态切换，纠正过期的 $native 全屏状态', () async {
      nativeFullscreen = native;
      final controller = _TestPlayer();
      controller.fullScreenState.value = !native;
      await controller.onDoubleTap();
      expect(nativeFullscreen, !native);
      expect(controller.fullScreenState.value, !native);
    });
  }

  test('恢复默认窗口尺寸失败后仍可重试', () async {
    var fail = true;
    var sizes = 0;
    maximized = true;
    nativeFullscreen = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isFullScreen') return nativeFullscreen;
      if (call.method == 'setFullScreen') {
        nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      if (call.method == 'isMaximized') return maximized;
      if (call.method == 'unmaximize') maximized = false;
      if (call.method == 'setBounds') {
        sizes++;
        if (fail) throw PlatformException(code: 'resize-failed');
        expect((call.arguments as Map)['width'], 1280);
        expect((call.arguments as Map)['height'], 720);
      }
      return null;
    });
    final controller = _TestPlayer();
    await expectLater(controller.restoreDefaultWindowSize(),
        throwsA(isA<PlatformException>()));
    fail = false;
    await controller.restoreDefaultWindowSize();
    expect(sizes, 2);
    expect(maximized, isFalse);
    expect(nativeFullscreen, isFalse);
    expect(controller.fullScreenState.value, isFalse);
  });

  test('恢复尺寸期间重复双击不重复设置窗口，也不插入全屏', () async {
    final gate = Completer<void>();
    var resizes = 0;
    var fullscreenRequests = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isFullScreen') return false;
      if (call.method == 'isMaximized') return false;
      if (call.method == 'setFullScreen') fullscreenRequests++;
      if (call.method == 'setBounds') {
        resizes++;
        await gate.future;
      }
      return null;
    });
    final controller = _TestPlayer();
    final restoring = controller.restoreDefaultWindowSize();
    await Future<void>.delayed(Duration.zero);
    await controller.restoreDefaultWindowSize();
    await controller.onDoubleTap();
    expect(resizes, 1);
    expect(fullscreenRequests, 0);
    gate.complete();
    await restoring;
  });

  test('Windows 调整窗口尺寸前准备全屏布局', () async {
    final fullscreenComplete = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isMaximized') return false;
      if (call.method == 'isFullScreen') return nativeFullscreen;
      if (call.method == 'setFullScreen') {
        await fullscreenComplete.future;
        nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      return null;
    });
    final controller = _TestPlayer();

    final entering = controller.enterFullScreen();
    await Future<void>.delayed(Duration.zero);
    expect(controller.fullScreenState.value, isTrue);

    fullscreenComplete.complete();
    await entering;
    expect(controller.fullScreenState.value, isTrue);
  });

  test('Windows 调整窗口尺寸前准备原窗口布局', () async {
    final fullscreenComplete = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isFullScreen') return nativeFullscreen;
      if (call.method == 'setFullScreen') {
        await fullscreenComplete.future;
        nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      return null;
    });
    final controller = _TestPlayer();
    nativeFullscreen = true;
    controller.fullScreenState.value = true;

    final exiting = controller.exitFull();
    await Future<void>.delayed(Duration.zero);
    expect(controller.fullScreenState.value, isFalse);

    fullscreenComplete.complete();
    await exiting;
    expect(controller.fullScreenState.value, isFalse);
  });

  for (final entering in [true, false]) {
    test('Windows ${entering ? "进入" : "退出"}全屏失败时恢复布局并允许重试', () async {
      var fail = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isMaximized') return false;
        if (call.method == 'isFullScreen') return nativeFullscreen;
        if (call.method == 'setFullScreen' && fail) {
          throw PlatformException(code: 'fullscreen-failed');
        }
        if (call.method == 'setFullScreen') {
          nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
        }
        return null;
      });
      final controller = _TestPlayer();
      controller.fullScreenState.value = !entering;
      nativeFullscreen = !entering;
      Future<void> toggle() =>
          entering ? controller.enterFullScreen() : controller.exitFull();

      await expectLater(toggle(), throwsA(isA<PlatformException>()));
      expect(controller.fullScreenState.value, !entering);
      fail = false;
      await toggle();
      expect(controller.fullScreenState.value, entering);
    });
  }

  testWidgets('普通全屏画面不拖动窗口，小窗仍能拖动', (tester) async {
    const content = SizedBox(key: ValueKey('player'));
    await tester.pumpWidget(MaterialApp(
      home: playerWindowDragArea(child: content, isSmallWindow: false),
    ));
    expect(find.byType(DragToMoveArea), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: playerWindowDragArea(child: content, isSmallWindow: true),
    ));
    expect(find.byType(DragToMoveArea), findsOneWidget);
  });

  test('最大化窗口直接往返全屏，不经过普通窗口或重复最大化', () async {
    maximized = true;
    final controller = _TestPlayer();

    await controller.enterFullScreen();
    expect(controller.fullScreenState.value, isTrue);
    expect(calls, ['isFullScreen', 'setFullScreen', 'isFullScreen']);
    expect(maximized, isTrue);

    calls.clear();
    await controller.exitFull();
    expect(controller.fullScreenState.value, isFalse);
    expect(calls, ['isFullScreen', 'setFullScreen', 'isFullScreen']);
    expect(maximized, isTrue);
  });

  test('普通窗口全屏退出后保持普通窗口', () async {
    final controller = _TestPlayer();

    await controller.enterFullScreen();
    expect(calls, ['isFullScreen', 'setFullScreen', 'isFullScreen']);

    calls.clear();
    await controller.exitFull();
    expect(calls, ['isFullScreen', 'setFullScreen', 'isFullScreen']);
  });

  for (final wasMaximized in [false, true]) {
    test('${wasMaximized ? "大屏" : "小屏"}双击进入再双击退出恢复原窗口状态', () async {
      maximized = wasMaximized;
      final controller = _TestPlayer();
      controller.onDoubleTap();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.fullScreenState.value, isTrue);

      calls.clear();
      controller.onDoubleTap();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.fullScreenState.value, isFalse);
      expect(calls, ['isFullScreen', 'setFullScreen', 'isFullScreen']);
      expect(maximized, wasMaximized);
    });
  }

  test('小窗退出恢复窗口，不走普通全屏退出', () async {
    final controller = _TestPlayer();
    controller.smallWindowState.value = true;
    controller.fullScreenState.value = true;

    await controller.exitFull();

    expect(controller.smallWindowState.value, isFalse);
    expect(controller.fullScreenState.value, isFalse);
    expect(calls, ['setTitleBarStyle', 'setAlwaysOnTop']);
  });
}
