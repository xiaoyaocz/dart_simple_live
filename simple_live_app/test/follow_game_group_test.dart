import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

class _Service extends FollowService {
  int loadCount = 0;
  // 测试使用内存数据，不启动定时器或请求网络。
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadData({bool updateStatus = true}) async {
    loadCount++;
  }
}

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Controller extends FollowUserController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

FollowUser user(String name, String? category, int status) {
  final item = FollowUser.fromJson({
    'id': 'huya_$name', 'roomId': name, 'siteId': 'huya',
    'userName': name, 'face': '', 'addTime': '2026-10-06T00:00:00',
    'categoryName': category,
  });
  item.liveStatus.value = status;
  return item;
}

void main() {
  late _Controller controller;
  setUp(() {
    Get.put<AppSettingsController>(_Settings())
        .siteSort.assignAll(['douyin', 'huya', 'bilibili', 'douyu']);
    final service = Get.put<FollowService>(_Service());
    final users = [user('联盟一', '英雄联盟', 2), user('契约一', '无畏契约', 2),
      user('联盟二', ' 英雄联盟 ', 1), user('未知', null, 1)];
    service.followList.assignAll(users);
    service.liveList.assignAll(users.where((item) => item.liveStatus.value == 2));
    service.notLiveList.assignAll(users.where((item) => item.liveStatus.value == 1));
    controller = _Controller();
    controller.list.assignAll(users);
    Get.put<FollowUserController>(controller);
  });
  tearDown(() => Get.reset());

  Future<void> show(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GetMaterialApp(home: FollowUserPage()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('unknown network status never makes saved follows look deleted', (tester) async {
    final service=Get.find<FollowService>();
    final saved=[user('保留一',null,0),user('保留二',null,0)];
    service.followList.assignAll(saved);service.liveList.clear();service.notLiveList.clear();
    await show(tester,const Size(1000,800));
    await tester.tap(find.widgetWithText(FilterButton,'直播中'));
    await tester.pumpAndSettle();
    expect(find.textContaining('关注记录仍在，直播状态暂未获取'),findsOneWidget);
    expect(service.followList.length,2);
    await tester.tap(find.widgetWithText(FilterButton,'全部'));
    await tester.pumpAndSettle();
    expect(find.byType(FollowUserItem),findsNWidgets(2));
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('$platform复用分类与排序，开播补分类后同步更新并保留筛选', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final high = user('虎牙高', 'LOL', 2)..heat = 100;
      final low = user('虎牙低', '英雄联盟', 2)..heat = 10;
      final douyin = FollowUser.fromJson({
        'id': 'douyin_主播', 'roomId': '主播', 'siteId': 'douyin',
        'userName': '抖音', 'face': '', 'addTime': '2026-10-06T00:00:00',
        'categoryName': '英雄联盟',
      })..heat = 1;
      douyin.liveStatus.value = 2;
      final offline = user('后期开播', null, 1);
      final unknown = user('确无分类', null, 2);
      final users = [low, high, douyin, offline, unknown];
      final service = Get.find<FollowService>();
      service.followList.assignAll(users);
      service.filterData();
      controller.filterData();
      await show(tester, platform == TargetPlatform.android
          ? const Size(400, 1200) : const Size(2200, 1200));
      List<String> names() => tester.widgetList<FollowUserItem>(
          find.byType(FollowUserItem)).map((card) => card.item.userName).toList();
      expect(find.text('英雄联盟 3人'), findsOneWidget);
      expect(find.text('其他 2人'), findsOneWidget);
      expect(names(), ['抖音', '虎牙高', '虎牙低', '确无分类', '后期开播']);

      // 模拟共享服务完成最新分类与状态更新，页面不另行识别分类。
      offline.categoryName = 'VALORANT';
      offline.liveStatus.value = 2;
      service.filterData();
      controller.filterData();
      await tester.pump();
      expect(find.text('无畏契约 1人'), findsOneWidget);
      expect(find.text('其他 1人'), findsOneWidget);
      expect(names(), ['抖音', '虎牙高', '虎牙低', '后期开播', '确无分类']);

      Get.find<AppSettingsController>().siteSort.assignAll(['huya', 'douyin']);
      high.heat = 5;
      service.filterData();
      controller.filterData();
      await tester.pump();
      expect(names(), ['虎牙低', '虎牙高', '抖音', '后期开播', '确无分类']);
      await tester.tap(find.widgetWithText(FilterButton, '未开播'));
      await tester.pumpAndSettle();
      expect(find.byType(FollowUserItem), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('手机横向滑动与点击共用淡入淡出，纵向与边界不切换、不请求', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await show(tester, const Size(400, 1000));
    final service = Get.find<FollowService>() as _Service;
    final loads = service.loadCount;
    final content = find.byType(CustomScrollView);
    await tester.drag(content, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '直播中');
    expect(find.widgetWithText(FilterButton, '直播中').evaluate().single.widget,
        isA<FilterButton>().having((button) => button.selected, 'selected', true));
    await tester.drag(content, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '直播中');
    await tester.drag(content, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '未开播');
    await tester.drag(content, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '未开播');
    await tester.drag(content, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '直播中');
    await tester.tap(find.widgetWithText(FilterButton, '全部'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final fade = tester.widget<FadeTransition>(find.ancestor(
        of: content, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, lessThan(1));
    expect(fade.opacity.value, greaterThan(0));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '全部');
    expect(find.byType(FollowUserItem), findsNWidgets(4));
    expect(service.loadCount, loads);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('手机连续点击以最后选择为准，短滑动不切换，退出取消动画', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await show(tester, const Size(400, 1000));
    await tester.drag(find.byType(CustomScrollView), const Offset(-35, 0));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '全部');
    await tester.tap(find.widgetWithText(FilterButton, '直播中'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.widgetWithText(FilterButton, '未开播'));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '未开播');
    await tester.tap(find.widgetWithText(FilterButton, '全部'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(controller.filterMode.value.tag, '未开播');
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('相同游戏合并并保持组内顺序，未知分类归其他，复用原主播卡片', (tester) async {
    await show(tester, const Size(2200, 1200));
    expect(find.text('英雄联盟 2人'), findsOneWidget);
    expect(find.text('无畏契约 1人'), findsOneWidget);
    expect(find.text('其他 1人'), findsOneWidget);
    final cards = tester.widgetList<FollowUserItem>(find.byType(FollowUserItem)).toList();
    expect(cards.map((item) => item.item.userName), ['联盟一', '联盟二', '契约一', '未知']);
    for (final item in cards) {
      expect(item.onTap, isNotNull);
      expect(item.onRemove, isNotNull);
      expect(item.onLongPress, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('先用原顶部筛选过滤，再计算分组人数，窄窗口无溢出', (tester) async {
    await show(tester, const Size(400, 1000));
    await tester.tap(find.widgetWithText(FilterButton, '直播中'));
    await tester.pumpAndSettle();
    expect(find.text('英雄联盟 1人'), findsOneWidget);
    expect(find.text('无畏契约 1人'), findsOneWidget);
    expect(find.text('其他 1人'), findsNothing);
    expect(find.byType(FollowUserItem), findsNWidgets(2));
    await tester.tap(find.widgetWithText(FilterButton, '未开播'));
    await tester.pumpAndSettle();
    expect(find.text('英雄联盟 1人'), findsOneWidget);
    expect(find.text('其他 1人'), findsOneWidget);
    expect(find.text('无畏契约 1人'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('分类只按已开播数降序，其他即使开播最多也固定最后', (tester) async {
    final users = [
      user('其他一', null, 2), user('其他二', null, 2), user('其他三', null, 2),
      user('甲直播', '游戏甲', 2),
      ...List.generate(5, (i) => user('甲离线$i', '游戏甲', 1)),
      user('乙一', '游戏乙', 2), user('乙二', '游戏乙', 2),
      user('零直播', '游戏丙', 1),
    ];
    Get.find<FollowService>().followList.assignAll(users);
    controller.list.assignAll(users);
    await show(tester, const Size(2200, 1400));
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('游戏乙 2人'), lessThan(top('游戏甲 6人')));
    expect(top('游戏甲 6人'), lessThan(top('游戏丙 1人')));
    expect(top('游戏丙 1人'), lessThan(top('其他 3人')));
    final cards = tester.widgetList<FollowUserItem>(find.byType(FollowUserItem));
    expect(cards.where((card) => card.item.categoryName == '游戏甲').map((card) => card.item.userName),
        ['甲直播', '甲离线0', '甲离线1', '甲离线2', '甲离线3', '甲离线4']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开播状态变化自动重排，同人数保留上一轮显示顺序且空刷新不清掉顺序', (tester) async {
    final a = user('甲一', '游戏甲', 2);
    final b = user('乙一', '游戏乙', 2);
    final b2 = user('乙二', '游戏乙', 2);
    final users = [a, b, b2];
    Get.find<FollowService>().followList.assignAll(users);
    controller.list.assignAll(users);
    await show(tester, const Size(2200, 1200));
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('游戏乙 2人'), lessThan(top('游戏甲 1人')));
    b2.liveStatus.value = 1;
    await tester.pump();
    expect(top('游戏乙 2人'), lessThan(top('游戏甲 1人')));
    controller.list.clear();
    await tester.pump();
    controller.list.assignAll(users);
    await tester.pump();
    expect(top('游戏乙 2人'), lessThan(top('游戏甲 1人')));
    b.liveStatus.value = 1;
    await tester.pump();
    expect(top('游戏甲 1人'), lessThan(top('游戏乙 2人')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Windows字体下分类长列表可连续滚轮到底，底部不回跳', (tester) async {
    final fontFile = File('C:/Windows/Fonts/msyh.ttc');
    final font = FontLoader('Microsoft YaHei');
    font.addFont(Future.value(ByteData.sublistView(fontFile.readAsBytesSync())));
    await font.load();
    final users = List.generate(76, (i) =>
        user('主播$i${i % 5 == 0 ? '（较长的名称与直播内容）' : ''}', '游戏${i ~/ 7}', i.isEven ? 2 : 1));
    final service = Get.find<FollowService>();
    service.followList.assignAll(users);
    controller.list.assignAll(users);
    await tester.binding.setSurfaceSize(const Size(2048, 1195));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(fontFamily: 'Microsoft YaHei'),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(2048, 1195), textScaler: TextScaler.linear(1.25)),
        child: const FollowUserPage(),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    double previous = 0;
    for (var i = 0; i < 100; i++) {
      await tester.sendEventToBinding(const PointerScrollEvent(
        position: Offset(1000, 600), scrollDelta: Offset(0, 80), kind: PointerDeviceKind.mouse));
      await tester.pump(const Duration(milliseconds: 100));
      final position = controller.scrollController.position;
      expect(position.pixels, greaterThanOrEqualTo(previous - 0.01));
      previous = position.pixels;
    }
    expect(controller.scrollController.position.extentAfter, closeTo(0, 0.01));
    final last = find.byWidgetPredicate((widget) => widget is FollowUserItem && widget.item.id == users.last.id);
    expect(last, findsOneWidget);
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(1195));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }, skip: !File('C:/Windows/Fonts/msyh.ttc').existsSync());
}
