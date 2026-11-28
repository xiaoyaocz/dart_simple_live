import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_refresh_scheduler.dart';
import 'package:simple_live_app/services/live_notification_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/room_startup_cache.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core_http;

class FollowService extends GetxService with WidgetsBindingObserver {
  StreamSubscription<dynamic>? subscription;
  static FollowService get instance => Get.find<FollowService>();

  final StreamController _updatedListController = StreamController.broadcast();
  Stream get updatedListStream => _updatedListController.stream;

  /// 关注用户列表
  RxList<FollowUser> followList = RxList<FollowUser>();

  /// 直播中的用户列表
  RxList<FollowUser> liveList = RxList<FollowUser>();

  /// 未直播的用户列表
  RxList<FollowUser> notLiveList = RxList<FollowUser>();

  /// 用户自定义的tag
  RxList<FollowUserTag> followTagList = RxList<FollowUserTag>();

  /// 当前tag的用户列表
  RxList<FollowUser> curTagFollowList = RxList<FollowUser>();

  /// 已经更新状态的数量
  var updatedCount = 0;

  /// 是否正在更新
  var updating = false.obs;

  Timer? updateTimer;
  Timer? _foregroundDebounceTimer;
  Timer? _filterFlushTimer;
  DateTime? _lastRefreshCompletedAt;
  DateTime? _lastFilterFlushAt;
  bool _filterFlushPending = false;

  /// UI 合并渲染节流窗口（leading 立即首帧 + trailing 50ms 合并重排）。
  Duration filterFlushInterval = const Duration(milliseconds: 50);

  /// 前台切回防抖窗口，吸收系统焦点抖动。
  Duration foregroundRefreshDebounce = const Duration(milliseconds: 300);

  /// 前台切回 SWR 冷却窗口（手动下拉刷新不受此限制）。
  Duration foregroundRefreshCooldown = const Duration(seconds: 45);

  /// 抖音健康状态发包间隔与风控降级后的保守限流参数。
  Duration douyinPacingDelay = Duration.zero;
  Duration douyinThrottledPacingDelay = const Duration(milliseconds: 80);
  int douyinThrottledConcurrency = 2;
  List<Duration> douyinBackoffSteps = const [
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
    Duration(milliseconds: 1500),
  ];
  int douyinCircuitBreakerThreshold = 3;

  /// 可注入时钟，便于测试控制防抖、冷却与节流窗口。
  DateTime Function() clock = DateTime.now;

  bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

  // A reload invalidates every outstanding response, including reloads without I/O.
  int _refreshRevision = 0;
  bool _closed = false;
  bool _wasAway = false;
  bool _foregroundRefreshPending = false;
  FollowUserTag? _selectedTag;
  FollowUserTag? _activeFilter;
  final Map<FollowUser, Object> _statusRequests = Map.identity();

  void setActiveFilter(FollowUserTag? tag) {
    _activeFilter = tag;
  }

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      loadData(updateStatus: updating.value || p0 == 0);
    });
    initTimer();
    super.onInit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _wasAway = true;
      _foregroundDebounceTimer?.cancel();
      _foregroundDebounceTimer = null;
      return;
    }
    if (!_wasAway) return;
    _wasAway = false;
    // 桌面窗口重新获得焦点、手机从后台返回共用同一入口。
    // 防抖合并连续切回，并在 45s 冷却期内跳过冗余状态请求；进行中的刷新不打断。
    if (_closed || updating.value || _foregroundRefreshPending) return;
    _foregroundDebounceTimer?.cancel();
    _foregroundDebounceTimer = Timer(foregroundRefreshDebounce, () {
      _foregroundDebounceTimer = null;
      if (_closed || updating.value || _foregroundRefreshPending) return;
      final lastCompleted = _lastRefreshCompletedAt;
      if (lastCompleted != null &&
          clock().difference(lastCompleted) < foregroundRefreshCooldown) {
        return;
      }
      unawaited(_refreshOnForeground());
    });
  }

  Future<void> _refreshOnForeground() async {
    _foregroundRefreshPending = true;
    try {
      await loadData();
    } catch (error) {
      Log.logPrint('回到前台刷新关注失败：$error');
    } finally {
      _foregroundRefreshPending = false;
    }
  }

  // 添加标签
  Future<void> addFollowUserTag(String tag) async {
    // 判断待添加tag是否已存在，存在则return
    if (followTagList.any((item) => item.tag == tag)) {
      SmartDialog.showToast("标签名重复，修改失败");
      return;
    }
    FollowUserTag item = await DBService.instance.addFollowTag(tag);
    followTagList.add(item);
  }

  // 删除标签
  Future<void> delFollowUserTag(FollowUserTag tag) async {
    followTagList.remove(tag);
    await DBService.instance.deleteFollowTag(tag.id);
  }

  // 获取用户自定义标签列表
  void getAllTagList() {
    var list = DBService.instance.getFollowTagList();
    followTagList.assignAll(list);
  }

  // 修改标签
  void updateFollowUserTag(FollowUserTag tag) {
    DBService.instance.updateFollowTag(tag);
    // 查找并修改
    var index = followTagList.indexWhere((oTag) => oTag.id == tag.id);
    followTagList[index] = tag;
  }

  // 根据标签筛选数据
  void filterDataByTag(FollowUserTag tag) {
    _selectedTag = tag;
    curTagFollowList.clear();
    // 用一个新的列表来存储需要删除的 userId
    List<String> toRemove = [];
    for (var id in tag.userId) {
      if (followList.any((x) => x.id == id)) {
        // 找到对应的 followUser 添加到 curTagFollowList
        curTagFollowList.add(followList.firstWhere((x) => x.id == id));
      } else {
        // 标记要删除的 id
        toRemove.add(id);
      }
    }
    // 双向确认用户取消关注后标签内是否还有该用户
    // 在遍历结束后统一移除不在 followList 中的 id
    tag.userId.removeWhere((id) => toRemove.contains(id));
    // 更新数据库
    if (toRemove.isNotEmpty) {
      DBService.instance.updateFollowTag(tag);
    }
    // 标签内排序
    curTagFollowList.sort(
      (a, b) => b.liveStatus.value.compareTo(a.liveStatus.value),
    );
  }

  // 添加关注
  Future<void> addFollow(FollowUser follow) async {
    await DBService.instance.addFollow(follow);
  }

  void initTimer() {
    if (AppSettingsController.instance.autoUpdateFollowEnable.value) {
      updateTimer?.cancel();
      updateTimer = Timer.periodic(
        Duration(
            minutes:
                AppSettingsController.instance.autoUpdateFollowDuration.value),
        (timer) {
          if (_closed || updating.value) return;
          Log.logPrint("Update Follow Timer");
          loadData();
        },
      );
    } else {
      updateTimer?.cancel();
    }
  }

  void _restoreStatusSnapshot() {
    if (!Get.isRegistered<LocalStorageService>()) return;
    dynamic raw;
    try {
      raw = LocalStorageService.instance
          .getValue<dynamic>(LocalStorageService.kFollowStatusSnapshot, null);
    } catch (_) {
      return;
    }
    final snapshot = decodeFollowStatusSnapshot(raw, now: clock());
    if (snapshot.isEmpty) return;
    for (final user in followList) {
      if (user.liveStatus.value != 0) continue;
      final entry = snapshot[user.id];
      if (entry == null) continue;
      user.liveStatus.value = entry.status;
      if (entry.status == 2) {
        user.liveStartTime = entry.showTime;
        user.heat = entry.heat;
      } else {
        user.liveStartTime = null;
        user.heat = null;
      }
      if ((user.categoryName == null || user.categoryName!.trim().isEmpty) &&
          entry.categoryName != null) {
        user.categoryName = entry.categoryName;
      }
    }
  }

  Future<void> _saveStatusSnapshot() async {
    if (_closed || !Get.isRegistered<LocalStorageService>()) return;
    try {
      final encoded =
          encodeFollowStatusSnapshot(followList.toList(), now: clock());
      await LocalStorageService.instance
          .setValue(LocalStorageService.kFollowStatusSnapshot, encoded);
    } catch (_) {
      // 测试替身未打开 settingsBox 时忽略快照写入。
    }
  }

  Future<void> loadData({bool updateStatus = true}) async {
    final revision = ++_refreshRevision;
    _filterFlushTimer?.cancel();
    _filterFlushTimer = null;
    _filterFlushPending = false;
    updatedCount = 0;
    updating.value = false;
    await DBService.instance.normalizeFollowTags();
    if (_closed || revision != _refreshRevision) return;
    followList.assignAll(DBService.instance.getFollowList());
    getAllTagList();
    _restoreStatusSnapshot();
    // Empty and cache-only reloads must publish the same coherent snapshot.
    filterData();
    if (followList.isEmpty) {
      await _saveStatusSnapshot();
    } else if (updateStatus) {
      startUpdateStatus();
    }
  }

  /// 获取最优并发数
  /// 根据 CPU 核心数和用户设置自动计算
  int getOptimalConcurrency() {
    var userSetting =
        AppSettingsController.instance.updateFollowThreadCount.value;

    // 如果用户设置为 0，则自动根据 CPU 核心数计算
    if (userSetting == 0) {
      var cpuCount = Platform.numberOfProcessors;
      // HTTP/2 多路复用 + 异步高并发 I/O，适当放大工作池上限到 24。
      var optimal = cpuCount * 3;
      return optimal.clamp(8, 24);
    }

    return userSetting;
  }

  /// 按平台交错排列，避免单一平台阻塞
  List<FollowUser> interleaveByPlatform(List<FollowUser> list) {
    // 按平台分组
    var grouped = <String, Queue<FollowUser>>{};
    for (var item in list) {
      grouped.putIfAbsent(item.siteId, () => Queue<FollowUser>()).add(item);
    }

    // 交错处理
    var result = <FollowUser>[];
    while (grouped.values.any((queue) => queue.isNotEmpty)) {
      for (var queue in grouped.values) {
        if (queue.isNotEmpty) {
          result.add(queue.removeFirst());
        }
      }
    }

    return result;
  }

  static const _statusTimeout = Duration(seconds: 4);
  static const _batchStatusTimeout = Duration(seconds: 6);
  static const _detailsTimeout = Duration(seconds: 4);

  /// 启动时预热各平台连接池与匿名 Cookie，跳过首轮查询握手损耗。
  Future<void> warmupNetwork() async {
    final futures = <Future<void>>[
      core_http.HttpClient.instance.warmupConnections([
        Uri.parse('https://live.douyin.com/'),
        Uri.parse('https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=0'),
        Uri.parse('https://www.douyu.com/'),
        Uri.parse('https://api.live.bilibili.com/'),
      ]),
    ];
    final douyin = Sites.allSites[Constant.kDouyin]?.liveSite;
    if (douyin is DouyinSite) futures.add(douyin.warmup());
    final bili = Sites.allSites[Constant.kBiliBili]?.liveSite;
    if (bili is BiliBiliSite) futures.add(bili.warmup());
    await Future.wait(futures);
  }

  void _triggerFilterUpdate({bool immediate = false}) {
    if (_closed) return;
    if (immediate ||
        filterFlushInterval <= Duration.zero ||
        _lastFilterFlushAt == null) {
      filterData();
      return;
    }
    final elapsed = clock().difference(_lastFilterFlushAt!);
    if (elapsed >= filterFlushInterval) {
      filterData();
      return;
    }
    _filterFlushPending = true;
    _filterFlushTimer ??= Timer(filterFlushInterval - elapsed, () {
      _filterFlushTimer = null;
      if (_closed || !_filterFlushPending) return;
      filterData();
    });
  }

  void _flushPendingFilterIfNeeded() {
    if (_closed) return;
    if (_filterFlushPending || _filterFlushTimer != null) {
      filterData();
    }
  }

  Future<void> startUpdateStatus() async {
    final revision = ++_refreshRevision;
    updatedCount = 0;
    _lastFilterFlushAt = null;
    final ordered = prioritizeFollowUsers(
      followList.toList(),
      activeFilter: _activeFilter ?? _selectedTag,
    );
    updating.value = ordered.isNotEmpty;
    if (_closed || ordered.isEmpty) return;

    final globalCap = getOptimalConcurrency().clamp(1, ordered.length);
    final isMobile = isMobilePlatform;
    final details = Queue<Future<void> Function()>();
    final dirtyFollows = <String, FollowUser>{};

    Future<void> flushDirtyFollows() async {
      if (_closed || dirtyFollows.isEmpty) return;
      final box = DBService.instance.followBox;
      if (!box.isOpen) {
        dirtyFollows.clear();
        return;
      }
      final batch = <String, FollowUser>{};
      for (final entry in dirtyFollows.entries) {
        if (box.containsKey(entry.key)) {
          batch[entry.key] = entry.value;
        }
      }
      dirtyFollows.clear();
      await DBService.instance.putFollowsSilently(batch);
    }

    final grouped = <String, List<FollowUser>>{};
    for (final item in ordered) {
      grouped.putIfAbsent(item.siteId, () => <FollowUser>[]).add(item);
    }

    final runners = <Future<void>>[];
    for (final entry in grouped.entries) {
      final siteId = entry.key;
      final items = entry.value;
      final site = Sites.allSites[siteId];
      if (site == null) continue;
      final source = site.liveSite;

      if (source.supportsFollowStatusBatch) {
        runners.add(_runBatchSiteStatusQueue(
          siteId: siteId,
          site: site,
          source: source,
          items: items,
          revision: revision,
          globalCap: globalCap,
          isMobile: isMobile,
          details: details,
          dirtyFollows: dirtyFollows,
        ));
      } else if (siteId == Constant.kDouyin) {
        runners.add(_runDouyinSiteStatusQueue(
          items: items,
          revision: revision,
          globalCap: globalCap,
          isMobile: isMobile,
          details: details,
          dirtyFollows: dirtyFollows,
        ));
      } else {
        runners.add(_runSingleSiteStatusQueue(
          siteId: siteId,
          items: items,
          revision: revision,
          globalCap: globalCap,
          isMobile: isMobile,
          details: details,
          dirtyFollows: dirtyFollows,
        ));
      }
    }

    await Future.wait(runners);
    if (!_closed && revision == _refreshRevision) {
      await flushDirtyFollows();
      _flushPendingFilterIfNeeded();
      updating.value = false;
      _lastRefreshCompletedAt = clock();
    }

    // Keep catalog, authentication and playback requests out of the status queue.
    if (details.isNotEmpty) {
      final detailConcurrency = globalCap.clamp(1, details.length);
      Future<void> detailWorker() async {
        while (details.isNotEmpty) {
          await details.removeFirst()();
          if (details.isEmpty && !_closed && revision == _refreshRevision) {
            _flushPendingFilterIfNeeded();
          }
        }
      }

      await Future.wait(
        List.generate(detailConcurrency, (_) => detailWorker()),
      );
    }

    if (!_closed && revision == _refreshRevision) {
      await flushDirtyFollows();
      _flushPendingFilterIfNeeded();
      _lastRefreshCompletedAt = clock();
      await _saveStatusSnapshot();
      if (Get.isRegistered<LiveNotificationService>()) {
        unawaited(LiveNotificationService.instance
            .handleFollowRefreshCompleted(followList.toList()));
      }
    }
  }

  Future<void> _runSingleSiteStatusQueue({
    required String siteId,
    required List<FollowUser> items,
    required int revision,
    required int globalCap,
    required bool isMobile,
    required Queue<Future<void> Function()> details,
    required Map<String, FollowUser> dirtyFollows,
  }) async {
    final queue = Queue<FollowUser>.from(items);
    final concurrency = followSiteConcurrency(
      siteId: siteId,
      globalCap: globalCap,
      isMobile: isMobile,
    );
    await runFollowQueueWorkers<FollowUser>(
      queue: queue,
      concurrency: concurrency,
      isCancelled: () => _closed || revision != _refreshRevision,
      task: (item) async {
        final task = await _readLiveStatus(
          item,
          revision,
          requireListed: true,
          dirtyFollows: dirtyFollows,
        );
        if (task != null) details.add(task);
        if (_closed || revision != _refreshRevision) return;
        updatedCount++;
      },
    );
  }

  Future<void> _runDouyinSiteStatusQueue({
    required List<FollowUser> items,
    required int revision,
    required int globalCap,
    required bool isMobile,
    required Queue<Future<void> Function()> details,
    required Map<String, FollowUser> dirtyFollows,
  }) async {
    final queue = Queue<FollowUser>.from(items);
    final concurrency = followSiteConcurrency(
      siteId: Constant.kDouyin,
      globalCap: globalCap,
      isMobile: isMobile,
    );
    final guard = DouyinRateLimitGuard(
      pacingDelay: douyinPacingDelay,
      throttledPacingDelay: douyinThrottledPacingDelay,
      throttledConcurrency: douyinThrottledConcurrency,
      backoffSteps: douyinBackoffSteps,
      circuitBreakerThreshold: douyinCircuitBreakerThreshold,
      clock: clock,
    );
    try {
      final workerCount = concurrency.clamp(1, queue.length);
      await Future.wait(List.generate(workerCount, (workerIndex) async {
        while (!_closed &&
            revision == _refreshRevision &&
            queue.isNotEmpty &&
            !guard.isCircuitOpen) {
          final allowed = await guard.acquireSlot(
            isCancelled: () => _closed || revision != _refreshRevision,
            workerIndex: workerIndex,
          );
          if (!allowed ||
              _closed ||
              revision != _refreshRevision ||
              queue.isEmpty) {
            break;
          }
          final item = queue.removeFirst();
          final task = await _readLiveStatus(
            item,
            revision,
            requireListed: true,
            dirtyFollows: dirtyFollows,
            onOutcome: (success, error) {
              if (success) {
                guard.recordSuccess();
              } else if (error != null && guard.recordError(error)) {
                Log.w('抖音关注刷新连续命中风控/限流，本轮熔断跳过剩余 ${queue.length} 个房间');
              }
            },
          );
          if (task != null) details.add(task);
          if (_closed || revision != _refreshRevision) return;
          updatedCount++;
        }
      }));
    } finally {
      guard.dispose();
    }
  }

  Future<void> _runBatchSiteStatusQueue({
    required String siteId,
    required Site site,
    required LiveSite source,
    required List<FollowUser> items,
    required int revision,
    required int globalCap,
    required bool isMobile,
    required Queue<Future<void> Function()> details,
    required Map<String, FollowUser> dirtyFollows,
  }) async {
    const chunkSize = BiliBiliSite.kFollowBatchSize;
    final chunks = Queue<List<FollowUser>>();
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize) > items.length ? items.length : i + chunkSize;
      chunks.add(items.sublist(i, end));
    }
    final batchWorkers = (globalCap < 4 ? globalCap : 4).clamp(1, chunks.length);
    final missing = <FollowUser>[];
    final database = DBService.instance;

    await Future.wait(List.generate(batchWorkers, (_) async {
      while (!_closed && revision == _refreshRevision && chunks.isNotEmpty) {
        final chunk = chunks.removeFirst();
        final guards = <({FollowUser item, Object request, FollowUser? stored})>[];
        final queryRoomIds = <String>[];
        for (final item in chunk) {
          final request = Object();
          _statusRequests[item] = request;
          final storedItem = database.followBox.get(item.id);
          guards.add((item: item, request: request, stored: storedItem));
          queryRoomIds.add(item.roomId);
        }

        Map<String, LiveFollowStatus> batchMap = const {};
        try {
          batchMap = await source
              .getFollowStatusBatch(roomIds: queryRoomIds)
              .timeout(_batchStatusTimeout);
        } catch (error) {
          Log.logPrint(error);
        }

        for (final guard in guards) {
          void finish() {
            if (identical(_statusRequests[guard.item], guard.request)) {
              _statusRequests.remove(guard.item);
            }
          }

          bool isCurrent() =>
              !_closed &&
              revision == _refreshRevision &&
              identical(_statusRequests[guard.item], guard.request) &&
              guard.stored != null &&
              database.followBox.isOpen &&
              identical(database.followBox.get(guard.item.id), guard.stored) &&
              followList.any((entry) => identical(entry, guard.item));

          if (_closed || revision != _refreshRevision) {
            finish();
            continue;
          }

          final status = batchMap[guard.item.roomId];
          if (status == null) {
            final shouldFallback = isCurrent();
            finish();
            if (shouldFallback) {
              missing.add(guard.item);
            }
            continue;
          }

          final task = await _applyFollowStatus(
            item: guard.item,
            revision: revision,
            source: source,
            site: site,
            storedItem: guard.stored,
            database: database,
            status: status,
            isCurrent: isCurrent,
            finish: finish,
            dirtyFollows: dirtyFollows,
            flushImmediate: false,
          );
          if (task != null) details.add(task);
          if (!_closed && revision == _refreshRevision) {
            updatedCount++;
          }
        }

        if (!_closed && revision == _refreshRevision) {
          _flushPendingFilterIfNeeded();
        }
      }
    }));

    if (missing.isNotEmpty && !_closed && revision == _refreshRevision) {
      await _runSingleSiteStatusQueue(
        siteId: siteId,
        items: missing,
        revision: revision,
        globalCap: globalCap,
        isMobile: isMobile,
        details: details,
        dirtyFollows: dirtyFollows,
      );
    }
  }

  Future<void> updateLiveStatus(FollowUser item) async {
    final task = await _readLiveStatus(
      item,
      _refreshRevision,
      flushImmediate: true,
    );
    if (task != null) await task();
  }

  Future<Future<void> Function()?> _readLiveStatus(
    FollowUser item,
    int revision, {
    bool requireListed = false,
    bool flushImmediate = false,
    Map<String, FollowUser>? dirtyFollows,
    void Function(bool success, Object? error)? onOutcome,
  }) async {
    final request = Object();
    _statusRequests[item] = request;
    final database = DBService.instance;
    final storedItem = database.followBox.get(item.id);
    // Compare the captured database identity as well as the round. Remove/re-add
    // of the same ID must never revive or overwrite the previous object.
    bool isCurrent() =>
        !_closed &&
        revision == _refreshRevision &&
        identical(_statusRequests[item], request) &&
        storedItem != null &&
        database.followBox.isOpen &&
        identical(database.followBox.get(item.id), storedItem) &&
        (!requireListed || followList.any((entry) => identical(entry, item)));

    void finish() {
      if (identical(_statusRequests[item], request)) {
        _statusRequests.remove(item);
      }
    }

    var handedOffToDetail = false;
    try {
      final site = Sites.allSites[item.siteId]!;
      final source = site.liveSite;
      final status =
          await source.getFollowStatus(roomId: item.roomId).timeout(_statusTimeout);
      onOutcome?.call(true, null);
      if (!isCurrent()) return null;

      final task = await _applyFollowStatus(
        item: item,
        revision: revision,
        source: source,
        site: site,
        storedItem: storedItem,
        database: database,
        status: status,
        isCurrent: isCurrent,
        finish: finish,
        dirtyFollows: dirtyFollows,
        flushImmediate: flushImmediate,
      );
      handedOffToDetail = task != null;
      return task;
    } catch (error) {
      onOutcome?.call(false, error);
      // A transient failure is not evidence that a previously live room ended.
      Log.logPrint(error);
      return null;
    } finally {
      if (!handedOffToDetail) finish();
    }
  }

  Future<Future<void> Function()?> _applyFollowStatus({
    required FollowUser item,
    required int revision,
    required LiveSite source,
    required Site site,
    required FollowUser? storedItem,
    required DBService database,
    required LiveFollowStatus status,
    required bool Function() isCurrent,
    required void Function() finish,
    Map<String, FollowUser>? dirtyFollows,
    bool flushImmediate = false,
  }) async {
    var enrich = false;
    try {
      if (!isCurrent()) return null;

      final isLiving = status.isLive;
      final nextStatus = isLiving ? 2 : 1;
      final statusChanged = item.liveStatus.value != nextStatus;
      if (!isLiving) {
        item.liveStartTime = null;
        item.heat = null;
      }
      if (statusChanged) {
        item.liveStatus.value = nextStatus;
      }
      if (!isLiving) {
        if (statusChanged) {
          _triggerFilterUpdate(immediate: flushImmediate);
        }
        return null;
      }

      if (!status.needsDetailFallback) {
        final previousHeat = item.heat;
        final previousStartTime = item.liveStartTime;
        item.liveStartTime = status.showTime;
        item.heat =
            status.online != null && status.online! > 0 ? status.online : null;
        final category = status.categoryName?.trim();
        final categoryChanged = category != null &&
            category.isNotEmpty &&
            category != item.categoryName;
        if (categoryChanged) {
          item.categoryName = category;
          if (identical(storedItem, item)) {
            if (dirtyFollows != null) {
              dirtyFollows[item.id] = item;
            } else {
              await database.addFollowSilently(item);
            }
          }
        }
        if (!isCurrent()) return null;
        final resolvedRoomId = status.resolvedRoomId?.trim() ?? '';
        if (site.id == Constant.kHuya &&
            RegExp(r'^[1-9][0-9]*$').hasMatch(resolvedRoomId) &&
            item.id != '${item.siteId}_$resolvedRoomId' &&
            await database.mergeFollowRoom(
              item,
              resolvedRoomId,
              isCurrent: isCurrent,
            )) {
          dirtyFollows?.remove(item.id);
          if (_closed || revision != _refreshRevision) return null;
          followList.assignAll(database.getFollowList());
          getAllTagList();
          _triggerFilterUpdate(immediate: flushImmediate);
        } else if (statusChanged ||
            categoryChanged ||
            previousHeat != item.heat ||
            previousStartTime != item.liveStartTime) {
          _triggerFilterUpdate(immediate: flushImmediate);
        }
        return null;
      }

      if (statusChanged) {
        _triggerFilterUpdate(immediate: flushImmediate);
      }

      enrich = true;
      return () async {
        try {
          if (!isCurrent()) return;
          final String? category;
          final String nextRoomId;
          final String? nextShowTime;
          final int? nextHeat;

          if (source is DouyinSite && status.categoryId != null) {
            final stub = LiveRoomDetail(
              roomId: status.resolvedRoomId ?? item.roomId,
              title: status.title ?? '',
              cover: '',
              userName: item.userName,
              userAvatar: '',
              online: status.online ?? 0,
              status: true,
              url: '',
              showTime: status.showTime,
              categoryId: status.categoryId,
              webParentCategoryName: status.parentCategoryName,
            );
            category = (await source
                    .getFollowCategoryName(stub)
                    .timeout(
                      _detailsTimeout,
                      onTimeout: () => status.parentCategoryName ?? '其他',
                    ))
                ?.trim();
            nextRoomId = status.resolvedRoomId ?? item.roomId;
            nextShowTime = status.showTime;
            nextHeat = status.online != null && status.online! > 0
                ? status.online
                : null;
          } else {
            final detail = await RoomStartupCache.instance
                .refresh(source, item.roomId)
                .timeout(_detailsTimeout);
            if (!isCurrent()) return;
            category = (source is DouyinSite
                    ? await source.getFollowCategoryName(detail).timeout(
                          _detailsTimeout,
                          onTimeout: () =>
                              detail.leafCategoryName ??
                              detail.webParentCategoryName,
                        )
                    : detail.categoryName)
                ?.trim();
            nextRoomId = detail.roomId;
            nextShowTime = detail.showTime;
            nextHeat = detail.online > 0 ? detail.online : null;
          }
          if (!isCurrent()) return;

          final previousHeat = item.heat;
          final previousStartTime = item.liveStartTime;
          item.liveStartTime = nextShowTime;
          item.heat = nextHeat;
          final categoryChanged = category != null &&
              category.isNotEmpty &&
              category != item.categoryName;
          if (categoryChanged) {
            item.categoryName = category;
            if (identical(storedItem, item)) {
              if (dirtyFollows != null) {
                dirtyFollows[item.id] = item;
              } else {
                await database.addFollowSilently(item);
              }
            }
          }
          if (!isCurrent()) return;
          if (site.id == Constant.kHuya &&
              RegExp(r'^[1-9][0-9]*$').hasMatch(nextRoomId) &&
              item.id != '${item.siteId}_$nextRoomId' &&
              await database.mergeFollowRoom(
                item,
                nextRoomId,
                isCurrent: isCurrent,
              )) {
            dirtyFollows?.remove(item.id);
            if (_closed || revision != _refreshRevision) return;
            followList.assignAll(database.getFollowList());
            getAllTagList();
            _triggerFilterUpdate(immediate: flushImmediate);
          } else if (isCurrent() &&
              (categoryChanged ||
                  previousHeat != item.heat ||
                  previousStartTime != item.liveStartTime)) {
            _triggerFilterUpdate(immediate: flushImmediate);
          }
        } catch (error) {
          Log.logPrint(error);
        } finally {
          finish();
        }
      };
    } finally {
      if (!enrich) finish();
    }
  }

  void filterData() {
    _filterFlushTimer?.cancel();
    _filterFlushTimer = null;
    _filterFlushPending = false;
    _lastFilterFlushAt = clock();
    followList.sort((a, b) => b.liveStatus.value.compareTo(a.liveStatus.value));
    liveList.assignAll(followList.where((x) => x.liveStatus.value == 2));
    notLiveList.assignAll(followList.where((x) => x.liveStatus.value == 1));
    final selectedTag = _selectedTag;
    if (selectedTag != null) {
      final currentTag =
          followTagList.firstWhereOrNull((tag) => tag.id == selectedTag.id);
      if (currentTag == null) {
        curTagFollowList.clear();
      } else {
        filterDataByTag(currentTag);
      }
    } else {
      curTagFollowList.clear();
    }
    if (!_closed) _updatedListController.add(0);
  }

  void exportFile() async {
    if (followList.isEmpty) {
      SmartDialog.showToast("列表为空");
      return;
    }

    try {
      var status = await Utils.checkStorgePermission();
      if (!status) {
        SmartDialog.showToast("无权限");
        return;
      }

      var dir = "";
      if (Platform.isIOS) {
        dir = (await getApplicationDocumentsDirectory()).path;
      } else {
        dir = await FilePicker.platform.getDirectoryPath() ?? "";
      }

      if (dir.isEmpty) {
        return;
      }
      var jsonFile = File(
          '$dir/SimpleLive_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json');
      var jsonText = generateJson();
      await jsonFile.writeAsString(jsonText);
      SmartDialog.showToast("已导出关注列表");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导出失败：$e");
    }
  }

  void inputFile() async {
    try {
      var status = await Utils.checkStorgePermission();
      if (!status) {
        SmartDialog.showToast("无权限");
        return;
      }
      var file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) {
        return;
      }
      var jsonFile = File(file.files.single.path!);
      await inputJson(await jsonFile.readAsString());
      SmartDialog.showToast("导入成功");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导入失败:$e");
    } finally {
      loadData();
    }
  }

  void exportText() {
    if (followList.isEmpty) {
      SmartDialog.showToast("列表为空");
      return;
    }
    var content = generateJson();
    Get.dialog(
      AlertDialog(
        title: const Text("导出为文本"),
        content: TextField(
          controller: TextEditingController(text: content),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          minLines: 5,
          maxLines: 8,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text("关闭"),
          ),
          TextButton(
            onPressed: () {
              Utils.copyToClipboard(content);
              Get.back();
            },
            child: const Text("复制"),
          ),
        ],
      ),
    );
  }

  void inputText() async {
    final TextEditingController textController = TextEditingController();
    await Get.dialog(
      AlertDialog(
        title: const Text("从文本导入"),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "请输入内容",
          ),
          minLines: 5,
          maxLines: 8,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text("关闭"),
          ),
          TextButton(
            onPressed: () async {
              var content = await Utils.getClipboard();
              if (content != null) {
                textController.text = content;
              }
            },
            child: const Text("粘贴"),
          ),
          TextButton(
            onPressed: () async {
              if (textController.text.isEmpty) {
                SmartDialog.showToast("内容为空");
                return;
              }
              try {
                await inputJson(textController.text);
                SmartDialog.showToast("导入成功");
                Get.back();
                loadData();
              } catch (e) {
                SmartDialog.showToast("导入失败，请检查内容是否正确");
              }
            },
            child: const Text("导入"),
          ),
        ],
      ),
    );
  }

  String generateJson() {
    var data = followList
        .map(
          (item) => {
            "siteId": item.siteId,
            "id": item.id,
            "roomId": item.roomId,
            "userName": item.userName,
            "face": item.face,
            "addTime": item.addTime.toString(),
            "tag": item.tag
          },
        )
        .toList();
    return jsonEncode(data);
  }

  Future inputJson(String content) async {
    var data = jsonDecode(content);

    for (var item in data) {
      var follow = FollowUser.fromJson(item);
      // 导入关注列表同时导入标签列表 此方法可优化为所有导入逻辑
      if (follow.tag != "全部") {
        // logic: 尝试添加，存在则返回已存在的对象
        var tag = await DBService.instance.addFollowTag(follow.tag);
        // 更新tag
        tag.userId.addIf(!tag.userId.contains(follow.id), follow.id);
        await DBService.instance.updateFollowTag(tag);
      }
      await DBService.instance.addFollow(follow);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _closed = true;
    _refreshRevision++;
    _foregroundDebounceTimer?.cancel();
    _foregroundDebounceTimer = null;
    _filterFlushTimer?.cancel();
    _filterFlushTimer = null;
    _filterFlushPending = false;
    _statusRequests.clear();
    updateTimer?.cancel();
    subscription?.cancel();
    super.onClose();
  }
}
