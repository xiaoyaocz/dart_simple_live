import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';

class _Room extends LiveRoomController {
  _Room() : super(pSite: Sites.allSites['huya']!, pRoomId: '1');
  int follows = 0, removes = 0, refreshes = 0;
  @override
  void followUser() {
    follows++;
    followed.value = true;
  }

  @override
  void removeFollowUser() {
    removes++;
    followed.value = false;
  }

  @override
  void refreshRoom() {
    refreshes++;
  }

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

class _Page extends LiveRoomPage {
  const _Page();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(actions: buildAppbarActions(context)),
      body: buildPhoneUI(context));
  @override
  Widget buildMediaPlayer() => const ColoredBox(color: Colors.black);
  @override
  Widget buildUserProfile(BuildContext context) => const SizedBox(height: 48);
  @override
  Widget buildMessageArea() => const Expanded(
      child: ColoredBox(
          key: ValueKey('chat-area'),
          color: Colors.grey,
          child: Center(child: Text('聊天内容'))));
}

void main() {
  Future<_Room> mount(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(() {
      Get.reset();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });
    final room = Get.put<LiveRoomController>(_Room()) as _Room;
    await tester.pumpWidget(GetMaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const _Page()));
    await tester.pumpAndSettle();
    return room;
  }

  for (final size in [
    const Size(390, 844),
    const Size(360, 780),
    const Size(720, 1280)
  ]) {
    testWidgets('手机竖屏$size无底部操作栏，聊天扩展且避开系统导航栏', (tester) async {
      final room = await mount(tester, size);
      for (final followed in [false, true]) {
        room.followed.value = followed;
        await tester.pump();
        expect(find.text('刷新'), findsNothing);
        expect(find.text('分享'), findsNothing);
        expect(find.text('关注'), findsNothing);
        expect(find.text('取消关注'), findsNothing);
        expect(tester.getRect(find.byKey(const ValueKey('chat-area'))).bottom,
            closeTo(size.height - 24, 0.1));
        expect(find.text('聊天内容'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('右上角更多保留关注、取消关注、刷新和分享入口', (tester) async {
    final room = await mount(tester, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('关注主播'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('分享直播间'), findsOneWidget);
    await tester.tap(find.text('关注主播'));
    await tester.pumpAndSettle();
    expect(room.follows, 1);
    expect(find.text('关注主播'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('取消关注'), findsOneWidget);
    await tester.tap(find.text('取消关注'));
    await tester.pumpAndSettle();
    expect(room.removes, 1);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刷新'));
    expect(room.refreshes, 1);
    Get.back();
    await tester.pumpAndSettle();
  });
}
