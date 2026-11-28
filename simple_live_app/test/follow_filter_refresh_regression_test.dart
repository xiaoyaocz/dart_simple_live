import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

// Replace only startup network/timers; keep real list publishing and filtering.
class _Service extends FollowService {
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

class _Storage extends LocalStorageService {
  @override
  T getValue<T>(dynamic key, T defaultValue) =>
      key == LocalStorageService.kFollowDefaultFilter ? '1' as T : defaultValue;
}

class _DelayedController extends FollowUserController {
  final gate = Completer<void>();
  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    await gate.future;
    return super.getData(page, pageSize);
  }
}

// Pause after taking the real service snapshot to control the async race.
class _SnapshotController extends FollowUserController {
  final captured = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    final snapshot = await super.getData(page, pageSize);
    if (!captured.isCompleted) captured.complete();
    await release.future;
    return snapshot;
  }
}

FollowUser _user(String name, int status) => FollowUser(
      id: 'huya_$name',
      roomId: name,
      siteId: 'huya',
      userName: name,
      face: '',
      addTime: DateTime(2026),
      categoryName: '我的世界',
    )..liveStatus.value = status;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FollowService service;
  setUp(() {
    Get.put<LocalStorageService>(_Storage());
    Get.put<AppSettingsController>(_Settings());
    service = Get.put<FollowService>(_Service());
  });
  tearDown(() async {
    Get.reset();
    debugDefaultTargetPlatformOverride = null;
  });

  test('默认直播中首次为空，状态发布后不会清空共享直播列表', () async {
    final controller = Get.put(FollowUserController());
    await controller.loadData();
    expect(controller.pageEmpty.value, isTrue);
    service.followList.assignAll([_user('开播主播', 2), _user('离线主播', 1)]);
    service.filterData();
    await Future<void>.delayed(Duration.zero);
    expect(service.liveList.map((item) => item.userName), ['开播主播']);
    expect(controller.list.map((item) => item.userName), ['开播主播']);
    controller.setFilterMode(controller.tagList[0]);
    controller.setFilterMode(controller.tagList[1]);
    expect(controller.list.map((item) => item.userName), ['开播主播']);
    expect(service.followList.length, 2);
  });

  for (final index in [0, 1, 2]) {
    test('筛选$index的加载结果不共享可变列表，页面清空不影响服务', () async {
      service.followList.assignAll([_user('开播主播', 2), _user('离线主播', 1)]);
      service.filterData();
      final controller = Get.put(FollowUserController());
      controller.setFilterMode(controller.tagList[index]);
      final result = await controller.getData(1, 24);
      result.clear();
      expect(service.followList.length, 2);
      expect(service.liveList.length, 1);
      expect(service.notLiveList.length, 1);
    });
  }

  test('空提示随筛选结果同步，恢复非空时不残留空状态或旧错误', () async {
    final controller = Get.put(FollowUserController());
    await controller.loadData();
    expect(controller.pageEmpty.value, isTrue);
    controller.pageError.value = true;
    service.followList.assignAll([_user('开播主播', 2)]);
    service.filterData();
    await Future<void>.delayed(Duration.zero);
    controller.setFilterMode(controller.tagList[0]);
    expect(controller.pageEmpty.value, isFalse);
    expect(controller.pageError.value, isFalse);
    controller.setFilterMode(controller.tagList[2]);
    expect(controller.pageEmpty.value, isTrue);
    controller.setFilterMode(controller.tagList[1]);
    expect(controller.pageEmpty.value, isFalse);
  });

  test('refreshData等待页面加载结束后才完成', () async {
    final controller = Get.put<FollowUserController>(_DelayedController())
        as _DelayedController;
    var completed = false;
    final refresh = controller.refreshData().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    controller.gate.complete();
    await refresh;
    expect(completed, isTrue);
  });

  test('销毁关注页控制器后取消状态订阅，旧页面不再响应更新', () async {
    final controller = Get.put(FollowUserController());
    await Get.delete<FollowUserController>();
    service.followList.assignAll([_user('开播主播', 2)]);
    service.filterData();
    await Future<void>.delayed(Duration.zero);
    expect(controller.list, isEmpty);
  });

  test('缓存列表存在时重复加载是替换，不追加重复主播', () async {
    service.followList.assignAll([_user('主播甲', 2), _user('主播乙', 2)]);
    service.filterData();
    final controller = Get.put(FollowUserController());
    for (var i = 0; i < 5; i++) {
      await controller.loadData();
      expect(controller.list.map((item) => item.userName), ['主播甲', '主播乙']);
      expect(controller.canLoadMore.value, isFalse);
    }
  });

  test('加载暂停期间状态事件先填入列表，完成后仍每个主播一条', () async {
    service.followList.assignAll([_user('主播甲', 2), _user('主播乙', 2)]);
    service.filterData();
    final controller = Get.put<FollowUserController>(_SnapshotController())
        as _SnapshotController;
    final load = controller.loadData();
    await controller.captured.future;
    service.filterData();
    await Future<void>.delayed(Duration.zero);
    controller.release.complete();
    await load;
    expect(controller.list.map((item) => item.userName), ['主播甲', '主播乙']);
    expect(service.liveList.length, 2);
  });

  test('旧加载返回前切到未开播，不能把直播快照混入新筛选', () async {
    service.followList.assignAll([_user('直播主播', 2), _user('离线主播', 1)]);
    service.filterData();
    final controller = Get.put<FollowUserController>(_SnapshotController())
        as _SnapshotController;
    final load = controller.loadData();
    await controller.captured.future;
    controller.setFilterMode(controller.tagList[2]);
    controller.release.complete();
    await load;
    expect(controller.list.map((item) => item.userName), ['离线主播']);
    expect(controller.filterMode.value.tag, '未开播');
  });

  test('加载返回前已关播，旧快照不能把主播加回直播列表', () async {
    final user = _user('刚关播主播', 2);
    service.followList.assignAll([user]);
    service.filterData();
    final controller = Get.put<FollowUserController>(_SnapshotController())
        as _SnapshotController;
    final load = controller.loadData();
    await controller.captured.future;
    user.liveStatus.value = 1;
    service.filterData();
    await Future<void>.delayed(Duration.zero);
    controller.release.complete();
    await load;
    expect(controller.list, isEmpty);
    expect(controller.pageEmpty.value, isTrue);
  });

  test('连续状态通知和并发刷新不叠加列表，保持原FollowUser对象', () async {
    final first = _user('同名主播', 2);
    final second = _user('同名主播', 2)..id = 'douyin_同名主播';
    second.siteId = 'douyin';
    service.followList.assignAll([first, second]);
    service.filterData();
    final controller = Get.put(FollowUserController());
    await Future.wait(List.generate(10, (_) async {
      service.filterData();
      await controller.refreshData();
    }));
    await Future<void>.delayed(Duration.zero);
    expect(controller.list.length, 2);
    expect(controller.list[0], same(first));
    expect(controller.list[1], same(second));
    expect(controller.canLoadMore.value, isFalse);
  });

  testWidgets('手机窄屏缓存直播刷新后卡片数量与分类人数一致，不出现重复key', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.binding.setSurfaceSize(const Size(420, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      service.followList.assignAll([
        _user('amariyy', 2),
        _user('老贺', 2),
        _user('尾巴', 2),
      ]);
      service.filterData();
      final controller = Get.put(FollowUserController());
      await tester.pumpWidget(const GetMaterialApp(home: FollowUserPage()));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 3; i++) {
        await controller.loadData();
        service.filterData();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(FollowUserItem), findsNWidgets(3));
        expect(find.text('我的世界 3人'), findsOneWidget);
        final ids = tester
            .widgetList<FollowUserItem>(find.byType(FollowUserItem))
            .map((card) => card.item.id)
            .toList();
        expect(ids.toSet().length, 3);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('$platform默认直播中启动为空，开播后显示且不叠加空提示', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = Get.put(FollowUserController());
      await controller.loadData();
      await tester.pumpWidget(const GetMaterialApp(home: FollowUserPage()));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('这里什么都没有'), findsOneWidget);
      service.followList.assignAll([_user('开播主播', 2), _user('离线主播', 1)]);
      service.filterData();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FollowUserItem), findsOneWidget);
      expect(find.text('这里什么都没有'), findsNothing);
      for (final label in ['全部', '未开播', '直播中']) {
        await tester.tap(find.widgetWithText(FilterButton, label));
        await tester.pumpAndSettle();
        expect(find.text('这里什么都没有'), findsNothing);
      }
      expect(controller.list.single.userName, '开播主播');
      expect(service.liveList.single.userName, '开播主播');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
