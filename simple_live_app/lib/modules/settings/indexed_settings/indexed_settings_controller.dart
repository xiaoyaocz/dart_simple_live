import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';

class IndexedSettingsController extends GetxController {
  RxList<String> siteSort = RxList<String>();
  RxList<String> homeSort = RxList<String>();
  RxSet<String> homeHidden = <String>{}.obs;
  RxSet<String> siteHidden = <String>{}.obs;
  RxList<String> liveRoomTabSort = RxList<String>();
  RxList<String> liveRoomQuickAccessSort = RxList<String>();
  RxSet<String> liveRoomQuickAccessEnabled = <String>{}.obs;
  RxBool contributionRankEnable = false.obs;
  RxBool liveEventFlowEnable = false.obs;
  @override
  void onInit() {
    siteSort = AppSettingsController.instance.siteSort;
    homeSort = AppSettingsController.instance.homeSort;
    homeHidden = AppSettingsController.instance.homeHidden;
    siteHidden = AppSettingsController.instance.siteHidden;
    liveRoomTabSort = AppSettingsController.instance.liveRoomTabSort;
    liveRoomQuickAccessSort =
        AppSettingsController.instance.liveRoomQuickAccessSort;
    liveRoomQuickAccessEnabled =
        AppSettingsController.instance.liveRoomQuickAccessEnabled;
    contributionRankEnable =
        AppSettingsController.instance.contributionRankEnable;
    liveEventFlowEnable = AppSettingsController.instance.liveEventFlowEnable;
    super.onInit();
  }

  void updateSiteSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = siteSort.removeAt(oldIndex);
    siteSort.insert(newIndex, item);
    // ignore: invalid_use_of_protected_member
    AppSettingsController.instance.setSiteSort(siteSort.value);
  }

  void setHomeVisible(String key, bool visible) {
    AppSettingsController.instance.setHomeVisible(key, visible);
  }

  Future<void> setSiteVisible(String key, bool visible) async {
    final applied = AppSettingsController.instance.setSiteVisible(key, visible);
    if (!applied) {
      // “至少保留一个平台”守卫拦截，弹窗说明而不是静默无效
      await Utils.showMessageDialog(
        "至少需要保留一个可见平台用于分类页展示，请先恢复其他平台后再隐藏。",
        title: "无法隐藏",
      );
    }
  }

  void updateHomeSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = homeSort.removeAt(oldIndex);
    homeSort.insert(newIndex, item);
    // ignore: invalid_use_of_protected_member
    AppSettingsController.instance.setHomeSort(homeSort.value);
  }

  void updateLiveRoomTabSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = liveRoomTabSort.removeAt(oldIndex);
    liveRoomTabSort.insert(newIndex, item);
    // ignore: invalid_use_of_protected_member
    AppSettingsController.instance.setLiveRoomTabSort(liveRoomTabSort.value);
  }

  void updateLiveRoomQuickAccessSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = liveRoomQuickAccessSort.removeAt(oldIndex);
    liveRoomQuickAccessSort.insert(newIndex, item);
    AppSettingsController.instance.setLiveRoomQuickAccessSort(
      liveRoomQuickAccessSort.toList(),
    );
  }

  void setLiveRoomQuickAccessEnabled(String key, bool enabled) {
    AppSettingsController.instance.setLiveRoomQuickAccessEnabled(key, enabled);
  }

  void setContributionRankEnable(bool enabled) {
    AppSettingsController.instance.setContributionRankEnable(enabled);
  }

  void setLiveEventFlowEnable(bool enabled) {
    AppSettingsController.instance.setLiveEventFlowEnable(enabled);
  }
}
