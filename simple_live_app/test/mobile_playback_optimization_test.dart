import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Player implements Player {
  @override
  PlayerState get state => const PlayerState(width: 720, height: 1280);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _System
    with PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin, PlayerSystemMixin {
  final _fakePlayer = _Player();

  @override
  Player get player => _fakePlayer;
}

class _MobileRoom extends LiveRoomController {
  _MobileRoom() : super(pSite: Sites.allSites['douyin']!, pRoomId: '1');

  @override
  bool get usesCellularQuality => true;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const floating = MethodChannel('floating');
  const pipEvents = MethodChannel('simple_live/pip');
  final mobile = TargetPlatformVariant.only(TargetPlatform.android);

  setUp(() {
    final settings = Get.put<AppSettingsController>(_Settings());
    settings.qualityLevel.value = 2;
    settings.qualityLevelCellular.value = 0;
    settings.pipHideDanmu.value = true;
    Floating().reset();
  });
  tearDown(() {
    for (final channel in [connectivity, floating, pipEvents]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    Get.reset();
  });

  for (final (transports, preference) in [
    (['vpn', 'mobile'], 0),
    (['mobile', 'wifi'], 2),
  ]) {
    testWidgets('Android 网络 $transports 选择对应画质，查询只执行一次', (tester) async {
      var calls = 0;
      messenger.setMockMethodCallHandler(connectivity, (_) async {
        calls++;
        return transports;
      });
      final room = _MobileRoom();
      addTearDown(room.scrollController.dispose);
      expect(await room.getQualityLevel(), preference);
      expect(await room.getQualityLevel(), preference);
      expect(calls, 1);
    }, variant: mobile);
  }

  testWidgets('网络插件无响应时，画质查询仍能在进房时结束', (tester) async {
    final response = Completer<List<String>>();
    messenger.setMockMethodCallHandler(connectivity, (_) => response.future);
    final room = _MobileRoom();
    addTearDown(room.scrollController.dispose);
    final quality = room.getQualityLevel();
    await tester.pump(const Duration(milliseconds: 701));
    expect(await quality, 2);
    response.complete(['mobile']);
    await tester.pump();
    expect(await room.getQualityLevel(), 2);
  }, variant: mobile);

  testWidgets('小窗请求失败保留界面，成功后退出恢复原状态且停止监听', (tester) async {
    var enabled = false;
    var requests = 0;
    final operations = <String>[];
    messenger.setMockMethodCallHandler(pipEvents, (call) async {
      operations.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(floating, (call) async {
      if (call.method == 'pipAvailable') return true;
      if (call.method == 'enablePip') {
        requests++;
        return enabled;
      }
      return null;
    });
    final system = _System();
    system.showDanmakuState.value = true;
    system.showControlsState.value = true;

    await Future.wait([system.enablePIP(), system.enablePIP()]);
    expect(requests, 1);
    expect(system.showDanmakuState.value, isTrue);
    expect(system.showControlsState.value, isTrue);
    expect(operations, isEmpty);

    enabled = true;
    await system.enablePIP();
    await tester.pump();
    expect(system.showDanmakuState.value, isFalse);
    expect(system.showControlsState.value, isFalse);
    expect(operations, ['listen']);
    await messenger.handlePlatformMessage(
      pipEvents.name,
      const StandardMethodCodec().encodeSuccessEnvelope(false),
      (_) {},
    );
    await tester.pump();
    expect(system.showDanmakuState.value, isTrue);
    expect(system.showControlsState.value, isTrue);
    expect(operations, ['listen', 'cancel']);
  }, variant: mobile);

  testWidgets('封面按布局和像素比限制解码宽度', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(devicePixelRatio: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: SizedBox(
          width: 175,
          height: 110,
          child: NetImage('https://example.com/cover.jpg', resizeToWidth: true),
        )),
      ),
    ));
    final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage));
    final provider = image.image as ExtendedResizeImage;
    expect(provider.width, 525);
  });
}
