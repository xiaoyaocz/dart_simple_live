import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/fullscreen_follow_panel.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Follows extends FollowService {
  int loadCount = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadData({bool updateStatus = true}) async {
    loadCount++;
  }
}

class _Stream implements PlayerStream {
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
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
  _Room() : super(pSite: Sites.allSites['huya']!, pRoomId: 'lol1');
  final List<(Site, String)> resetRooms = [];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onClose() {}

  @override
  void resetRoom(Site site, String roomId) {
    resetRooms.add((site, roomId));
    rxSite.value = site;
    rxRoomId.value = roomId;
  }
}

FollowUser _user(
  String id,
  String site,
  String? category,
  int status, {
  int? heat,
  String? startTime,
}) {
  return FollowUser(
    id: '${site}_$id',
    roomId: id,
    siteId: site,
    userName: id,
    face: '',
    addTime: DateTime(2026),
    categoryName: category,
  )
    ..heat = heat
    ..liveStartTime = startTime
    ..liveStatus.value = status;
}

void _seedFollows(_Follows service) {
  final users = [
    _user('lol1', 'huya', '英雄联盟', 2, heat: 200),
    _user('lol2', 'huya', '英雄联盟', 2, heat: 100),
    _user('val1', 'douyin', '无畏契约', 2, heat: 80),
    _user('other1', 'huya', null, 2, heat: 10),
    _user('off1', 'huya', '英雄联盟', 1),
  ];
  service.followList.assignAll(users);
  service.liveList.assignAll(users.where((u) => u.liveStatus.value == 2));
  service.notLiveList.assignAll(users.where((u) => u.liveStatus.value == 1));
  service.followTagList.assignAll([
    FollowUserTag(id: 'custom_1', tag: '常看', userId: ['douyin_val1']),
  ]);
}

Finder _filterPill(String label) => find.descendant(
      of: find.descendant(
        of: find.byType(FullscreenFollowPanel),
        matching: find.byType(SingleChildScrollView),
      ),
      matching: find.text(label),
    );

Finder _panelIcon(IconData icon) => find.descendant(
      of: find.byType(FullscreenFollowPanel),
      matching: find.byIcon(icon),
    );

void main() {
  setUp(() {
    final settings = Get.put<AppSettingsController>(_Settings());
    settings.siteSort.assignAll(['huya', 'douyin', 'bilibili', 'douyu']);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  test('computeFullscreenFollowLayout 按桌面与手机横竖屏比例自适应', () {
    final desktop1080 = computeFullscreenFollowLayout(
      const Size(1920, 1080),
      EdgeInsets.zero,
      isMobile: false,
    );
    expect(desktop1080.panelWidth, 660.0);
    expect(desktop1080.crossAxisCount, 2);
    expect(desktop1080.compactStyle.avatarSize, 38);

    final desktop720 = computeFullscreenFollowLayout(
      const Size(1280, 720),
      EdgeInsets.zero,
      isMobile: false,
    );
    expect(desktop720.panelWidth, closeTo(563.2, 0.01));
    expect(desktop720.crossAxisCount, 2);

    final desktopNarrow = computeFullscreenFollowLayout(
      const Size(800, 600),
      EdgeInsets.zero,
      isMobile: false,
    );
    expect(desktopNarrow.panelWidth, closeTo(352.0, 0.01));
    expect(desktopNarrow.crossAxisCount, 1);

    final mobileCutout = computeFullscreenFollowLayout(
      const Size(852, 393),
      const EdgeInsets.only(left: 47, right: 47),
      isMobile: true,
    );
    expect(mobileCutout.panelWidth, closeTo(394.16, 0.01));
    expect(mobileCutout.crossAxisCount, 2);
    expect(mobileCutout.compactStyle.avatarSize, 30);

    final mobileWide = computeFullscreenFollowLayout(
      const Size(800, 360),
      EdgeInsets.zero,
      isMobile: true,
    );
    expect(mobileWide.panelWidth, closeTo(416.0, 0.01));
    expect(mobileWide.crossAxisCount, 2);

    final mobileNarrow = computeFullscreenFollowLayout(
      const Size(640, 360),
      EdgeInsets.zero,
      isMobile: true,
    );
    expect(mobileNarrow.panelWidth, closeTo(332.8, 0.01));
    expect(mobileNarrow.crossAxisCount, 1);

    final mobileTablet = computeFullscreenFollowLayout(
      const Size(1024, 768),
      EdgeInsets.zero,
      isMobile: true,
    );
    expect(mobileTablet.panelWidth, 520.0);
    expect(mobileTablet.crossAxisCount, 2);

    final mobilePortrait = computeFullscreenFollowLayout(
      const Size(360, 780),
      EdgeInsets.zero,
      isMobile: true,
    );
    expect(mobilePortrait.panelWidth, 240.0);
  });

  testWidgets('桌面端全屏长按从左侧打开分类两列关注面板并支持筛选刷新切房',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final follows = _Follows();
    Get.put<FollowService>(follows);
    _seedFollows(follows);
    final room = _Room();
    room.fullScreenState.value = true;
    room.showControlsState.value = false;

    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: Scaffold(
        body: Builder(
          builder: (context) => buildFullControls(_VideoState(context), room),
        ),
      ),
    ));
    await tester.pump();

    await tester.longPressAt(tester.getCenter(find.byType(Scaffold)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(FullscreenFollowPanel), findsOneWidget);
    final panelRect = tester.getRect(find.byType(FullscreenFollowPanel));
    expect(panelRect.left, 0.0);
    expect(panelRect.width, closeTo(660.0, 1.0));

    expect(find.text('关注列表'), findsOneWidget);
    expect(find.text('英雄联盟 2人'), findsOneWidget);
    expect(find.text('无畏契约 1人'), findsOneWidget);
    expect(find.text('其他 1人'), findsOneWidget);
    expect(find.textContaining('正在观看'), findsOneWidget);

    final card1 = tester.getRect(find.widgetWithText(FollowUserItem, 'lol1'));
    final card2 = tester.getRect(find.widgetWithText(FollowUserItem, 'lol2'));
    expect(card1.top, card2.top);
    expect(card2.left, greaterThan(card1.right));

    await tester.tap(_filterPill('全部'));
    await tester.pump();
    expect(find.text('英雄联盟 3人'), findsOneWidget);
    expect(find.text('off1'), findsOneWidget);

    await tester.tap(_filterPill('未开播'));
    await tester.pump();
    expect(find.text('英雄联盟 1人'), findsOneWidget);
    expect(find.text('lol1'), findsNothing);

    await tester.tap(_filterPill('常看'));
    await tester.pump();
    expect(find.text('无畏契约 1人'), findsOneWidget);
    expect(find.text('val1'), findsOneWidget);

    await tester.tap(_panelIcon(Icons.refresh));
    await tester.pump();
    expect(follows.loadCount, 1);

    await tester.tap(_filterPill('直播中'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FollowUserItem, 'lol2'));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenFollowPanel), findsNothing);
    expect(room.resetRooms, [(Sites.allSites['huya']!, 'lol2')]);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    room.hideControlsTimer?.cancel();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('手机端横屏全屏长按从右侧打开紧凑分类面板且无溢出', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(840, 380);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final follows = _Follows();
    Get.put<FollowService>(follows);
    _seedFollows(follows);
    final room = _Room();
    room.fullScreenState.value = true;
    room.showControlsState.value = false;

    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: Scaffold(
        body: Builder(
          builder: (context) => buildFullControls(_VideoState(context), room),
        ),
      ),
    ));
    await tester.pump();

    await tester.longPressAt(tester.getCenter(find.byType(Scaffold)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(FullscreenFollowPanel), findsOneWidget);
    final panelRect = tester.getRect(find.byType(FullscreenFollowPanel));
    expect(panelRect.right, closeTo(840.0, 0.5));
    expect(panelRect.width, closeTo(436.8, 1.0));

    expect(find.text('英雄联盟 2人'), findsOneWidget);
    final card1 = tester.getRect(find.widgetWithText(FollowUserItem, 'lol1'));
    final card2 = tester.getRect(find.widgetWithText(FollowUserItem, 'lol2'));
    expect(card1.top, card2.top);
    expect(card2.left, greaterThan(card1.right));
    expect(tester.takeException(), isNull);

    await tester.tap(_panelIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenFollowPanel), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    room.hideControlsTimer?.cancel();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('竖屏全屏关注弹窗也复用分类关注面板并支持切换主播', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final follows = _Follows();
    Get.put<FollowService>(follows);
    _seedFollows(follows);
    final room = _Room();
    room.isVertical.value = true;

    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: TextButton(
          onPressed: room.showFollowUserSheet,
          child: const Text('打开竖屏关注'),
        ),
      ),
    ));
    await tester.tap(find.text('打开竖屏关注'));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenFollowPanel), findsOneWidget);
    expect(find.text('关注列表'), findsOneWidget);
    expect(find.text('英雄联盟 2人'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FollowUserItem, 'val1'));
    await tester.pumpAndSettle();
    expect(room.resetRooms, [(Sites.allSites['douyin']!, 'val1')]);

    await tester.pumpWidget(const SizedBox.shrink());
    room.hideControlsTimer?.cancel();
    debugDefaultTargetPlatformOverride = null;
  });
}
