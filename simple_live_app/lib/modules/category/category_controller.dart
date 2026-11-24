import 'dart:async';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/site_tabs_mixin.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';

class CategoryController extends GetxController
    with GetSingleTickerProviderStateMixin, SiteTabsMixin {
  CategoryController() {
    initSiteTabs();
  }
  StreamSubscription<dynamic>? streamSubscription;

  @override
  void registerSiteListController(Site site) {
    if (!Get.isRegistered<CategoryListController>(tag: site.id)) {
      Get.put(CategoryListController(site), tag: site.id);
    }
  }

  @override
  void unregisterSiteListController(Site site) {
    if (Get.isRegistered<CategoryListController>(tag: site.id)) {
      Get.delete<CategoryListController>(tag: site.id);
    }
  }

  @override
  void onInit() {
    streamSubscription = EventBus.instance.listen(
      EventBus.kBottomNavigationBarClicked,
      (index) {
        if (index == 2) {
          refreshOrScrollTop();
        }
      },
    );
    for (var site in Sites.visibleSites) {
      Get.put(CategoryListController(site), tag: site.id);
    }
    listenSiteTabsChanged();

    super.onInit();
  }

  String get currentSiteId {
    final sites = Sites.visibleSites;
    if (sites.isEmpty) {
      // visibleSites 自带兜底，这里防御 supportSites 也异常的场景，按用户排序取首位
      final support = Sites.supportSites;
      return support.isEmpty ? Constant.kDouyin : support.first.id;
    }
    final index = tabController.index.clamp(0, sites.length - 1);
    return sites[index].id;
  }

  void refreshOrScrollTop() {
    var tabIndex = tabController.index;
    BasePageController controller;
    controller =
        Get.find<CategoryListController>(tag: Sites.visibleSites[tabIndex].id);
    controller.scrollToTopOrRefresh();
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    super.onClose();
  }
}
