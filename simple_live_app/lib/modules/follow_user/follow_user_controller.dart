// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';

class FollowUserController extends BasePageController<FollowUser> {
  StreamSubscription<dynamic>? onUpdatedIndexedStream;
  StreamSubscription<dynamic>? onUpdatedListStream;

  /// 0:全部 1:直播中 2:未直播
  var filterMode = 0.obs;

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
    super.refreshData();
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    if (page > 1) {
      return Future.value([]);
    }
    if (filterMode.value == 0) {
      return FollowService.instance.followList.value;
    } else if (filterMode.value == 1) {
      return FollowService.instance.liveList.value;
    } else {
      return FollowService.instance.notLiveList.value;
    }
  }

  void filterData() {
    if (filterMode.value == 0) {
      list.assignAll(FollowService.instance.followList.value);
    } else if (filterMode.value == 1) {
      list.assignAll(FollowService.instance.liveList.value);
    } else if (filterMode.value == 2) {
      list.assignAll(FollowService.instance.notLiveList.value);
    }
  }

  void setFilterMode(int mode) {
    filterMode.value = mode;
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

  @override
  void onClose() {
    onUpdatedIndexedStream?.cancel();
    super.onClose();
  }
}
