import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_refresh_scheduler.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Storage extends LocalStorageService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Service extends FollowService {
  int? fixedConcurrency;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  int getOptimalConcurrency() => fixedConcurrency ?? super.getOptimalConcurrency();
}

class _SingleFieldSite extends LiveSite {
  @override
  String id;
  @override
  String name;

  final List<String> requestedRooms = [];
  final Map<String, Future<LiveFollowStatus> Function()> handlers = {};
  int detailCalls = 0;

  _SingleFieldSite({this.id = 'huya', this.name = '虎牙直播'});

  @override
  Future<LiveFollowStatus> getFollowStatus({required String roomId}) {
    requestedRooms.add(roomId);
    final handler = handlers[roomId];
    if (handler != null) return handler();
    return Future.value(const LiveFollowStatus(isLive: false));
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    detailCalls++;
    throw StateError('直出全字段路径不应触发二阶段 getRoomDetail: $roomId');
  }
}

class _BatchBiliSite extends LiveSite {
  @override
  String id = 'bilibili';
  @override
  String name = '哔哩哔哩直播';

  final List<List<String>> batchChunks = [];
  final List<String> singleFallbackRooms = [];
  int detailCalls = 0;
  final Set<String> omitInBatch = {};

  @override
  bool get supportsFollowStatusBatch => true;

  @override
  Future<Map<String, LiveFollowStatus>> getFollowStatusBatch({
    required List<String> roomIds,
  }) async {
    batchChunks.add(List<String>.from(roomIds));
    final map = <String, LiveFollowStatus>{};
    for (final roomId in roomIds) {
      if (omitInBatch.contains(roomId)) continue;
      final n = int.parse(roomId);
      final live = n % 2 == 0;
      map[roomId] = LiveFollowStatus(
        isLive: live,
        resolvedRoomId: roomId,
        online: live ? n * 100 : null,
        categoryName: live ? '英雄联盟' : null,
        showTime: live ? '1795772000' : null,
        needsDetailFallback: false,
      );
    }
    return map;
  }

  @override
  Future<LiveFollowStatus> getFollowStatus({required String roomId}) async {
    singleFallbackRooms.add(roomId);
    return const LiveFollowStatus(
      isLive: true,
      resolvedRoomId: '45',
      online: 999,
      categoryName: '单机',
      showTime: '1795772111',
      needsDetailFallback: false,
    );
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    detailCalls++;
    throw StateError('B站批量+单房直出不应请求 getRoomDetail');
  }
}

class _RiskDouyinSite extends DouyinSite {
  final Set<String> activeRooms = {};
  final List<String> requestedOrder = [];
  int maxConcurrent = 0;
  int attempts = 0;
  Future<LiveRoomDetail> Function(String roomId, int attempt)? customHandler;

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    requestedOrder.add(roomId);
    activeRooms.add(roomId);
    if (activeRooms.length > maxConcurrent) {
      maxConcurrent = activeRooms.length;
    }
    try {
      final attempt = ++attempts;
      if (customHandler != null) {
        return await customHandler!(roomId, attempt);
      }
      throw CoreError('风控限流(444)', statusCode: 444);
    } finally {
      activeRooms.remove(roomId);
    }
  }
}

class _DirectCategoryDouyinSite extends DouyinSite {
  final List<String> categoryCalls = [];
  Completer<String?>? ambiguousCategoryGate;

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    if (roomId == 'direct') {
      return LiveRoomDetail(
        roomId: 'direct',
        title: '王者专场',
        cover: '',
        userName: '主播_direct',
        userAvatar: '',
        status: true,
        online: 1234,
        url: '',
        showTime: '1795773000',
        categoryName: '王者荣耀',
        leafCategoryName: '王者荣耀',
        categoryId: '999,1',
      );
    }
    return LiveRoomDetail(
      roomId: 'ambiguous',
      title: '游戏专场',
      cover: '',
      userName: '主播_ambiguous',
      userAvatar: '',
      status: true,
      online: 5678,
      url: '',
      showTime: '1795773100',
      categoryName: '游戏',
      leafCategoryName: '游戏',
      categoryId: '888,1',
      webParentCategoryName: '网游',
    );
  }

  @override
  Future<String?> getFollowCategoryName(LiveRoomDetail detail) async {
    categoryCalls.add(detail.roomId);
    if (ambiguousCategoryGate != null) {
      return ambiguousCategoryGate!.future;
    }
    return '三角洲行动';
  }
}

FollowUser _follow(
  String siteId,
  String roomId, {
  int status = 0,
  String tag = '全部',
  String? category,
}) =>
    FollowUser(
      id: '${siteId}_$roomId',
      roomId: roomId,
      siteId: siteId,
      userName: '主播_$roomId',
      face: '',
      addTime: DateTime(2026),
      tag: tag,
      categoryName: category,
    )..liveStatus.value = status;

Future<void> _until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('等待异步刷新完成超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Future<void> _tick() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late DBService db;
  late _Storage storage;
  late _Service service;
  late Map<String, Site> originalSites;
  late DateTime fakeNow;

  setUp(() async {
    fakeNow = DateTime(2026, 11, 28, 9, 0, 0);
    directory =
        await Directory.systemTemp.createTemp('follow-refresh-engine-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FollowUserAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(FollowUserTagAdapter());
    }
    storage = Get.put<LocalStorageService>(_Storage()) as _Storage;
    storage.settingsBox = await Hive.openBox('LocalStorage');
    db = Get.put(DBService());
    db.followBox = await Hive.openBox<FollowUser>('follow');
    db.tagBox = await Hive.openBox<FollowUserTag>('tags');
    final settings = Get.put<AppSettingsController>(_Settings());
    settings.autoUpdateFollowEnable.value = false;
    settings.updateFollowThreadCount.value = 0;

    originalSites = Map<String, Site>.from(Sites.allSites);
    service = Get.put<FollowService>(_Service()) as _Service;
    service.clock = () => fakeNow;
  });

  tearDown(() async {
    service.onClose();
    Sites.allSites
      ..clear()
      ..addAll(originalSites);
    Get.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('本地状态快照实现冷启动0ms秒开，支持2小时过期失效及取关清理', () async {
    final huya = _SingleFieldSite(id: 'huya', name: '虎牙');
    huya.handlers['1'] = () async => const LiveFollowStatus(
          isLive: true,
          resolvedRoomId: '1',
          online: 8888,
          categoryName: '英雄联盟',
          showTime: '1795772503',
          needsDetailFallback: false,
        );
    huya.handlers['2'] = () async => const LiveFollowStatus(isLive: false);
    Sites.allSites['huya'] = Site(
      id: 'huya',
      name: '虎牙',
      logo: originalSites['huya']!.logo,
      liveSite: huya,
    );

    await db.addFollow(_follow('huya', '1'));
    await db.addFollow(_follow('huya', '2'));
    await service.loadData();
    await _until(() => !service.updating.value);
    expect(service.liveList.single.roomId, '1');
    expect(service.liveList.single.heat, 8888);
    expect(service.liveList.single.liveStartTime, '1795772503');
    expect(
      storage.getValue<dynamic>(LocalStorageService.kFollowStatusSnapshot, null),
      isA<String>(),
    );

    // 模拟冷启动：重新打开 followBox，状态全为 0，仅走 loadData(updateStatus: false)
    await db.followBox.close();
    db.followBox = await Hive.openBox<FollowUser>('follow');
    huya.requestedRooms.clear();

    service.onClose();
    await Get.delete<FollowService>(force: true);
    final coldStart = Get.put<FollowService>(_Service()) as _Service;
    coldStart.clock = () => fakeNow.add(const Duration(minutes: 30));
    await coldStart.loadData(updateStatus: false);

    expect(huya.requestedRooms, isEmpty);
    expect(coldStart.liveList.map((e) => e.roomId), ['1']);
    expect(coldStart.liveList.single.heat, 8888);
    expect(coldStart.liveList.single.liveStartTime, '1795772503');
    expect(coldStart.notLiveList.map((e) => e.roomId), ['2']);

    // 超过 2 小时 TTL 后快照自动失效
    await db.followBox.close();
    db.followBox = await Hive.openBox<FollowUser>('follow');
    coldStart.onClose();
    await Get.delete<FollowService>(force: true);
    final expiredStart = Get.put<FollowService>(_Service()) as _Service;
    expiredStart.clock =
        () => fakeNow.add(const Duration(hours: 2, minutes: 1));
    await expiredStart.loadData(updateStatus: false);
    expect(expiredStart.liveList, isEmpty);
    expect(expiredStart.notLiveList, isEmpty);

    // 取关后下次刷新自动清理已删除条目
    await db.deleteFollow('huya_2');
    service = expiredStart;
    await expiredStart.loadData();
    await _until(() => !expiredStart.updating.value);
    final raw = storage.getValue<String>(
      LocalStorageService.kFollowStatusSnapshot,
      '',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = decoded['items'] as Map<String, dynamic>;
    expect(items.containsKey('huya_1'), isTrue);
    expect(items.containsKey('huya_2'), isFalse);
  });

  test('B站40房间分片批量查询+缺漏房间单房兜底，全程零详情请求', () async {
    final bili = _BatchBiliSite()..omitInBatch.add('45');
    Sites.allSites['bilibili'] = Site(
      id: 'bilibili',
      name: '哔哩哔哩',
      logo: originalSites['bilibili']!.logo,
      liveSite: bili,
    );

    for (var i = 1; i <= 45; i++) {
      await db.addFollow(_follow('bilibili', '$i'));
    }

    await service.loadData();
    await _until(() => !service.updating.value);

    expect(bili.batchChunks.length, 2);
    expect(bili.batchChunks[0].length, 40);
    expect(bili.batchChunks[1].length, 5);
    expect(bili.singleFallbackRooms, ['45']);
    expect(bili.detailCalls, 0);
    expect(service.updatedCount, 45);
    // 偶数 2..44 共 22 人开播 + 兜底开播的 45 = 23 人开播
    expect(service.liveList.length, 23);
    expect(service.notLiveList.length, 22);
    final room45 =
        service.liveList.firstWhere((element) => element.roomId == '45');
    expect(room45.heat, 999);
    expect(room45.categoryName, '单机');
    expect(room45.liveStartTime, '1795772111');
  });

  test('虎牙与斗鱼单次状态直出全字段并合并虎牙别名，零getRoomDetail请求', () async {
    final huya = _SingleFieldSite(id: 'huya', name: '虎牙');
    huya.handlers['dank1ng'] = () async => const LiveFollowStatus(
          isLive: true,
          resolvedRoomId: '12345',
          online: 6666,
          categoryName: 'CS2',
          showTime: '1795772503',
          needsDetailFallback: false,
        );
    huya.handlers['12345'] = () async => const LiveFollowStatus(isLive: false);
    final douyu = _SingleFieldSite(id: 'douyu', name: '斗鱼');
    douyu.handlers['999'] = () async => const LiveFollowStatus(
          isLive: true,
          resolvedRoomId: '999',
          online: 5555,
          categoryName: '和平精英',
          showTime: '1795772600',
          needsDetailFallback: false,
        );

    Sites.allSites['huya'] = Site(
      id: 'huya',
      name: '虎牙',
      logo: originalSites['huya']!.logo,
      liveSite: huya,
    );
    Sites.allSites['douyu'] = Site(
      id: 'douyu',
      name: '斗鱼',
      logo: originalSites['douyu']!.logo,
      liveSite: douyu,
    );

    final alias = _follow('huya', 'dank1ng');
    final canonical = _follow('huya', '12345');
    final douyuUser = _follow('douyu', '999');
    await db.addFollow(alias);
    await db.addFollow(canonical);
    await db.addFollow(douyuUser);
    final tag = await db.addFollowTag('爱看');
    await db.updateFollowTag(tag.copyWith(userId: [alias.id, canonical.id]));

    await service.loadData();
    await _until(() => !service.updating.value && service.followList.length == 2);

    expect(huya.detailCalls, 0);
    expect(douyu.detailCalls, 0);
    expect(db.followBox.get(alias.id), isNull);
    final merged = service.followList.firstWhere((e) => e.id == canonical.id);
    expect(merged.liveStatus.value, 2);
    expect(merged.heat, 6666);
    expect(merged.categoryName, 'CS2');
    expect(merged.liveStartTime, '1795772503');
    expect(db.getFollowTag('爱看')!.userId, [canonical.id]);

    final dy = service.followList.firstWhere((e) => e.id == douyuUser.id);
    expect(dy.liveStatus.value, 2);
    expect(dy.heat, 5555);
    expect(dy.categoryName, '和平精英');
    expect(dy.liveStartTime, '1795772600');
  });

  test('followSiteConcurrency 按桌面端与移动端提供高并发快路径', () {
    expect(
      followSiteConcurrency(siteId: 'douyin', globalCap: 24, isMobile: false),
      14,
    );
    expect(
      followSiteConcurrency(siteId: 'douyin', globalCap: 24, isMobile: true),
      8,
    );
    expect(
      followSiteConcurrency(siteId: 'douyin', globalCap: 4, isMobile: true),
      4,
    );
    expect(
      followSiteConcurrency(siteId: 'huya', globalCap: 24, isMobile: false),
      20,
    );
    expect(
      followSiteConcurrency(siteId: 'douyu', globalCap: 24, isMobile: true),
      16,
    );
    expect(
      followSiteConcurrency(siteId: 'bilibili', globalCap: 24, isMobile: false),
      14,
    );
    expect(
      followSiteConcurrency(siteId: 'bilibili', globalCap: 24, isMobile: true),
      10,
    );
  });

  test('DouyinRateLimitGuard 正常零等待高并发，触发444后自适应收紧至<=2并发并支持3次熔断',
      () async {
    var now = DateTime(2026, 11, 28, 9, 0, 0);
    final guard = DouyinRateLimitGuard(
      throttledPacingDelay: const Duration(milliseconds: 5),
      throttledConcurrency: 2,
      backoffSteps: const [Duration(milliseconds: 10), Duration(milliseconds: 20)],
      circuitBreakerThreshold: 3,
      clock: () => now,
    );
    addTearDown(guard.dispose);

    expect(guard.isThrottled, isFalse);
    expect(guard.isCircuitOpen, isFalse);
    for (var worker = 0; worker < 6; worker++) {
      expect(
        await guard.acquireSlot(isCancelled: () => false, workerIndex: worker),
        isTrue,
      );
    }

    // 首次风控 444：立即开启降速模式，workerIndex >= 2 的多余并发自动退出。
    expect(guard.recordError(CoreError('风控(444)', statusCode: 444)), isFalse);
    expect(guard.isThrottled, isTrue);
    expect(guard.consecutiveRiskErrors, 1);
    for (var worker = 2; worker < 6; worker++) {
      expect(
        await guard.acquireSlot(isCancelled: () => false, workerIndex: worker),
        isFalse,
      );
    }
    now = now.add(const Duration(milliseconds: 20));
    expect(
      await guard.acquireSlot(isCancelled: () => false, workerIndex: 0),
      isTrue,
    );
    expect(
      await guard.acquireSlot(isCancelled: () => false, workerIndex: 1),
      isTrue,
    );

    // 再连续命中 2 次 444 触发单轮熔断，保留的 2 个 worker 也立即停止。
    expect(guard.recordError(CoreError('风控(444)', statusCode: 444)), isFalse);
    expect(guard.recordError(CoreError('风控(444)', statusCode: 444)), isTrue);
    expect(guard.isCircuitOpen, isTrue);
    expect(
      await guard.acquireSlot(isCancelled: () => false, workerIndex: 0),
      isFalse,
    );
  });

  test('抖音健康状态零等待并发>2，命中444后收紧并发与熔断且不阻塞虎牙并发完成', () async {
    service
      ..fixedConcurrency = 8
      ..douyinPacingDelay = Duration.zero
      ..douyinThrottledPacingDelay = const Duration(milliseconds: 5)
      ..douyinThrottledConcurrency = 2
      ..douyinBackoffSteps = const [
        Duration(milliseconds: 5),
        Duration(milliseconds: 10),
      ]
      ..douyinCircuitBreakerThreshold = 3;

    // 1. 健康状态：6 个以上并发直接起飞，耗时无需等待 80ms 节流
    final healthyGate = Completer<void>();
    final healthyDouyin = _RiskDouyinSite();
    healthyDouyin.customHandler = (roomId, attempt) async {
      if (healthyDouyin.activeRooms.length >= 6 && !healthyGate.isCompleted) {
        healthyGate.complete();
      } else if (!healthyGate.isCompleted) {
        await healthyGate.future;
      }
      return LiveRoomDetail(
        roomId: roomId,
        title: 't',
        cover: '',
        userName: roomId,
        userAvatar: '',
        online: 0,
        url: '',
        status: false,
      );
    };
    for (var i = 1; i <= 8; i++) {
      await db.addFollow(_follow('douyin', 'ok$i'));
    }
    Sites.allSites['douyin'] = Site(
      id: 'douyin',
      name: '抖音',
      logo: originalSites['douyin']!.logo,
      liveSite: healthyDouyin,
    );
    await service.loadData();
    await _until(() => !service.updating.value);
    expect(healthyDouyin.maxConcurrent, greaterThanOrEqualTo(6));

    // 2. 风控自适应降速 + 单轮熔断，且不阻塞虎牙池
    await db.followBox.clear();
    service.fixedConcurrency = 6;
    final huyaGate = Completer<void>();
    final wave1ThrottleGate = Completer<void>();
    final wave2Barrier = Completer<void>();
    var wave2Active = 0;
    var wave2MaxConcurrent = 0;
    final douyin = _RiskDouyinSite();
    douyin.customHandler = (roomId, attempt) async {
      // d1 挂起等待虎牙先完成，验证跨平台互不阻塞
      if (roomId == 'd1') {
        await huyaGate.future;
        return LiveRoomDetail(
          roomId: roomId,
          title: 't',
          cover: '',
          userName: roomId,
          userAvatar: '',
          online: 0,
          url: '',
          status: false,
        );
      }
      // d2 率先抛 444 触发降级；d3..d6 等待降级完成后返回正常，重置连错计数
      if (roomId == 'd2') {
        throw CoreError('风控限流(444)', statusCode: 444);
      }
      if (const {'d3', 'd4', 'd5', 'd6'}.contains(roomId)) {
        await wave1ThrottleGate.future;
        return LiveRoomDetail(
          roomId: roomId,
          title: 't',
          cover: '',
          userName: roomId,
          userAvatar: '',
          online: 0,
          url: '',
          status: false,
        );
      }
      // 第二波 (d7..d11)：仅统计降级后进入的并发数，并连续触发 3 次 444 熔断
      wave2Active++;
      if (wave2Active > wave2MaxConcurrent) {
        wave2MaxConcurrent = wave2Active;
      }
      try {
        await wave2Barrier.future;
        throw CoreError('风控限流(444)', statusCode: 444);
      } finally {
        wave2Active--;
      }
    };

    final huya = _SingleFieldSite(id: 'huya', name: '虎牙');
    for (var i = 1; i <= 4; i++) {
      huya.handlers['h$i'] = () async => LiveFollowStatus(
            isLive: true,
            resolvedRoomId: 'h$i',
            online: 1000 + i,
            categoryName: '英雄联盟',
            needsDetailFallback: false,
          );
      await db.addFollow(_follow('huya', 'h$i'));
    }
    for (var i = 1; i <= 6; i++) {
      await db.addFollow(_follow('douyin', 'd$i', status: 0, tag: '本页'));
    }
    for (var i = 7; i <= 11; i++) {
      await db.addFollow(_follow('douyin', 'd$i', status: 2));
    }
    service.setActiveFilter(
      FollowUserTag(
        id: 'custom_page',
        tag: '本页',
        userId: [for (var i = 1; i <= 6; i++) 'douyin_d$i'],
      ),
    );
    addTearDown(() => service.setActiveFilter(null));

    Sites.allSites['douyin'] = Site(
      id: 'douyin',
      name: '抖音',
      logo: originalSites['douyin']!.logo,
      liveSite: douyin,
    );
    Sites.allSites['huya'] = Site(
      id: 'huya',
      name: '虎牙',
      logo: originalSites['huya']!.logo,
      liveSite: huya,
    );

    await service.loadData();
    // 即使抖音首个请求挂起，虎牙池仍独立全速完成全部 4 个房间
    await _until(
      () => service.liveList.where((e) => e.siteId == 'huya').length == 4,
    );
    expect(service.updating.value, isTrue);

    huyaGate.complete();
    await _tick();
    wave1ThrottleGate.complete();
    // 等待第一波 d1..d6 结束、第二波降级窗口就绪
    await Future<void>.delayed(const Duration(milliseconds: 40));
    wave2Barrier.complete();
    await _until(() => !service.updating.value);

    // 触发风控后的第二波并发应已收敛至 <= 2
    expect(wave2MaxConcurrent, lessThanOrEqualTo(2));
    // 第二波连续 3 次 444 触发单轮熔断，跳过剩余房间（不会跑满 11 个）
    expect(douyin.attempts, lessThan(11));
    // 被熔断跳过的原本直播中抖音主播维持原开播状态，不误标离线
    final keptLiveDouyin =
        service.followList.firstWhere((e) => e.roomId == 'd11');
    expect(keptLiveDouyin.liveStatus.value, 2);
  });

  test('抖音在线房间具备明确分类时首轮直出全字段且不调用 getFollowCategoryName', () async {
    final categoryGate = Completer<String?>();
    final douyin = _DirectCategoryDouyinSite()
      ..ambiguousCategoryGate = categoryGate;
    Sites.allSites['douyin'] = Site(
      id: 'douyin',
      name: '抖音',
      logo: originalSites['douyin']!.logo,
      liveSite: douyin,
    );

    await db.addFollow(_follow('douyin', 'direct'));
    await db.addFollow(_follow('douyin', 'ambiguous'));

    await service.loadData();
    // 阶段一状态刷新完成后，direct 应已直接具备完整分类、热度和开播时间，无需等待 ambiguous 查分类目录
    await _until(() => !service.updating.value);

    final direct = service.liveList.firstWhere((e) => e.roomId == 'direct');
    expect(direct.liveStatus.value, 2);
    expect(direct.categoryName, '王者荣耀');
    expect(direct.heat, 1234);
    expect(direct.liveStartTime, '1795773000');
    expect(douyin.categoryCalls, ['ambiguous']);

    categoryGate.complete('三角洲行动');
    await _until(
      () =>
          service.followList
              .firstWhere((e) => e.roomId == 'ambiguous')
              .categoryName ==
          '三角洲行动',
    );
    expect(douyin.categoryCalls, ['ambiguous']);
  });

  test('优先调度当前激活筛选标签与直播中主播', () async {
    service.fixedConcurrency = 1;
    final huya = _SingleFieldSite(id: 'huya', name: '虎牙');
    Sites.allSites['huya'] = Site(
      id: 'huya',
      name: '虎牙',
      logo: originalSites['huya']!.logo,
      liveSite: huya,
    );

    final offOther = _follow('huya', 'off_other', status: 1);
    final liveOther = _follow('huya', 'live_other', status: 2);
    final offTag = _follow('huya', 'off_tag', status: 1, tag: '常看');
    final liveTag = _follow('huya', 'live_tag', status: 2, tag: '常看');
    await db.addFollow(offOther);
    await db.addFollow(liveOther);
    await db.addFollow(offTag);
    await db.addFollow(liveTag);
    final tag = await db.addFollowTag('常看');
    final updatedTag = tag.copyWith(userId: [offTag.id, liveTag.id]);
    await db.updateFollowTag(updatedTag);

    await service.loadData(updateStatus: false);
    final controller = Get.put(FollowUserController());
    controller.setFilterMode(updatedTag);

    await service.loadData();
    await _until(() => !service.updating.value);

    expect(
      huya.requestedRooms,
      ['live_tag', 'off_tag', 'live_other', 'off_other'],
    );
  });

  test('150ms合并渲染：首帧立出，突发多条响应合并成少数批次广播', () async {
    service
      ..fixedConcurrency = 10
      ..filterFlushInterval = const Duration(milliseconds: 150);

    final completers = <String, Completer<LiveFollowStatus>>{};
    final huya = _SingleFieldSite(id: 'huya', name: '虎牙');
    for (var i = 1; i <= 10; i++) {
      final id = '$i';
      final completer = Completer<LiveFollowStatus>();
      completers[id] = completer;
      huya.handlers[id] = () => completer.future;
      await db.addFollow(_follow('huya', id));
    }
    Sites.allSites['huya'] = Site(
      id: 'huya',
      name: '虎牙',
      logo: originalSites['huya']!.logo,
      liveSite: huya,
    );

    await service.loadData();
    final events = <dynamic>[];
    final sub = service.updatedListStream.listen(events.add);

    // 第 1 条状态立即走 leading edge 渲染
    completers['1']!.complete(const LiveFollowStatus(
      isLive: true,
      resolvedRoomId: '1',
      online: 100,
      needsDetailFallback: false,
    ));
    await _tick();
    expect(events.length, 1);
    expect(service.liveList.map((e) => e.roomId), ['1']);

    // 在 150ms 窗口内突发完成第 2..9 条（第 10 条暂挂住使批次不立即收尾）
    for (var i = 2; i <= 9; i++) {
      completers['$i']!.complete(LiveFollowStatus(
        isLive: true,
        resolvedRoomId: '$i',
        online: i * 100,
        needsDetailFallback: false,
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(events.length, 1);

    // 跨越 150ms 后 trailing 合并统一刷出第 2..9 条
    await _until(() => events.length >= 2);
    expect(events.length, 2);
    expect(service.liveList.length, 9);

    completers['10']!.complete(const LiveFollowStatus(
      isLive: true,
      resolvedRoomId: '10',
      online: 1000,
      needsDetailFallback: false,
    ));
    await _until(() => !service.updating.value && service.liveList.length == 10);
    await sub.cancel();
  });

  test('刷新整轮后批量静默落盘分类更新且不复活已合并的旧房间键', () async {
    final originalHuya = Sites.allSites['huya']!;
    addTearDown(() => Sites.allSites['huya'] = originalHuya);
    Sites.allSites['huya'] = Site(
      id: 'huya',
      logo: originalHuya.logo,
      name: originalHuya.name,
      liveSite: _BatchPersistHuyaSite({
        'cat_a': const LiveFollowStatus(
          isLive: true,
          resolvedRoomId: 'cat_a',
          online: 500,
          categoryName: '英雄联盟',
          needsDetailFallback: false,
        ),
        'cat_b': const LiveFollowStatus(
          isLive: true,
          resolvedRoomId: 'cat_b',
          online: 800,
          categoryName: '无畏契约',
          needsDetailFallback: false,
        ),
        'alias': const LiveFollowStatus(
          isLive: true,
          resolvedRoomId: '99999',
          online: 1200,
          categoryName: '主机游戏',
          needsDetailFallback: false,
        ),
      }),
    );

    final db = DBService.instance;
    await db.followBox.put('huya_cat_a', FollowUser(
      id: 'huya_cat_a',
      roomId: 'cat_a',
      siteId: 'huya',
      userName: '主播A',
      face: '',
      addTime: DateTime(2026, 1, 1),
    ));
    await db.followBox.put('huya_cat_b', FollowUser(
      id: 'huya_cat_b',
      roomId: 'cat_b',
      siteId: 'huya',
      userName: '主播B',
      face: '',
      addTime: DateTime(2026, 1, 2),
      categoryName: '旧分类',
    ));
    await db.followBox.put('huya_alias', FollowUser(
      id: 'huya_alias',
      roomId: 'alias',
      siteId: 'huya',
      userName: '主播C',
      face: '',
      addTime: DateTime(2026, 1, 3),
    ));

    final service = FollowService.instance;
    await service.loadData();
    await _until(() => !service.updating.value);

    expect(
      service.followList.firstWhere((e) => e.id == 'huya_cat_a').categoryName,
      '英雄联盟',
    );
    expect(
      service.followList.firstWhere((e) => e.id == 'huya_cat_b').categoryName,
      '无畏契约',
    );
    expect(
      service.followList
          .firstWhere((e) => e.id == 'huya_99999')
          .categoryName,
      '主机游戏',
    );
    expect(service.followList.any((e) => e.id == 'huya_alias'), isFalse);

    final boxName = db.followBox.name;
    await db.followBox.close();
    db.followBox = await Hive.openBox<FollowUser>(boxName);

    expect(db.followBox.get('huya_cat_a')?.categoryName, '英雄联盟');
    expect(db.followBox.get('huya_cat_b')?.categoryName, '无畏契约');
    expect(db.followBox.get('huya_99999')?.categoryName, '主机游戏');
    expect(db.followBox.containsKey('huya_alias'), isFalse);
  });
}

class _BatchPersistHuyaSite extends LiveSite {
  _BatchPersistHuyaSite(this._statuses);

  final Map<String, LiveFollowStatus> _statuses;

  @override
  String get id => 'huya';

  @override
  String get name => '虎牙直播';

  @override
  Future<LiveFollowStatus> getFollowStatus({required String roomId}) async {
    return _statuses[roomId] ??
        LiveFollowStatus(
          isLive: false,
          resolvedRoomId: roomId,
          needsDetailFallback: false,
        );
  }
}
