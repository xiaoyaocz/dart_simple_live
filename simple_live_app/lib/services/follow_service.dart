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
import 'package:simple_live_app/services/live_notification_service.dart';
import 'package:simple_live_app/services/room_startup_cache.dart';
import 'package:simple_live_core/simple_live_core.dart';

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

  // A reload invalidates every outstanding response, including reloads without I/O.
  int _refreshRevision = 0;
  bool _closed = false;
  bool _wasAway = false;
  bool _foregroundRefreshPending = false;
  FollowUserTag? _selectedTag;
  final Map<FollowUser, Object> _statusRequests = Map.identity();

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
      return;
    }
    if (!_wasAway) return;
    _wasAway = false;
    // 桌面窗口重新获得焦点、手机从后台返回共用同一入口。
    // 合并重复事件，不打断已经进行中的开播状态查询。
    if (_closed || updating.value || _foregroundRefreshPending) return;
    unawaited(_refreshOnForeground());
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

  Future<void> loadData({bool updateStatus = true}) async {
    final revision = ++_refreshRevision;
    updatedCount = 0;
    updating.value = false;
    await DBService.instance.normalizeFollowTags();
    if (_closed || revision != _refreshRevision) return;
    followList.assignAll(DBService.instance.getFollowList());
    getAllTagList();
    // Empty and cache-only reloads must publish the same coherent snapshot.
    filterData();
    if (updateStatus && followList.isNotEmpty) {
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
      // 网络 I/O 密集型任务，并发数可以是 CPU 核心数的 2-3 倍
      var optimal = (cpuCount * 2.5).round();
      // 限制在合理范围内（最少 4，最多 20）
      return optimal.clamp(4, 20);
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

  static const _statusTimeout = Duration(seconds: 8);
  static const _detailsTimeout = Duration(seconds: 5);

  Future<void> startUpdateStatus() async {
    final revision = ++_refreshRevision;
    updatedCount = 0;
    final statuses = Queue<FollowUser>.from(interleaveByPlatform(followList));
    updating.value = statuses.isNotEmpty;
    if (_closed || statuses.isEmpty) return;
    final concurrency = getOptimalConcurrency().clamp(1, statuses.length);
    final details = Queue<Future<void> Function()>();

    Future<void> statusWorker() async {
      while (!_closed && revision == _refreshRevision && statuses.isNotEmpty) {
        final task = await _readLiveStatus(statuses.removeFirst(), revision,
            requireListed: true);
        if (task != null) details.add(task);
        if (_closed || revision != _refreshRevision) return;
        updatedCount++;
      }
    }

    Future<void> detailWorker() async {
      while (details.isNotEmpty) {
        await details.removeFirst()();
      }
    }

    await Future.wait(List.generate(concurrency, (_) => statusWorker()));
    if (!_closed && revision == _refreshRevision) updating.value = false;
    // Keep catalog, authentication and playback requests out of the status queue.
    await Future.wait(List.generate(concurrency, (_) => detailWorker()));
    if (!_closed &&
        revision == _refreshRevision &&
        Get.isRegistered<LiveNotificationService>()) {
      unawaited(LiveNotificationService.instance
          .handleFollowRefreshCompleted(followList.toList()));
    }
  }

  Future<void> updateLiveStatus(FollowUser item) async {
    final task = await _readLiveStatus(item, _refreshRevision);
    if (task != null) await task();
  }

  Future<Future<void> Function()?> _readLiveStatus(
      FollowUser item, int revision, {bool requireListed = false}) async {
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
      if (identical(_statusRequests[item], request)) _statusRequests.remove(item);
    }

    var enrich = false;
    try {
      final site = Sites.allSites[item.siteId]!;
      final source = site.liveSite;
      final douyinDetail = source is DouyinSite
          ? await RoomStartupCache.instance.refresh(source, item.roomId)
              .timeout(_statusTimeout)
          : null;
      final isLiving = douyinDetail?.status ??
          await source.getLiveStatus(roomId: item.roomId).timeout(_statusTimeout);
      if (!isCurrent()) return null;

      final nextStatus = isLiving ? 2 : 1;
      if (!isLiving) {
        item.liveStartTime = null;
        item.heat = null;
      }
      if (item.liveStatus.value != nextStatus) {
        item.liveStatus.value = nextStatus;
        filterData();
      }
      if (!isLiving) return null;

      enrich = true;
      return () async {
        try {
          if (!isCurrent()) return;
          final detail = douyinDetail ??
              await RoomStartupCache.instance.refresh(source, item.roomId)
                  .timeout(_detailsTimeout);
          if (!isCurrent()) return;
          final category = (source is DouyinSite
                  ? await source.getFollowCategoryName(detail).timeout(
                        _detailsTimeout,
                        onTimeout: () => detail.leafCategoryName ??
                            detail.webParentCategoryName,
                      )
                  : detail.categoryName)
              ?.trim();
          if (!isCurrent()) return;
          final previousHeat = item.heat;
          item.liveStartTime = detail.showTime;
          item.heat = detail.online > 0 ? detail.online : null;
          final categoryChanged = category != null &&
              category.isNotEmpty &&
              category != item.categoryName;
          if (categoryChanged) {
            item.categoryName = category;
            if (identical(storedItem, item)) {
              await database.addFollowSilently(item);
            }
          }
          if (!isCurrent()) return;
          if (site.id == Constant.kHuya &&
              RegExp(r'^[1-9][0-9]*$').hasMatch(detail.roomId) &&
              item.id != '${item.siteId}_${detail.roomId}' &&
              await database.mergeFollowRoom(item, detail.roomId,
                  isCurrent: isCurrent)) {
            if (_closed || revision != _refreshRevision) return;
            followList.assignAll(database.getFollowList());
            getAllTagList();
            filterData();
          } else if (isCurrent() &&
              (categoryChanged || previousHeat != item.heat)) {
            filterData();
          }
        } catch (error) {
          Log.logPrint(error);
        } finally {
          finish();
        }
      };
    } catch (error) {
      // A transient failure is not evidence that a previously live room ended.
      Log.logPrint(error);
      return null;
    } finally {
      if (!enrich) finish();
    }
  }

  void filterData() {
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
    _statusRequests.clear();
    updateTimer?.cancel();
    subscription?.cancel();
    super.onClose();
  }
}
