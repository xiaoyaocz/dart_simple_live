import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/native_refresh_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('simple_live/display_refresh');
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'capabilities'
          ? {
              'current': 120.0,
              'rates': [60.0, 90.0, 120.0]
            }
          : 60.0;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test(
      'entry, metadata, background and exit never request display mode changes',
      () async {
    final controller = NativeRefreshController();
    controller.start();
    await controller.refresh();
    for (final fps in [60.0, 90.0, 120.0, 60.0]) {
      await controller.updateSource(fps);
      expect(controller.sourceFps.value, fps);
    }
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await controller.refresh();
    expect(controller.displayHz.value, 120);
    await controller.dispose();
    expect(calls, isNotEmpty);
    expect(calls.every((method) => method == 'capabilities'), isTrue,
        reason:
            'Room lifecycle must not switch or restore physical display modes');
  });

  test('track metadata does not repeatedly enumerate native display modes',
      () async {
    final controller = NativeRefreshController();
    await controller.refresh();
    final before = calls.length;
    for (var i = 0; i < 20; i++) {
      await controller.updateSource(i.isEven ? 60 : 120);
    }
    expect(calls.length, before);
    await controller.dispose();
  });

  test('native runners have no physical display mode mutation entry points',
      () {
    final windows =
        File('windows/runner/flutter_window.cpp').readAsStringSync();
    final android =
        File('android/app/src/main/kotlin/com/xycz/simple_live/MainActivity.kt')
            .readAsStringSync();
    expect(windows, isNot(contains('ChangeDisplaySettingsExW')));
    expect(android, isNot(contains('window.attributes =')));
  });
}
