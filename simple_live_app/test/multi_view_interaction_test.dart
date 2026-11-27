import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_page.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_slot.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';

class _TestSettings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {
    siteSort.assignAll(['huya', 'douyu', 'bilibili', 'douyin']);
  }

  @override
  void setPlayerVolume(double value) {
    playerVolume.value = value;
  }
}

class _TestFollowService extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadData({bool updateStatus = true}) async {}
}

class _TestMultiViewController extends MultiViewController {
  int toggleFullscreenCalls = 0;
  int exitFullscreenCalls = 0;
  int refreshedSlot = -1;
  int openedSingleRoomSlot = -1;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> toggleFullScreen() async {
    toggleFullscreenCalls++;
    fullScreen.value = !fullScreen.value;
  }

  @override
  Future<void> exitFullScreen() async {
    exitFullscreenCalls++;
    fullScreen.value = false;
  }

  @override
  Future<void> refreshSlot(int index) async {
    refreshedSlot = index;
  }

  @override
  Future<void> openInSingleRoom(int index) async {
    openedSingleRoomSlot = index;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestSettings settings;
  late _TestFollowService followService;
  late _TestMultiViewController controller;

  setUp(() {
    Get.reset();
    settings = Get.put<AppSettingsController>(_TestSettings()) as _TestSettings;
    followService =
        Get.put<FollowService>(_TestFollowService()) as _TestFollowService;
    controller = Get.put<MultiViewController>(_TestMultiViewController())
        as _TestMultiViewController;
  });

  tearDown(() {
    Get.reset();
  });

  void seedTwoRooms() {
    const r0 = MultiViewRoomRef(
      siteId: 'huya',
      roomId: '101',
      userName: '主播A',
    );
    const r1 = MultiViewRoomRef(
      siteId: 'douyu',
      roomId: '202',
      userName: '主播B',
    );
    controller.layoutState.assignSlot(0, r0);
    controller.layoutState.assignSlot(1, r1);
    controller.tiles[0].room.value = r0;
    controller.tiles[1].room.value = r1;
    controller.activeAudioIndex.value = 0;
  }

  testWidgets('全屏后底部悬浮工具栏不与右上角窗口按键重叠', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    seedTwoRooms();
    controller.fullScreen.value = true;

    await tester.pumpWidget(const GetMaterialApp(home: MultiViewPage()));
    await tester.pumpAndSettle();

    final exitBtnRect = tester.getRect(find.byIcon(Icons.fullscreen_exit));
    final closeBtnRects =
        find.byIcon(Icons.close).evaluate().map((e) => tester.getRect(find.byElementPredicate((el) => el == e))).toList();
    final openRoomRects =
        find.byIcon(Icons.open_in_full).evaluate().map((e) => tester.getRect(find.byElementPredicate((el) => el == e))).toList();

    expect(closeBtnRects, hasLength(2));
    for (final rect in [...closeBtnRects, ...openRoomRects]) {
      expect(exitBtnRect.overlaps(rect), isFalse);
    }
  });

  testWidgets('F 键切换全屏、R 键刷新选中直播间、前侧键进入选中直播间', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    seedTwoRooms();
    controller.selectAudioSlot(1);

    await tester.pumpWidget(const GetMaterialApp(home: MultiViewPage()));
    await tester.pumpAndSettle();

    // F 键进入全屏，再按 F 退出全屏
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(controller.toggleFullscreenCalls, 1);
    expect(controller.fullScreen.value, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(controller.toggleFullscreenCalls, 2);
    expect(controller.fullScreen.value, isFalse);

    // R 键刷新当前选中的窗口 #1
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(controller.refreshedSlot, 1);

    // 鼠标前侧键进入当前选中的直播间 #1
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kForwardMouseButton,
    );
    await gesture.down(const Offset(400, 300));
    await gesture.up();
    await tester.pump();
    expect(controller.openedSingleRoomSlot, 1);
  });

  testWidgets('仅在选中直播间上滚轮上下可调节音量，未选中窗口不调音', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    seedTwoRooms();
    settings.playerVolume.value = 50;
    controller.activeAudioIndex.value = 0;

    await tester.pumpWidget(const GetMaterialApp(home: MultiViewPage()));
    await tester.pumpAndSettle();

    // 在选中窗口 #0（左侧）滚轮向上 -> 音量 +5
    final leftCenter = tester.getCenter(find.text('主播A'));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(leftCenter.dx, 360),
        scrollDelta: const Offset(0, -120),
      ),
    );
    await tester.pump();
    expect(settings.playerVolume.value, 55);
    expect(find.text('音量 55%'), findsOneWidget);

    // 滚轮向下 -> 音量 -5
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(leftCenter.dx, 360),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(settings.playerVolume.value, 50);

    // 在未选中窗口 #1（右侧）滚轮 -> 音量不变
    final rightCenter = tester.getCenter(find.text('主播B'));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(rightCenter.dx, 360),
        scrollDelta: const Offset(0, -120),
      ),
    );
    await tester.pump();
    expect(settings.playerVolume.value, 50);

    // 清理音量提示定时器
    await tester.pump(const Duration(milliseconds: 1300));
  });

  testWidgets('选择直播间弹窗复用关注列表标签筛选与分区归类显示逻辑', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final u1 = FollowUser(
      id: 'huya_1',
      roomId: '1',
      siteId: 'huya',
      userName: 'LOL主播',
      face: '',
      addTime: DateTime(2026),
      categoryName: 'LOL',
    )
      ..heat = 5000
      ..liveStatus.value = 2;
    final u2 = FollowUser(
      id: 'douyu_2',
      roomId: '2',
      siteId: 'douyu',
      userName: '未播主播',
      face: '',
      addTime: DateTime(2026),
      categoryName: '',
    )..liveStatus.value = 1;

    followService.followList.assignAll([u1, u2]);
    followService.liveList.assignAll([u1]);
    followService.notLiveList.assignAll([u2]);
    followService.followTagList.assignAll([
      FollowUserTag(id: 'custom_1', tag: '常看', userId: ['huya_1']),
    ]);

    await tester.pumpWidget(const GetMaterialApp(home: MultiViewPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加直播间 #1'));
    await tester.pumpAndSettle();

    // 验证筛选标签条存在（全部 / 直播中 / 未开播 / 自定义标签）
    expect(find.widgetWithText(FilterButton, '全部'), findsOneWidget);
    expect(find.widgetWithText(FilterButton, '直播中'), findsOneWidget);
    expect(find.widgetWithText(FilterButton, '未开播'), findsOneWidget);
    expect(find.widgetWithText(FilterButton, '常看'), findsOneWidget);

    // 默认显示直播中，且按关注列表分区归类（LOL -> 英雄联盟）
    expect(find.text('英雄联盟 1人'), findsOneWidget);
    expect(find.textContaining('LOL主播', findRichText: true), findsOneWidget);
    expect(find.textContaining('未播主播', findRichText: true), findsNothing);

    // 切到“全部”后显示“其他 1人”和未播主播
    await tester.tap(find.widgetWithText(FilterButton, '全部'));
    await tester.pumpAndSettle();
    expect(find.text('其他 1人'), findsOneWidget);
    expect(find.textContaining('未播主播', findRichText: true), findsOneWidget);
  });
}
