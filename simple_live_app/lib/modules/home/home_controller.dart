import 'dart:async';

import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/site_tabs_mixin.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin, SiteTabsMixin {
  HomeController() {
    initSiteTabs();
  }

  StreamSubscription<dynamic>? streamSubscription;

  @override
  void registerSiteListController(Site site) {
    if (!Get.isRegistered<HomeListController>(tag: site.id)) {
      Get.put(HomeListController(site), tag: site.id);
    }
  }

  @override
  void unregisterSiteListController(Site site) {
    if (Get.isRegistered<HomeListController>(tag: site.id)) {
      Get.delete<HomeListController>(tag: site.id);
    }
  }

  @override
  void onInit() {
    streamSubscription = EventBus.instance.listen(
      EventBus.kBottomNavigationBarClicked,
      (index) {
        if (index == 0) {
          refreshOrScrollTop();
        }
      },
    );
    for (var site in Sites.visibleSites) {
      Get.put(HomeListController(site), tag: site.id);
    }
    listenSiteTabsChanged();
    super.onInit();
  }

  void refreshOrScrollTop() {
    var tabIndex = tabController.index;
    BasePageController controller;
    controller =
        Get.find<HomeListController>(tag: Sites.visibleSites[tabIndex].id);
    controller.scrollToTopOrRefresh();
  }

  void toSearch() {
    Get.toNamed(
      RoutePath.kSearch,
      arguments: {
        "siteId": Sites.visibleSites[tabController.index].id,
      },
    );
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    super.onClose();
  }
}
