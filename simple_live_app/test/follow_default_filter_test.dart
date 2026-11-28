import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/modules/indexed/indexed_controller.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';

const _key = 'FollowDefaultFilter';

// Only suppress startup timers/network; filtering and persistence stay real.
class _FollowService extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadData({bool updateStatus = true}) async {}
}

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Navigation extends IndexedController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

// Widget tests cannot await Hive's real file I/O in Flutter's fake clock.
// Controller tests above/below still exercise real Hive storage.
class _WidgetStorage extends LocalStorageService {
  _WidgetStorage(this.values);
  final Map<dynamic, dynamic> values;

  @override
  T getValue<T>(dynamic key, T defaultValue) =>
      values.containsKey(key) ? values[key] as T : defaultValue;

  @override
  Future<void> setValue<T>(dynamic key, T value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LocalStorageService storage;
  late FollowService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('follow-default-');
    Hive.init(directory.path);
    storage = LocalStorageService();
    await storage.init();
    Get.put<LocalStorageService>(storage);
    Get.put<AppSettingsController>(_Settings());
    service = Get.put<FollowService>(_FollowService());
    FollowUser user(String name, int status) {
      final user = FollowUser(
        id: 'huya_$name',
        roomId: name,
        siteId: 'huya',
        userName: name,
        face: '',
        addTime: DateTime(2026),
      );
      user.liveStatus.value = status;
      return user;
    }

    service.followList.assignAll([user('直播主播', 2), user('离线主播', 1)]);
    service.filterData();
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await directory.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final entry in {'0': '全部', '1': '直播中', '2': '未开播'}.entries) {
    test('新控制器恢复持久默认：${entry.value}，普通切换不覆盖默认', () async {
      await storage.setValue(_key, entry.key);
      final controller = Get.put(FollowUserController());
      expect(controller.filterMode.value.tag, entry.value);
      final result = await controller.getData(1, 24);
      expect(
          result.map((item) => item.userName),
          switch (entry.key) {
            '1' => ['直播主播'],
            '2' => ['离线主播'],
            _ => ['直播主播', '离线主播'],
          });
      controller
          .setFilterMode(controller.tagList[(int.parse(entry.key) + 1) % 3]);
      expect(storage.getValue<String>(_key, 'missing'), entry.key);
      await Get.delete<FollowUserController>();
      final reopened = Get.put(FollowUserController());
      expect(reopened.filterMode.value.tag, entry.value);
    });
  }

  for (final invalid in [null, 'unknown', '3', -1, true, <String>[]]) {
    test('缺失或异常默认值 $invalid 回退全部', () async {
      if (invalid != null) await storage.setValue(_key, invalid);
      final controller = Get.put(FollowUserController());
      expect(controller.filterMode.value.tag, '全部');
    });
  }

  test('设为默认真实落盘，重新打开Hive后仍恢复；自定义标签不写入', () async {
    final controller = Get.put(FollowUserController());
    await controller.setDefaultFilter(controller.tagList[2]);
    await controller
        .setDefaultFilter(FollowUserTag(id: 'custom', tag: '收藏', userId: []));
    await Get.delete<FollowUserController>();
    await Hive.close();
    await storage.init();
    final reopened = Get.put(FollowUserController());
    expect(reopened.filterMode.value.tag, '未开播');
    expect(storage.getValue<String>(_key, 'missing'), '2');
  });

  Future<FollowUserController> show(WidgetTester tester) async {
    storage = _WidgetStorage(storage.settingsBox.toMap());
    await Get.delete<LocalStorageService>(force: true);
    Get.put<LocalStorageService>(storage);
    final controller = Get.put(FollowUserController());
    controller.updateTagList();
    await tester.binding.setSurfaceSize(const Size(700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GetMaterialApp(home: FollowUserPage()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return controller;
  }

  Future<void> rightClick(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilterButton, label),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    debugDefaultTargetPlatformOverride = null;
  }

  Future<void> selectDefault(WidgetTester tester) async {
    await tester.tap(find.byType(CheckedPopupMenuItem<bool>));
    await tester.pumpAndSettle();
  }

  testWidgets('Windows右键可设置三个默认；普通点击和取消菜单不写入', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = await show(tester);
    await tester.tap(find.widgetWithText(FilterButton, '未开播'));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '未开播');
    expect(storage.getValue<String>(_key, 'missing'), 'missing');
    for (final entry in {'1': '直播中', '2': '未开播', '0': '全部'}.entries) {
      final previous = controller.filterMode.value.tag;
      await rightClick(tester, entry.value);
      expect(find.text('设为默认显示'), findsOneWidget);
      expect(controller.filterMode.value.tag, previous);
      await selectDefault(tester);
      expect(storage.getValue<String>(_key, 'missing'), entry.key);
    }
    await rightClick(tester, '全部');
    expect(find.text('当前默认显示'), findsOneWidget);
    expect(
        tester
            .widget<CheckedPopupMenuItem<bool>>(
                find.byType(CheckedPopupMenuItem<bool>))
            .checked,
        isTrue);
    await tester.tapAt(const Offset(650, 900));
    await tester.pumpAndSettle();
    await rightClick(tester, '直播中');
    await tester.tapAt(const Offset(650, 900));
    await tester.pumpAndSettle();
    expect(storage.getValue<String>(_key, 'missing'), '0');
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('手机长按同菜单，普通点击仍为临时筛选', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = await show(tester);
    await tester.longPress(find.widgetWithText(FilterButton, '直播中'));
    await tester.pumpAndSettle();
    expect(find.text('设为默认显示'), findsOneWidget);
    await selectDefault(tester);
    expect(storage.getValue<String>(_key, 'missing'), '1');
    await tester.tap(find.widgetWithText(FilterButton, '未开播'));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '未开播');
    expect(storage.getValue<String>(_key, 'missing'), '1');
    await close(tester);
  });

  testWidgets('自定义标签右键不展示默认菜单', (tester) async {
    service.followTagList
        .add(FollowUserTag(id: 'custom', tag: '收藏', userId: []));
    await show(tester);
    await rightClick(tester, '收藏');
    expect(find.text('设为默认显示'), findsNothing);
    expect(storage.getValue<String>(_key, 'missing'), 'missing');
    await close(tester);
  });

  testWidgets('从其他导航返回缓存关注页恢复默认，不覆盖持久值', (tester) async {
    await tester.runAsync(() => storage.setValue(_key, '1'));
    final navigation = Get.put<IndexedController>(_Navigation());
    // Reordered home tabs: follow is at position 0, not position 1.
    navigation.items.assignAll([
      Constant.allHomePages['follow']!,
      Constant.allHomePages['user']!,
    ]);
    final controller = await show(tester);
    await tester.tap(find.widgetWithText(FilterButton, '未开播'));
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '未开播');
    navigation.index.value = 1;
    await tester.pump();
    navigation.index.value = 0;
    await tester.pumpAndSettle();
    expect(controller.filterMode.value.tag, '直播中');
    expect(controller.list.map((item) => item.userName), ['直播主播']);
    expect(storage.getValue<String>(_key, 'missing'), '1');
    await close(tester);
  });
}
