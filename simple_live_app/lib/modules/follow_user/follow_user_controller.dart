// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';

class FollowUserController extends BasePageController<FollowUser> {
  StreamSubscription<dynamic>? onUpdatedIndexedStream;
  StreamSubscription<dynamic>? onUpdatedListStream;

  /// 0:全部 1:直播中 2:未直播
  var filterMode = FollowUserTag(id: "0", tag: "全部", userId: []).obs;
  RxList<FollowUserTag> tagList = [
    FollowUserTag(id: "0", tag: "全部", userId: []),
    FollowUserTag(id: "1", tag: "直播中", userId: []),
    FollowUserTag(id: "2", tag: "未开播", userId: []),
  ].obs;

  // 用户自定义标签
  RxList<FollowUserTag> userTagList = <FollowUserTag>[].obs;

  @override
  void onInit() {
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
    super.refreshData();
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    if (page > 1) {
      return Future.value([]);
    }
    if (filterMode.value.tag == "全部") {
      return FollowService.instance.followList.value;
    } else if (filterMode.value.tag == "直播中") {
      return FollowService.instance.liveList.value;
    } else if (filterMode.value.tag == "未开播") {
      return FollowService.instance.notLiveList.value;
    } else {
      FollowService.instance.filterDataByTag(filterMode.value);
      return FollowService.instance.curTagFollowList.value;
    }
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
    if (filterMode.value.tag == "全部") {
      list.assignAll(FollowService.instance.followList.value);
    } else if (filterMode.value.tag == "直播中") {
      list.assignAll(FollowService.instance.liveList.value);
    } else if (filterMode.value.tag == "未开播") {
      list.assignAll(FollowService.instance.notLiveList.value);
    } else {
      FollowService.instance.filterDataByTag(filterMode.value);
      list.assignAll(FollowService.instance.curTagFollowList);
    }
  }

  void setFilterMode(FollowUserTag tag) {
    filterMode.value = tag;
    filterData();
  }

  void removeItem(FollowUser item) async {
    var result =
        await Utils.showAlertDialog("确定要取消关注${item.userName}吗?", title: "取消关注");
    if (!result) {
      return;
    }
    await DBService.instance.followBox.delete(item.id);
    refreshData();
  }

  void setItemTag(FollowUser item, FollowUserTag tag) {
    int tagIndex = tagList.indexOf(tag);
    int curTagIndex = tagList.indexOf(filterMode.value);
    // 处于默认标签选择默认 或切换标签->return
    if ((tagIndex == 0 && curTagIndex < 3) || (tagIndex == curTagIndex)) {
      return;
    }
    // 处于默认标签选择自定义标签->加入选择tag
    if (tagIndex >= 3 && curTagIndex < 3) {
      tag.userId.addIf(!tag.userId.contains(item.id), item.id);
    }
    // 处于自定义标签选择默认->从当前tag移除
    else if (tagIndex == 0 && curTagIndex >= 3) {
      filterMode.value.userId.remove(item.id);
    }
    // 处于自定义标签选择自定义标签->从当前tag移除 加入选择tag
    else if (tagIndex >= 3 && curTagIndex >= 3 && tagIndex != curTagIndex) {
      filterMode.value.userId.remove(item.id);
      // 目标标签不包含当前关注则加入
      tag.userId.addIf(!tag.userId.contains(item.id), item.id);
    }
    // 更新当前tag和目标tag
    if (curTagIndex >= 3) {
      updateTag(filterMode.value);
    }
    // 目标tag不为全部更新
    if(tagIndex != 0){
      updateTag(tag);
    }
    filterData();
  }

  void removeIdFromTag() {}

  void removeTag(FollowUserTag tag) {
    FollowService.instance.delFollowUserTag(tag);
    updateTagList();
  }

  void addTag(String tag) async {
    FollowService.instance
        .addFollowUserTag(tag)
        .then((value) => updateTagList());
  }

  void updateTag(FollowUserTag followUserTag) {
    FollowService.instance.updateFollowUserTag(followUserTag);
  }

  void updateTagName(FollowUserTag followUserTag, String tag) {
    // 避免重名
    if (tagList.any((item) => item.tag == tag)) {
      SmartDialog.showToast("标签名重复，修改失败");
      return;
    }
    final FollowUserTag item = followUserTag.copyWith(tag: tag);
    DBService.instance.updateFollowTag(item);
    updateTagList();
  }

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
    super.onClose();
  }
}
