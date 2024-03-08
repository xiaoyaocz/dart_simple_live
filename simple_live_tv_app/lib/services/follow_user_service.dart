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

  RxList<FollowUser> livingList = RxList<FollowUser>();

  @override
  void onInit() {
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      refreshData();
    });

    if (list.isEmpty) {
      refreshData();
    }
    super.onInit();
  }

  var updatedCount = 0;
  var updating = false.obs;
  @override
  Future<List<FollowUser>> getData(int page, int pageSize) {
    if (page > 1) {
      return Future.value([]);
    }

    var followList = DBService.instance.getFollowList();

    updatedCount = 0;
    updating.value = true;
    for (var item in followList) {
      updateLiveStatus(item);
    }
    if (followList.isEmpty) {
      updating.value = false;
    }
    return Future.value(followList);
  }

  void sortList() {
    list.sort((a, b) => b.liveStatus.value.compareTo(a.liveStatus.value));
    updateLivingList();
  }

  void updateLivingList() {
    livingList.assignAll(list.where((x) => x.liveStatus.value == 2));
  }

  void updateLiveStatus(FollowUser item) async {
    try {
      var site = Sites.allSites[item.siteId]!;
      item.liveStatus.value =
          (await site.liveSite.getLiveStatus(roomId: item.roomId)) ? 2 : 1;
      updatedCount++;
      if (updatedCount == list.length) {
        sortList();
        updating.value = false;
      }
      //sortList();
      //updateLivingList();
    } catch (e) {
      Log.logPrint(e);
    }
  }

  void removeItem(FollowUser item, {bool refresh = true}) async {
    var result =
        await Utils.showAlertDialog("确定要取消关注${item.userName}吗?", title: "取消关注");
    if (!result) {
      return;
    }
    await DBService.instance.followBox.delete(item.id);
    if (refresh) {
      refreshData();
    } else {
      list.remove(item);
      livingList.remove(item);
    }
  }

  @override
  void onClose() {
    subscription?.cancel();

    super.onClose();
  }
}
