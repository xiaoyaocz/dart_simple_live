// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class FollowUserController extends BasePageController<FollowUser> {
  StreamSubscription<dynamic>? onUpdatedIndexedStream;
  StreamSubscription<dynamic>? onUpdatedListStream;

  /// 0:全部 1:直播中 2:未直播
  var filterMode = FollowUserTag(id: "0", tag: "全部", userId: []).obs;
  final defaultFilterId = '0'.obs;
  RxList<FollowUserTag> tagList = [
    FollowUserTag(id: "0", tag: "全部", userId: []),
    FollowUserTag(id: "1", tag: "直播中", userId: []),
    FollowUserTag(id: "2", tag: "未开播", userId: []),
  ].obs;

  // 用户自定义标签
  RxList<FollowUserTag> userTagList = <FollowUserTag>[].obs;

  final List<String> _categoryOrder = [];
  int _snapshotRevision = 0;

  List<FollowUser> sortCategoryMembers(
      List<FollowUser> members, List<String> siteOrder) {
    final indexed = members.asMap().entries.toList();
    final ranks = {for (var i = 0; i < siteOrder.length; i++) siteOrder[i]: i};
    for (final item in members) {
      ranks.putIfAbsent(item.siteId, () => ranks.length);
    }
    indexed.sort((a, b) {
      final platform = ranks[a.value.siteId]!.compareTo(ranks[b.value.siteId]!);
      if (platform != 0) return platform;
      final aHeat = a.value.heat;
      final bHeat = b.value.heat;
      if (aHeat == null && bHeat != null) return 1;
      if (aHeat != null && bHeat == null) return -1;
      final heat = aHeat == null ? 0 : bHeat!.compareTo(aHeat);
      return heat != 0 ? heat : a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList();
  }

  List<MapEntry<String, List<FollowUser>>> sortCategoryGroups(
      Map<String, List<FollowUser>> groups) {
    final entries = groups.entries.toList();
    final previousOrder = {
      for (var i = 0; i < _categoryOrder.length; i++) _categoryOrder[i]: i,
    };
    final order = {
      for (var i = 0; i < entries.length; i++)
        entries[i].key: previousOrder[entries[i].key] ?? _categoryOrder.length + i,
    };
    final liveCounts = {
      for (final entry in entries)
        entry.key: entry.value.where((item) => item.liveStatus.value == 2).length,
    };
    entries.sort((a, b) {
      if (a.key == b.key) return 0;
      if (a.key == '其他') return 1;
      if (b.key == '其他') return -1;
      final difference = liveCounts[b.key]!.compareTo(liveCounts[a.key]!);
      return difference != 0
          ? difference
          : order[a.key]!.compareTo(order[b.key]!);
    });
    // 刷新暂时清空列表时保留顺序，避免同人数分类在重新加载后跳动。
    if (entries.isNotEmpty) {
      _categoryOrder
        ..clear()
        ..addAll(entries.map((entry) => entry.key));
    }
    return entries;
  }

  @override
  void onInit() {
    restoreDefaultFilter();
    onUpdatedIndexedStream = EventBus.instance.listen(
      EventBus.kBottomNavigationBarClicked,
          (index) {
        if (index == 1) {
          scrollToTopOrRefresh();
        }
      },
    );
    onUpdatedListStream =
        FollowService.instance.updatedListStream.listen((event) {
      filterData();
    });
    super.onInit();
  }

  @override
  Future refreshData() async {
    await FollowService.instance.loadData();
    updateTagList();
    await loadData();
  }

  @override
  Future<void> loadData() async {
    if (loadding || isClosed) return;
    loadding = true;
    pageLoadding.value = true;
    pageError.value = false;
    final revision = _snapshotRevision;
    try {
      // 关注是完整的本地快照，不使用基类的分页 addAll。
      final result = await getData(1, pageSize);
      if (isClosed) return;
      // 等待期间可能切换筛选、开关播或取消关注，旧结果不能覆盖新状态。
      _publishSnapshot(revision == _snapshotRevision ? result : _filteredUsers());
    } catch (error) {
      if (!isClosed && revision == _snapshotRevision) {
        handleError(error, showPageError: list.isEmpty);
      }
    } finally {
      loadding = false;
      if (!isClosed) pageLoadding.value = false;
    }
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    if (page > 1) {
      return Future.value([]);
    }
    return _filteredUsers();
  }

  List<FollowUser> _filteredUsers() {
    final service = FollowService.instance;
    final Iterable<FollowUser> source;
    if (filterMode.value.tag == "全部") {
      source = service.followList;
    } else if (filterMode.value.tag == "直播中") {
      source = service.liveList;
    } else if (filterMode.value.tag == "未开播") {
      source = service.notLiveList;
    } else {
      service.filterDataByTag(filterMode.value);
      source = service.curTagFollowList;
    }
    // 页面只能持有独立快照，不能共享服务的可变底层列表。
    // 只复制列表容器 (O(n))，保留 FollowUser 身份与响应式开播状态。
    return source.toList();
  }

  void updateTagList() {
    userTagList.assignAll(FollowService.instance.followTagList);
    tagList.value = tagList.take(3).toList();
    for (var i in userTagList) {
      if (!tagList.contains(i)) {
        tagList.add(i);
      }
    }
  }

  void filterData() {
    _publishSnapshot(_filteredUsers());
  }

  void _publishSnapshot(List<FollowUser> users) {
    _snapshotRevision++;
    // 只替换容器，保留原主播对象；不按昵称合并跨平台同名主播。
    list.value = users;
    currentPage = 1;
    canLoadMore.value = false;
    pageEmpty.value = users.isEmpty;
    pageError.value = false;
  }

  void setFilterMode(FollowUserTag tag) {
    filterMode.value = tag;
    filterData();
  }

  void restoreDefaultFilter() {
    final saved = Get.isRegistered<LocalStorageService>()
        ? LocalStorageService.instance
            .getValue<dynamic>(LocalStorageService.kFollowDefaultFilter, '0')
        : '0';
    // 只允许内置状态，旧值或损坏的设置不能变成自定义标签筛选。
    final tag = tagList
        .take(3)
        .firstWhere((tag) => tag.id == saved, orElse: () => tagList.first);
    defaultFilterId.value = tag.id;
    setFilterMode(tag);
  }

  Future<void> setDefaultFilter(FollowUserTag tag) async {
    if (!tagList.take(3).contains(tag)) return;
    await LocalStorageService.instance
        .setValue(LocalStorageService.kFollowDefaultFilter, tag.id);
    // 保存成功才更新菜单标记；普通点击仍只调用 setFilterMode。
    defaultFilterId.value = tag.id;
  }

  Future<void> removeItem(FollowUser item, {bool confirm = true}) async {
    if (confirm) {
      final result = await Utils.showAlertDialog(
          "确定要取消关注${item.userName}吗?", title: "取消关注");
      if (!result) return;
    }
    // 取消关注同时删除标签内的 userId
    if(item.tag != "全部"){
      var tag = tagList.firstWhere((tag) => tag.tag == item.tag);
      tag.userId.remove(item.id);
      updateTag(tag);
    }
    await DBService.instance.deleteFollow(item.id);
    await refreshData();
  }

  void updateItem(FollowUser item){
    FollowService.instance.addFollow(item);
  }
  // 修改item的标签
  void setItemTag(FollowUser item, FollowUserTag targetTag) {
    FollowUserTag tarTag = targetTag;
    FollowUserTag curTag =
    tagList.firstWhere((tag) => tag.tag == item.tag);
    // 从当前标签（非全部）删除item 向目标标签(全部包含所有item == 非全部)添加item
    curTag.userId.remove(item.id);
    tarTag.userId.addIf(!tarTag.userId.contains(item.id), item.id);
    // 数据库更新
    item.tag = tarTag.tag;
    updateTag(curTag);
    updateTag(tarTag);
    updateItem(item);
    filterData();
  }

  Future<void> removeTag(FollowUserTag tag) async {
    // 将tag下的所有follow设置为全部
    for(var i in tag.userId){
      var follow = DBService.instance.followBox.get(i);
      if(follow != null){
        follow.tag = "全部";
        updateItem(follow);
      }
    }
    await FollowService.instance.delFollowUserTag(tag);
    updateTagList();
    Log.i('删除tag${tag.tag}');
  }

  void addTag(String tag) async {
    FollowService.instance
        .addFollowUserTag(tag)
        .then((value) => updateTagList());
  }

  void updateTag(FollowUserTag followUserTag) {
    if(followUserTag.tag == '全部'){
      return;
    }
    FollowService.instance.updateFollowUserTag(followUserTag);
  }

  void updateTagName(FollowUserTag followUserTag, String newTagName) {
    // 未操作
    if (followUserTag.tag == newTagName) {
      return;
    }
    // 避免重名
    if (tagList.any((item) => item.tag == newTagName)) {
      SmartDialog.showToast("标签名重复，修改失败");
      return;
    }
    final FollowUserTag newTag = followUserTag.copyWith(tag: newTagName);
    updateTag(newTag);
    // update item's tag when update tagName
    for(var i in newTag.userId){
      var follow = DBService.instance.followBox.get(i);
      if(follow != null){
        follow.tag = newTagName;
        updateItem(follow);
      }
    }
    SmartDialog.showToast("标签名修改成功");
    updateTagList();
  }

  // 调整标签顺序
  void updateTagOrder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1; // 处理索引调整
    final item = userTagList.removeAt(oldIndex);
    userTagList.insert(newIndex, item);
    tagList.value = tagList.take(3).toList();
    tagList.addAll(userTagList);
    DBService.instance.updateFollowTagOrder(userTagList);
  }

  @override
  void onClose() {
    onUpdatedIndexedStream?.cancel();
    onUpdatedListStream?.cancel();
    super.onClose();
  }
}
