import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/services/native_refresh_controller.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _SourceStreams implements PlayerStream {
  final events = StreamController<Tracks>.broadcast();
  @override
  Stream<Tracks> get tracks => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => const Stream<Never>.empty();
}

class _SourcePlayer implements Player {
  @override
  final _SourceStreams stream = _SourceStreams();
  @override
  PlayerState get state => const PlayerState();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends PlayerController {
  final fake = _SourcePlayer();
  @override
  _SourcePlayer get player => fake;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('simple_live/display_refresh');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'capabilities') {
        return {
          'rates': [60.0, 90.0, 120.0],
          'current': 60.0
        };
      }
      return call.method == 'set' ? call.arguments['hz'] : 60.0;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('source FPS remains distinct from the actual system display Hz',
      () async {
    final controller = NativeRefreshController();
    await controller.refresh();
    await controller.updateSource(120);
    expect(controller.sourceFps.value, 120);
    expect(controller.displayHz.value, 60);
    await controller.updateSource(double.nan);
    expect(controller.sourceFps.value, 0);
    await controller.dispose();
    expect(calls.map((c) => c.method), ['capabilities']);
  });

  test('late capabilities after disposal cannot publish stale display data',
      () async {
    final gate = Completer<dynamic>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => gate.future);
    final controller = NativeRefreshController();
    final updating = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.dispose();
    gate.complete({'current': 120.0});
    await updating;
    expect(controller.displayHz.value, 0);
  });

  test('missing native APIs do not interrupt playback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    final controller = NativeRefreshController();
    await controller.refresh();
    await controller.updateSource(60);
    expect(controller.sourceFps.value, 60);
    await controller.dispose();
  });

  test('real player metadata updates never trigger extra native calls',
      () async {
    Get.put<AppSettingsController>(_Settings());
    final controller = _Controller();
    try {
      controller.initNativeRefresh();
      await Future<void>.delayed(Duration.zero);
      final before = calls.length;
      for (final fps in [60.0, 90.0, 120.0]) {
        controller.player.stream.events.add(Tracks(
          video: [VideoTrack('1', null, null, fps: fps)],
        ));
        await Future<void>.delayed(Duration.zero);
        expect(calls.length, before);
      }
    } finally {
      controller.disposeStream();
      await controller.player.stream.events.close();
      await Future<void>.delayed(Duration.zero);
      Get.reset();
    }
    expect(calls.map((c) => c.method), ['capabilities']);
  });
}
