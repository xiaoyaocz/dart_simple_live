import 'dart:async';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/services/db_service.dart';

class FollowUserService extends BasePageController<FollowUser> {
  static FollowUserService get instance => Get.find<FollowUserService>();
  StreamSubscription<dynamic>? subscription;

  RxList<FollowUser> allList = RxList<FollowUser>();
  RxList<FollowUser> livingList = RxList<FollowUser>();

  /// 0:全部 1:直播中 2:未直播
  var filterMode = 0.obs;

  @override
  void onInit() {
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      refreshData();
    });

    if (allList.isEmpty) {
      refreshData();
    }
    super.onInit();
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) {
    if (page > 1) {
      return Future.value([]);
    }
    var list = DBService.instance.getFollowList();
    for (var item in list) {
      updateLiveStatus(item);
    }
    allList.assignAll(list);
    return Future.value(list);
  }

  void filterData() {
    if (filterMode.value == 0) {
      list.assignAll(allList);
      list.sort((a, b) => b.liveStatus.value.compareTo(a.liveStatus.value));
    } else if (filterMode.value == 1) {
      list.assignAll(allList.where((x) => x.liveStatus.value == 2));
    } else if (filterMode.value == 2) {
      list.assignAll(allList.where((x) => x.liveStatus.value == 1));
    }
    allList.sort((a, b) => b.liveStatus.value.compareTo(a.liveStatus.value));
  }

  void setFilterMode(int mode) {
    filterMode.value = mode;
    filterData();
  }

  void updateLivingList() {
    livingList.assignAll(allList.where((x) => x.liveStatus.value == 2));
  }

  void updateLiveStatus(FollowUser item) async {
    try {
      var site = Sites.allSites[item.siteId]!;
      item.liveStatus.value =
          (await site.liveSite.getLiveStatus(roomId: item.roomId)) ? 2 : 1;

      filterData();
      updateLivingList();
    } catch (e) {
      Log.logPrint(e);
    }
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
    subscription?.cancel();

    super.onClose();
  }
}
