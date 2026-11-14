import 'package:get/get.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/follow_user_tag.dart';
import 'package:simple_live_tv_app/services/auto_switch_list_service.dart';

/// 轮播列表管理页控制器（#154）
class AutoSwitchListController extends GetxController {
  AutoSwitchListService get service => AutoSwitchListService.instance;

  void removeItem(String id) {
    service.removeItem(id);
  }

  void moveItem(int index, int offset) {
    service.moveItem(index, offset);
  }

  void clearAll() {
    service.clearAll();
  }

  int importFollows(List<FollowUser> follows) {
    return service.importFollows(follows);
  }

  int importTag(FollowUserTag tag) {
    return service.importTag(tag);
  }
}
