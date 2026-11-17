import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
// 直接验证项目内 Windows 插件的生命周期。
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/src/in_app_webview/custom_platform_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel =
      MethodChannel('com.pichillilorenzo/flutter_inappwebview_manager');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('点击网页不重复调整原生纹理尺寸，真实尺寸或 DPI 变化仍上报', (tester) async {
    const native = MethodChannel('com.pichillilorenzo/custom_platform_view_123');
    const events = MethodChannel('com.pichillilorenzo/custom_platform_view_123_events');
    final sizes = <List<dynamic>>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async =>
        call.method == 'createInAppWebView' ? 123 : null);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'setSize') sizes.add(List<dynamic>.from(call.arguments));
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(native, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    Future<void> show(double width, double scale) async {
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: 376,
              child: CustomPlatformView(scaleFactor: scale)))));
      await tester.pumpAndSettle();
    }
    await show(375, 1);
    expect(sizes, [[375.0, 376.0, 1.0]]);
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byType(CustomPlatformView));
      await tester.pump();
    }
    expect(sizes, hasLength(1),
        reason: 'Every redundant setSize recreates the native capture frame pool');
    await show(400, 1);
    expect(sizes, [[375.0, 376.0, 1.0], [400.0, 376.0, 1.0]]);
    await show(400, 1.5);
    await tester.tap(find.byType(CustomPlatformView));
    await tester.pump();
    expect(sizes.last, [400.0, 376.0, 1.5]);
    expect(sizes, hasLength(3));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('原生创建失败后初始化等待和释放不能永久挂起', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: '0', message: '无法创建网页组件');
    });
    final controller = CustomPlatformViewController();
    await expectLater(
        controller.initialize(), throwsA(isA<PlatformException>()));
    await expectLater(
        controller.ready.timeout(const Duration(milliseconds: 100)), completes);
    await expectLater(
        controller.dispose().timeout(const Duration(milliseconds: 100)),
        completes);
  });

  test('退出页面后才创建成功的组件必须释放且不再调用页面回调', () async {
    final creation = Completer<int>();
    final disposed = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createInAppWebView') return creation.future;
      if (call.method == 'dispose') disposed.add(call.arguments['id'] as int);
      return null;
    });
    final controller = CustomPlatformViewController();
    var callbackCalled = false;
    final initialization = controller.initialize(
        onPlatformViewCreated: (_) => callbackCalled = true);
    final disposal = controller.dispose();
    creation.complete(123);
    await initialization;
    await disposal.timeout(const Duration(milliseconds: 100));
    expect(callbackCalled, isFalse);
    expect(disposed, [123]);
  });
}
