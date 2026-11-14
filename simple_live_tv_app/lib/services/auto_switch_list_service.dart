import 'dart:convert';

import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/models/auto_switch_item.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/follow_user_tag.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';

/// 自动换台轮播列表（#154）。
///
/// 开启"自动换台使用轮播列表"后，自动换台的候选源从关注列表切换为该列表：
/// 换台前整体刷新成员开播状态，再按顺序（从当前成员环形顺延）或随机点名在播成员。
/// 成员为跨平台房间快照，独立于关注生命周期存储。
class AutoSwitchListService extends GetxService {
  static AutoSwitchListService get instance =>
      Get.find<AutoSwitchListService>();

  /// 有序列表（持久化）
  RxList<AutoSwitchListItem> items = RxList<AutoSwitchListItem>();

  /// 成员开播状态缓存：key = "siteId_roomId"，refreshStatuses 时整体重建
  RxMap<String, bool> statusCache = RxMap<String, bool>();

  /// 顺序模式游标：当前播放成员在 items 中的下标（运行时状态，不持久化）
  int cursor = 0;

  DateTime? _lastStatusRefreshAt;

  /// 并发探测成员状态的线程数
  static const int _probeConcurrency = 4;

  /// 状态缓存的复用时长：手动切台短时间连按不重复探测
  static const Duration statusCacheMaxAge = Duration(seconds: 60);

  void loadFromStorage() {
    final raw = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoSwitchListItems, "");
    items.assignAll(_decodeItems(raw));
  }

  List<AutoSwitchListItem> _decodeItems(String raw) {
    if (raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AutoSwitchListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      Log.e("轮播列表数据解析失败：$raw", stackTrace);
      return [];
    }
  }

  void persist() {
    LocalStorageService.instance.setValue(
      LocalStorageService.kAutoSwitchListItems,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  bool contains(String siteId, String roomId) {
    return items.any((e) => e.siteId == siteId && e.roomId == roomId);
  }

  /// 追加单个成员，重复（siteId+roomId）自动忽略；返回是否新增
  bool addItem(String siteId, String roomId, String userName) {
    if (contains(siteId, roomId)) {
      return false;
    }
    items.add(AutoSwitchListItem(
      siteId: siteId,
      roomId: roomId,
      userName: userName,
    ));
    persist();
    return true;
  }

  /// 批量追加，自动去重；返回实际新增数
  int addItems(List<AutoSwitchListItem> newItems) {
    var added = 0;
    for (final item in newItems) {
      if (contains(item.siteId, item.roomId)) {
        continue;
      }
      items.add(item);
      added += 1;
    }
    if (added > 0) {
      persist();
    }
    return added;
  }

  void removeItem(String id) {
    final index = items.indexWhere((e) => e.id == id);
    if (index < 0) {
      return;
    }
    items.removeAt(index);
    _normalizeCursorAfterRemoval(index);
    persist();
  }

  /// 上下平移成员（TV 遥控器没有拖拽，用按钮移动实现排序）
  void moveItem(int index, int offset) {
    final target = index + offset;
    if (index < 0 ||
        index >= items.length ||
        target < 0 ||
        target >= items.length) {
      return;
    }
    final item = items.removeAt(index);
    items.insert(target, item);
    // 游标跟随被移动的成员，保证顺序模式不跳位
    if (cursor == index) {
      cursor = target;
    } else if (index < cursor && target >= cursor) {
      cursor -= 1;
    } else if (index > cursor && target <= cursor) {
      cursor += 1;
    }
    persist();
  }

  void clearAll() {
    items.clear();
    cursor = 0;
    statusCache.clear();
    persist();
  }

  /// 批量导入关注；返回实际新增数
  int importFollows(List<FollowUser> follows) {
    return addItems(
      follows
          .map(
            (e) => AutoSwitchListItem(
              siteId: e.siteId,
              roomId: e.roomId,
              userName: e.userName,
            ),
          )
          .toList(),
    );
  }

  /// 批量导入指定标签的成员（含"字符串有、实体缺"的旧数据兜底）；返回实际新增数
  int importTag(FollowUserTag tag) {
    final tagName = tag.tag.trim();
    final follows = <FollowUser>[];
    for (final id in tag.userId) {
      final follow = DBService.instance.followBox.get(id);
      if (follow != null) {
        follows.add(follow);
      }
    }
    for (final item in DBService.instance.getFollowList()) {
      if (item.tag.trim() == tagName &&
          !follows.any((e) => e.id == item.id)) {
        follows.add(item);
      }
    }
    return importFollows(follows);
  }

  /// 整体重建成员开播状态缓存。
  /// 返回 false 表示触发平台风控（444），调用方应中止本次自动换台。
  Future<bool> refreshStatuses() async {
    final valid =
        items.where((e) => Sites.allSites.containsKey(e.siteId)).toList();
    final results = <String, bool>{};
    var riskControl = false;
    var index = 0;

    Future<void> worker() async {
      while (index < valid.length && !riskControl) {
        final item = valid[index];
        index += 1;
        try {
          results[item.id] = await Sites.allSites[item.siteId]!.liveSite
              .getLiveStatus(roomId: item.roomId);
        } catch (e, stackTrace) {
          if (e is CoreError && e.statusCode == 444) {
            Log.e("轮播成员状态查询触发风控：${item.id}", stackTrace);
            riskControl = true;
            return;
          }
          Log.e("轮播成员状态查询失败：${item.id}", stackTrace);
          results[item.id] = false;
        }
      }
    }

    final workers = <Future<void>>[
      for (var i = 0;
          i < _probeConcurrency && i < valid.length;
          i++)
        worker(),
    ];
    if (workers.isNotEmpty) {
      await Future.wait(workers);
    }
    if (riskControl) {
      return false;
    }
    statusCache.clear();
    statusCache.addAll(results);
    _lastStatusRefreshAt = DateTime.now();
    return true;
  }

  /// 缓存仍新鲜时直接复用（手动切台连按场景），否则重新探测
  Future<bool> ensureStatusFresh() async {
    final fresh = _lastStatusRefreshAt != null &&
        DateTime.now().difference(_lastStatusRefreshAt!) <
            statusCacheMaxAge &&
        statusCache.isNotEmpty;
    if (fresh) {
      return true;
    }
    return refreshStatuses();
  }

  /// 在播成员（基于状态缓存，调用前先 refreshStatuses/ensureStatusFresh）
  List<AutoSwitchListItem> liveItems({String? excludeId}) {
    return items
        .where(
          (e) =>
              e.id != excludeId && statusCache[e.id] == true,
        )
        .toList();
  }

  void _normalizeCursorAfterRemoval(int removedIndex) {
    if (items.isEmpty) {
      cursor = 0;
      return;
    }
    if (cursor == removedIndex) {
      if (cursor >= items.length) {
        cursor = 0;
      }
      return;
    }
    if (cursor > removedIndex) {
      cursor -= 1;
    }
  }
}
