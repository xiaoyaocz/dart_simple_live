import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _DB extends DBService {
  final added = <FollowUser>[];
  final deleted = <String>[];
  @override
  Future<void> deleteFollow(String id) async {
    deleted.add(id);
  }
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> addFollow(FollowUser follow) async {
    added.add(follow);
  }
}

class _Room extends LiveRoomController {
  _Room() : super(pSite: Sites.allSites['douyin']!, pRoomId: '123');
  int removals = 0;
  bool realRemoval = false;
  @override
  void removeFollowUser() {
    removals++;
    if (realRemoval) {
      super.removeFollowUser();
      return;
    }
    followed.value = false;
  }
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {
    resetFollowShortcut();
    scrollController.dispose();
  }
}

void main() {
  late _DB db;
  late _Room room;
  setUp(() {
    db = Get.put<DBService>(_DB()) as _DB;
    room = Get.put<LiveRoomController>(_Room()) as _Room;
    room.detail.value = LiveRoomDetail(
        roomId: '123',
        title: '直播间',
        cover: '',
        userName: '耀言',
        userAvatar: '',
        online: 237,
        status: true,
        url: '');
  });
  tearDown(Get.reset);

  Future<void> mount(WidgetTester tester, double width) =>
      tester.pumpWidget(GetMaterialApp(
          navigatorObservers: [FlutterSmartDialog.observer],
          builder: FlutterSmartDialog.init(),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: width,
                      child: Builder(
                          builder: (context) => KeyedSubtree(
                              key: const ValueKey('profile'),
                              child: const LiveRoomPage()
                                  .buildUserProfile(context))))))));
  Future<void> doubleTap(WidgetTester tester, Offset point,
      {PointerDeviceKind kind = PointerDeviceKind.mouse,
      int buttons = kPrimaryButton}) async {
    await tester.tapAt(point, kind: kind, buttons: buttons);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(point, kind: kind, buttons: buttons);
    await tester.pumpAndSettle();
  }

  testWidgets('Enter直接请求内嵌官方输入区，不创建发送弹窗', (tester) async {
    await mount(tester, 390);
    final first = room.openDanmakuComposer();
    final second = room.openDanmakuComposer();
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    await Future.wait([first, second]);
    expect(room.officialEditorFocusRequest.value, 2);
    expect(room.officialEditorVisible.value, isTrue);
    expect(db.added, isEmpty);
  });

  testWidgets('已关注菜单单击无效，双击才请求取消关注', (tester) async {
    room.followed.value = true;
    await mount(tester, 390);
    await tester.tap(find.byType(NetImage),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('已关注'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(room.removals, 0);
    expect(room.followed.value, isTrue);
    await doubleTap(tester, tester.getCenter(find.text('已关注')));
    expect(room.removals, 1);
    expect(room.followed.value, isFalse);
    expect(find.text('已关注'), findsNothing);
  });

  testWidgets('已关注菜单期间换房不误取消新房间', (tester) async {
    room.followed.value = true;
    await mount(tester, 390);
    await tester.tap(find.byType(NetImage),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    room.rxRoomId.value = '456';
    await doubleTap(tester, tester.getCenter(find.text('已关注')));
    expect(room.removals, 0);
  });

  testWidgets('双击已关注保留确认框，取消不删除，确定后删除关注', (tester) async {
    room.realRemoval = true;
    room.followed.value = true;
    await mount(tester, 390);
    Future<void> openConfirmation() async {
      await tester.tap(find.byType(NetImage),
          kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await doubleTap(tester, tester.getCenter(find.text('已关注')));
      expect(find.text('确定要取消关注该用户吗？'), findsOneWidget);
    }
    await openConfirmation();
    expect(db.deleted, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(room.followed.value, isTrue);
    expect(db.deleted, isEmpty);
    await openConfirmation();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(room.followed.value, isFalse);
    expect(db.deleted, ['douyin_123']);
  });

  testWidgets('双击Q才关注并提示，超时、其他键和长按不触发', (tester) async {
    await mount(tester, 390);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => handlePlayerShortcut(
          event,
          onToggleDanmaku: () {},
          onToggleFullscreen: () {},
          onFollowKey: room.followByDoubleQ,
          onResetFollowKey: room.resetFollowShortcut,
        ),
        child: const Scaffold(body: TextField()),
      ),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(db.added, isEmpty);
    await tester.pump(const Duration(milliseconds: 401));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(db.added, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyQ);
    expect(db.added, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();
    expect(db.added, hasLength(1));
    expect(find.text('关注成功'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(db.added, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('输入框和组合键中的Q不关注，切房不继承第一击', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => handlePlayerShortcut(
          event,
          onToggleDanmaku: () {},
          onToggleFullscreen: () {},
          onFollowKey: room.followByDoubleQ,
          onResetFollowKey: room.resetFollowShortcut,
        ),
        child: const Scaffold(body: TextField()),
      ),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(db.added, isEmpty);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(db.added, isEmpty);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    room.followByDoubleQ();
    room.rxRoomId.value = '456';
    room.followByDoubleQ();
    expect(db.added, isEmpty);
    room.resetFollowShortcut();
    room.followByDoubleQ();
    room.detail.value = null;
    room.followByDoubleQ();
    expect(db.added, isEmpty);
  });

  for (final width in [300.0, 390.0]) {
    testWidgets('右键头像只打开菜单，点击关注后写入并提示，宽度$width', (tester) async {
      await mount(tester, width);
      await tester.tap(find.byType(NetImage),
          kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(db.added, isEmpty);
      expect(find.text('关注'), findsOneWidget);
      await tester.tap(find.text('关注'));
      await tester.pumpAndSettle();
      expect(db.added, hasLength(1));
      expect(db.added.single.id, 'douyin_123');
      expect(db.added.single.userName, '耀言');
      expect(room.followed.value, isTrue);
      expect(find.text('关注成功'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('关注成功'), findsNothing);
      await tester.tap(find.byType(NetImage),
          kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('已关注'), findsOneWidget);
      await tester.tap(find.text('已关注'));
      await tester.pumpAndSettle();
      expect(db.added, hasLength(1));
      expect(room.followed.value, isTrue);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
    });
  }
  testWidgets('左键和双击信息卡不关注，右键非头像区域也不显示菜单', (tester) async {
    await mount(tester, 390);
    for (final point in [
      tester.getCenter(find.byType(NetImage)),
      tester.getCenter(find.text('耀言')),
      tester.getCenter(find.text('抖音直播')),
      tester.getCenter(find.text('237'))
    ]) {
      await doubleTap(tester, point);
      expect(db.added, isEmpty);
      expect(find.text('关注'), findsNothing);
    }
    await tester.tap(find.text('耀言'),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('关注'), findsNothing);
  });
  testWidgets('关闭菜单不关注，未加载资料不弹菜单，菜单期间换房不误关注', (tester) async {
    await mount(tester, 390);
    final avatar = find.byType(NetImage);
    await tester.tap(avatar,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('关注'), findsOneWidget);
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(db.added, isEmpty);
    await tester.tap(avatar,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    room.rxRoomId.value = '456';
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();
    expect(db.added, isEmpty);
    room.detail.value = null;
    await tester.pump();
    await tester.tap(avatar,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('关注'), findsNothing);
  });
}
