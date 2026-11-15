import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  // 测试不初始化持久化设置。
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void setPlayerVolume(double value) => playerVolume.value = value;
}

class _Follows extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Stream implements PlayerStream {
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
  final volumes = <double>[];
  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  PlayerState get state => const PlayerState();
  @override
  PlayerStream get stream => _Stream();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VideoController implements VideoController {
  @override
  Player get player => _Player();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VideoState with Diagnosticable implements VideoState {
  _VideoState(this.context);
  @override
  final BuildContext context;
  @override
  Video get widget => Video(controller: _VideoController());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room extends LiveRoomController {
  _Room() : super(pSite: Sites.allSites['huya']!, pRoomId: '1');
  int exits = 0;
  int refreshes = 0;
  int screenshots = 0;
  int enters = 0;
  int followSheets = 0;
  int settingSheets = 0;
  int qualitySheets = 0;
  int lineSheets = 0;
  int danmakuSheets = 0;
  bool useNativeToggle = false;
  @override
  Future<void> onDoubleTap() async {
    if (useNativeToggle) {
      await super.onDoubleTap();
      return;
    }
    if (lockControlsState.value) return;
    if (fullScreenState.value) {
      await exitFull();
    } else {
      await enterFullScreen();
    }
  }

  @override
  Future<void> exitFull() async {
    exits++;
  }

  @override
  void refreshRoom() {
    refreshes++;
  }

  @override
  Future<void> saveScreenshot() async {
    screenshots++;
  }

  @override
  Future<void> enterFullScreen() async {
    enters++;
  }

  @override
  void showFollowUserSheet() => followSheets++;
  @override
  void showPlayerSettingsSheet() => settingSheets++;
  @override
  void showQualitySheet() => qualitySheets++;
  @override
  void showPlayUrlsSheet() => lineSheets++;
  @override
  void showDanmuSettingsSheet() => danmakuSheets++;
}

class _VolumeRoom extends _Room {
  final testPlayer = _Player();
  @override
  Player get player => testPlayer;
  @override
  void showVolumeSlider(BuildContext context) {
    if (useVolumePopup) super.showVolumeSlider(context);
  }
  bool useVolumePopup = false;
}

class _ControlsPage extends LiveRoomPage {
  const _ControlsPage(this.room);
  final _Room room;
  @override
  LiveRoomController get controller => room;
  @override
  Widget buildMediaPlayer() =>
      Builder(builder: (context) => playerControls(_VideoState(context), room));
  @override
  Widget buildUserProfile(BuildContext context) => const SizedBox(height: 48);
  @override
  Widget buildMessageArea() => const Expanded(child: SizedBox());
  @override
  List<Widget> buildAppbarActions(BuildContext context) => [];
}

void main() {
  testWidgets('画面滚轮只显示音量卡片，连续滚动更新数值并延后隐藏', (tester) async {
    final room = _VolumeRoom()..useVolumePopup = true;
    AppSettingsController.instance.playerVolume.value = 50;
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: Scaffold(body: playerVolumeScrollArea(controller: room,
        child: Stack(children: [
          Builder(builder: (context) => playerControls(_VideoState(context), room)),
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
        ]))),
    ));
    await tester.pump();
    void scroll() => tester.binding.handlePointerEvent(PointerScrollEvent(
      position: const Offset(100, 100), scrollDelta: const Offset(0, -120),
      kind: PointerDeviceKind.mouse));
    scroll();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('55%'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(room.showControlsState.value, isFalse);
    final popup = tester.getRect(find.byType(Slider));
    expect(popup.center.dx, greaterThan(400));
    expect(popup.center.dy, greaterThan(300));
    await tester.pump(const Duration(seconds: 2));
    scroll();
    await tester.pump();
    expect(find.text('60%'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('60%'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    room.hideControlsTimer?.cancel();
  });
  testWidgets('video foreground and black margins receive wheel input even above hidden controls', (tester) async {
    final room = _VolumeRoom();
    AppSettingsController.instance.playerVolume.value = 50;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [
      Expanded(child: playerVolumeScrollArea(controller: room, child: Stack(children: [
        Builder(builder: (context) => playerControls(_VideoState(context), room)),
        const Positioned.fill(child: ColoredBox(key: ValueKey('video-foreground'), color: Colors.black)),
      ]))),
      SizedBox(width: 180, child: ListView(children: List.generate(30, (n) => Text('聊天$n')))),
    ]))));
    await tester.pump();
    final video = tester.getRect(find.byKey(const ValueKey('video-foreground')));
    for (final point in [video.center, video.topLeft + const Offset(2, 2)]) {
      tester.binding.handlePointerEvent(PointerScrollEvent(position: point,
          scrollDelta: const Offset(0, -120), kind: PointerDeviceKind.mouse));
    }
    expect(AppSettingsController.instance.playerVolume.value, 60);
    expect(room.testPlayer.volumes, [55, 60]);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: video.center,
        scrollDelta: const Offset(0, 120), kind: PointerDeviceKind.mouse));
    expect(AppSettingsController.instance.playerVolume.value, 55);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: tester.getCenter(find.byType(ListView)),
        scrollDelta: const Offset(0, 120), kind: PointerDeviceKind.mouse));
    expect(AppSettingsController.instance.playerVolume.value, 55);
    await tester.pumpWidget(const SizedBox());
    room.hideControlsTimer?.cancel();
  });
  testWidgets('nested video and icon wheel handlers change volume only once', (tester) async {
    final room = _VolumeRoom();
    AppSettingsController.instance.playerVolume.value = 50;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: playerVolumeScrollArea(
      controller: room, child: Builder(
        builder: (context) => playerControls(_VideoState(context), room))))));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: const Offset(100, 100),
        scrollDelta: const Offset(0, -120), kind: PointerDeviceKind.mouse));
    expect(room.testPlayer.volumes, [55]);
  });
  testWidgets('真实房间和视频两层Focus共存，DFR每次只触发一次', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final room = _Room();
    await tester.pumpWidget(GetMaterialApp(home: _ControlsPage(room)));
    await tester.pump();
    final initial = room.showDanmakuState.value;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(room.showDanmakuState.value, !initial);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(room.enters, 1);
    room.fullScreenState.value = true;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(room.exits, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    expect(room.refreshes, 1);
    await tester.pumpWidget(const SizedBox());
    room.hideControlsTimer?.cancel();
  });
  for (final full in [false, true]) {
    testWidgets('非默认比例，全屏=$full，鼠标双击轻微抖动不应被竖向拖动抢走', (tester) async {
      tester.view.devicePixelRatio = 1.25;
      tester.view.physicalSize = const Size(1600, 1300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = _Room();
      room.fullScreenState.value = full;
      await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => playerControls(_VideoState(context), room),
      ))));
      for (final size in [
        const Size(1600, 1300),
        const Size(1900, 1000),
        const Size(800, 1200)
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        final point = tester.getCenter(find.byType(Scaffold));
        final mouse =
            await tester.startGesture(point, kind: PointerDeviceKind.mouse);
        await mouse.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 30));
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(point + const Offset(0, 6),
            kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(full ? room.exits : room.enters, 3);
      await tester.pumpWidget(const SizedBox());
      room.hideControlsTimer?.cancel();
    });
  }
  for (final full in [false, true]) {
    testWidgets('全屏=$full，画面滚轮调音量且音量按钮不重复调整', (tester) async {
      final room = _VolumeRoom();
      room.fullScreenState.value = full;
      room.showControlsState.value = true;
      AppSettingsController.instance.playerVolume.value = 50;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => playerControls(_VideoState(context), room),
      ))));
      await tester.pump(const Duration(milliseconds: 250));
      void scroll(Offset point, double dy) =>
          tester.binding.handlePointerEvent(PointerScrollEvent(
              position: point,
              scrollDelta: Offset(0, dy),
              kind: PointerDeviceKind.mouse));
      scroll(tester.getCenter(find.byType(Scaffold)), -120);
      expect(AppSettingsController.instance.playerVolume.value, 55);
      scroll(tester.getCenter(find.byType(Scaffold)), 120);
      expect(AppSettingsController.instance.playerVolume.value, 50);
      final volumeIcon = find.byIcon(Icons.volume_down);
      expect(volumeIcon, findsOneWidget);
      scroll(tester.getCenter(volumeIcon), -120);
      expect(AppSettingsController.instance.playerVolume.value, 55);
      expect(room.testPlayer.volumes, [55, 50, 55]);
      room.showControlsState.value = false;
      await tester.pump(const Duration(milliseconds: 250));
      scroll(tester.getCenter(find.byType(Scaffold)), -120);
      expect(AppSettingsController.instance.playerVolume.value, 60);
      expect(room.testPlayer.volumes, [55, 50, 55, 60]);
      await tester.pumpWidget(const SizedBox());
      room.hideControlsTimer?.cancel();
    });
  }
  testWidgets('评论区滚轮继续翻消息，不改变播放音量', (tester) async {
    final room = _VolumeRoom();
    final chatScroll = ScrollController();
    addTearDown(chatScroll.dispose);
    AppSettingsController.instance.playerVolume.value = 50;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Row(children: [
      Expanded(
          child: Builder(
              builder: (context) =>
                  playerControls(_VideoState(context), room))),
      SizedBox(
          width: 200,
          child: ListView.builder(
            key: const ValueKey('chat-scroll'),
            controller: chatScroll,
            itemCount: 100,
            itemExtent: 40,
            itemBuilder: (_, i) => Text('消息$i'),
          )),
    ]))));
    await tester.pump();
    tester.binding.handlePointerEvent(PointerScrollEvent(
      position: tester.getCenter(find.byKey(const ValueKey('chat-scroll'))),
      scrollDelta: const Offset(0, 120),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pump();
    expect(chatScroll.offset, greaterThan(0));
    expect(AppSettingsController.instance.playerVolume.value, 50);
    expect(room.testPlayer.volumes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    room.hideControlsTimer?.cancel();
  });
  for (final size in [const Size(480, 720), const Size(1920, 1080)]) {
    testWidgets('$size 视频中心连续双击 100 次并切换布局始终响应', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var nativeFullscreen = false;
      var requests = 0;
      const channel = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isFullScreen') return nativeFullscreen;
        if (call.method == 'setFullScreen') {
          nativeFullscreen = (call.arguments as Map)['isFullScreen'] as bool;
          requests++;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final room = _Room()..useNativeToggle = true;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => playerControls(_VideoState(context), room),
      ))));
      for (var i = 0; i < 100; i++) {
        final point = tester.getCenter(find.byType(Scaffold));
        await tester.tapAt(point, kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(point, kind: PointerDeviceKind.mouse);
        tester.view.physicalSize = i.isEven ? const Size(1920, 1080) : size;
        await tester.pump(const Duration(milliseconds: 350));
        expect(requests, i + 1, reason: '第 ${i + 1} 次双击');
        expect(nativeFullscreen, i.isEven);
        expect(room.fullScreenState.value, nativeFullscreen);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      room.hideControlsTimer?.cancel();
    });
  }
  final buttons = <String, Finder Function()>{
    '关注列表': () => find.byIcon(Remix.play_list_2_line),
    '设置': () => find.byIcon(Icons.more_horiz),
    '清晰度': () => find.text('原画'),
    '线路': () => find.text('线路1'),
    '弹幕设置': () => find.byType(ImageIcon).last,
  };
  for (final button in buttons.entries) {
    testWidgets('全屏${button.key}按钮实际打开可见弹层', (tester) async {
      Get.put<FollowService>(_Follows());
      final room = _Room();
      room.fullScreenState.value = true;
      room.showControlsState.value = true;
      room.showDanmakuState.value = true;
      room.currentQualityInfo.value = '原画';
      room.currentLineInfo.value = '线路1';
      room.qualites.add(LivePlayQuality(quality: '原画', data: {}));
      room.playUrls.add('https://example.com/live.flv');
      await tester.pumpWidget(GetMaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        navigatorObservers: [FlutterSmartDialog.observer],
        builder: FlutterSmartDialog.init(),
        home: Scaffold(
            body: Builder(
          builder: (context) => buildFullControls(_VideoState(context), room),
        )),
      ));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(button.value());
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(button.key), findsWidgets);
      SmartDialog.dismiss(status: SmartStatus.allCustom);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox.shrink());
      room.hideControlsTimer?.cancel();
    });
  }
  testWidgets('播放器右侧系统弹层在导航页上可见', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Utils.showRightDialog(
              title: '线路',
              useSystem: true,
              child: const Text('线路1'),
            ),
            child: const Text('打开线路'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开线路'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('线路1'), findsOneWidget);
  });
  testWidgets('播放器底部弹层在全屏页面可见', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: PopScope(
        canPop: false,
        child: Scaffold(
          body: TextButton(
            onPressed: () => Utils.showBottomSheet(
              title: '切换线路',
              child: const Text('线路1'),
            ),
            child: const Text('打开线路'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开线路'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('线路1'), findsOneWidget);
  });
  test('鼠标侧键识别器不参与左键和触摸手势竞争', () {
    final recognizer = FourthButtonTapGestureRecognizer();
    expect(
        recognizer
            .isPointerAllowed(const PointerDownEvent(buttons: kPrimaryButton)),
        isFalse);
    expect(
        recognizer.isPointerAllowed(const PointerDownEvent(
            kind: PointerDeviceKind.mouse, buttons: kBackMouseButton)),
        isTrue);
    recognizer.dispose();
  });
  setUp(() {
    Get.put<AppSettingsController>(_Settings());
    AppSettingsController.instance.playershowSuperChat.value = false;
  });
  tearDown(() => Get.reset());
  testWidgets('第二次点击松开后才切换全屏，不在按下时重建播放区域', (tester) async {
    final room = _Room();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => buildControls(false, _VideoState(context), room),
    ))));
    final point = tester.getCenter(find.byType(Scaffold));
    await tester.tapAt(point, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 80));
    final gesture =
        await tester.startGesture(point, kind: PointerDeviceKind.mouse);
    expect(room.enters, 0);
    await gesture.up();
    expect(room.enters, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    room.hideControlsTimer?.cancel();
  });
  for (final full in [false, true]) {
    testWidgets('${full ? "全屏" : "普通"}控制层不因同方向尺寸变化重新构造', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final room = _Room();
      room.fullScreenState.value = full;
      var builds = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
        builder: (context) {
          builds++;
          return playerControls(_VideoState(context), room);
        },
      ))));
      final initial = builds;
      for (var i = 1; i <= 20; i++) {
        tester.view.physicalSize = Size(1200 + i * 10, 800);
        await tester.pump();
      }
      debugPrint(
          '20 次 resize：${full ? "全屏" : "普通"}控制层构造 ${builds - initial} 次');
      expect(builds, initial);
      await tester.pumpWidget(const SizedBox.shrink());
      room.hideControlsTimer?.cancel();
    });
    testWidgets('${full ? "全屏" : "普通"}控件可点击且不触发画面手势', (tester) async {
      final room = _Room();
      room.fullScreenState.value = full;
      room.showControlsState.value = true;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
              body: RawGestureDetector(
                  gestures: {
                FourthButtonTapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        FourthButtonTapGestureRecognizer>(
                  FourthButtonTapGestureRecognizer.new,
                  (recognizer) => recognizer.onTap = () {},
                ),
              },
                  child: Builder(
                    builder: (context) => full
                        ? buildFullControls(_VideoState(context), room)
                        : buildControls(false, _VideoState(context), room),
                  )))));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byIcon(Remix.refresh_line));
      expect(room.refreshes, 1);
      expect(room.showControlsState.value, isTrue);
      if (full) {
        await tester.tap(find.byIcon(Icons.camera_alt_outlined));
        expect(room.screenshots, 1);
        await tester.tap(find.byIcon(Remix.fullscreen_exit_fill));
        expect(room.exits, 1);
        await tester.tap(find.byIcon(Icons.arrow_back));
        expect(room.exits, 2);
      }
      final point = tester.getCenter(find.byType(Scaffold));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      expect(full ? room.exits : room.enters, full ? 3 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
      room.hideControlsTimer?.cancel();
    });
  }
  testWidgets('竖屏全屏右上角和右下角按钮可点击', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final room = _Room();
    room.fullScreenState.value = true;
    room.showControlsState.value = true;
    room.showDanmakuState.value = true;
    room.isVertical.value = true;
    room.currentQualityInfo.value = '原画';
    room.currentLineInfo.value = '线路1';
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
          body: Builder(
        builder: (context) => buildFullControls(_VideoState(context), room),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    expect(room.screenshots, 1);
    await tester.tap(find.byIcon(Remix.play_list_2_line));
    expect(room.followSheets, 1);
    await tester.tap(find.byIcon(Icons.more_horiz));
    expect(room.settingSheets, 1);
    await tester.tap(find.text('原画'));
    expect(room.qualitySheets, 1);
    await tester.tap(find.text('线路1'));
    expect(room.lineSheets, 1);
    await tester.tap(find.byType(ImageIcon).last);
    expect(room.danmakuSheets, 1);
    await tester.tap(find.byIcon(Remix.fullscreen_exit_fill));
    expect(room.exits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    room.hideControlsTimer?.cancel();
  });
  testWidgets('切换为全屏并改变尺寸后，右侧按钮继续响应', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final room = _Room();
    room.showControlsState.value = true;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
          body: Builder(
        builder: (context) => playerControls(_VideoState(context), room),
      )),
    ));
    room.fullScreenState.value = true;
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    expect(room.screenshots, 1);
    await tester.tap(find.byIcon(Remix.fullscreen_exit_fill));
    expect(room.exits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    room.hideControlsTimer?.cancel();
  });
}
