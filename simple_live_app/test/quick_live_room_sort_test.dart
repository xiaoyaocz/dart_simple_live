import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/modules/live_room/quick_live_room_sort.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Follows extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Room extends LiveRoomController {
  _Room() : super(pSite: Sites.allSites['huya']!, pRoomId: '1');
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

FollowUser room(String id, String site, String? game, int? heat,
    {int status = 2}) {
  return FollowUser(
    id: id,
    roomId: id,
    siteId: site,
    userName: id,
    face: '',
    addTime: DateTime(2026),
    categoryName: game,
  )
    ..heat = heat
    ..liveStatus.value = status;
}

void main() {
  testWidgets('右侧列表随平台设置及现有数据刷新自动重排，复用原卡片', (tester) async {
    final settings = Get.put<AppSettingsController>(_Settings());
    settings.siteSort.assignAll(['douyin', 'huya']);
    final service = Get.put<FollowService>(_Follows());
    Get.put<LiveRoomController>(_Room());
    addTearDown(() => Get.reset());
    final items = [
      room('d1', 'douyin', '英雄联盟', 10),
      room('h1', 'huya', '无畏契约', 20),
      room('d2', 'douyin', '无畏契约', 30),
    ];
    service.liveList.assignAll(items);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: LiveRoomPage().buildFollowList()),
    ));
    await tester.pump();
    List<String> order() => tester
        .widgetList<FollowUserItem>(find.byType(FollowUserItem))
        .map((card) => card.item.id)
        .toList();
    expect(order(), ['d1', 'd2', 'h1']);
    settings.siteSort.assignAll(['huya', 'douyin']);
    await tester.pump();
    expect(order(), ['h1', 'd1', 'd2']);
    items[0].categoryName = '无畏契约';
    service.liveList.assignAll(items);
    await tester.pump();
    expect(order(), ['h1', 'd2', 'd1']);
    items[0].heat = 100;
    service.liveList.assignAll(items);
    await tester.pump();
    expect(order(), ['h1', 'd1', 'd2']);
    expect(service.liveList.toList(), items);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('设置平台顺序优先于分类人数和热度，不修改原列表', () {
    final items = [
      room('d1', 'douyin', '英雄联盟', 10000),
      room('h1', 'huya', '无畏契约', 1),
      room('d2', 'douyin', '英雄联盟', 20000),
    ];
    expect(sortQuickLiveRooms(items, ['huya', 'douyin']).map((e) => e.id),
        ['h1', 'd2', 'd1']);
    expect(items.map((e) => e.id), ['d1', 'h1', 'd2']);
    expect(sortQuickLiveRooms(items, ['douyin', 'huya']).first, items[2]);
  });

  test('同平台按分类直播人数降序，同游戏连续且热度降序，缺分类最后', () {
    final items = [
      room('other', 'douyin', null, 99999),
      room('v1', 'douyin', '无畏契约', 500),
      room('l1', 'douyin', 'LOL', 10),
      room('l2', 'douyin', '英雄联盟', 20),
      room('v2', 'douyin', '无畏契约', 600),
      room('l3', 'douyin', '英雄联盟', null),
    ];
    expect(sortQuickLiveRooms(items, ['douyin']).map((e) => e.id),
        ['l2', 'l1', 'l3', 'v2', 'v1', 'other']);
  });

  test('分类人数相同保持首次出现顺序，主播热度相同或缺失保持原顺序', () {
    final items = [
      room('v1', 'huya', '无畏契约', 20),
      room('l1', 'huya', '英雄联盟', null),
      room('v2', 'huya', '无畏契约', 20),
      room('l2', 'huya', '英雄联盟', null),
    ];
    expect(sortQuickLiveRooms(items, ['huya']).map((e) => e.id),
        ['v1', 'v2', 'l1', 'l2']);
  });

  test('已有数据变化后重新计算，仅当前直播计入分类人数', () {
    final items = [
      room('v1', 'huya', '无畏契约', 10),
      room('v2', 'huya', '无畏契约', 20, status: 1),
      room('l1', 'huya', '英雄联盟', 30),
      room('l2', 'huya', '英雄联盟', 40),
    ];
    expect(sortQuickLiveRooms(items, ['huya']).first.id, 'l2');
    items[1].liveStatus.value = 2;
    expect(sortQuickLiveRooms(items, ['huya']).first.id, 'v2');
    items[0].heat = 100;
    expect(sortQuickLiveRooms(items, ['huya']).first.id, 'v1');
    items[0].categoryName = '英雄联盟';
    expect(sortQuickLiveRooms(items, ['huya']).map((e) => e.id),
        ['v1', 'l2', 'l1', 'v2']);
  });

  test('笼统游戏分类放平台末尾，未配置平台按原出现顺序保留', () {
    final items = [
      room('x', 'new', 'CS2', 1),
      room('broad', 'huya', '射击游戏', 100),
      room('game', 'huya', 'CS2', 10),
      room('y', 'another', 'CS2', 2),
    ];
    expect(sortQuickLiveRooms(items, ['huya']).map((e) => e.id),
        ['game', 'broad', 'x', 'y']);
    expect(sortQuickLiveRooms([], ['huya']), isEmpty);
  });
}
