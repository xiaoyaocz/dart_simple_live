import 'dart:async';

import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/db_service.dart';

class FollowUserController extends BasePageController<FollowUser> {
  StreamSubscription<dynamic>? subscription;
  @override
  void onInit() {
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      refreshData();
    });
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
    return Future.value(list);
  }

  void updateLiveStatus(FollowUser item) async {
    try {
      var site = Sites.supportSites.firstWhere((x) => x.id == item.siteId);
      item.liveStatus.value =
          (await site.liveSite.getLiveStatus(roomId: item.roomId)) ? 2 : 1;
      list.sort((a, b) => b.liveStatus.value.compareTo(a.liveStatus.value));
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
