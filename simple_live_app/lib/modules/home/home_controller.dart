import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;

  /// 平台显隐变化时自增，触发首页用新 TabController 重建
  final RxInt sitesVersion = 0.obs;
  var _knownSites = Sites.visibleSites;
  HomeController() {
    tabController = TabController(length: _knownSites.length, vsync: this);
  }

  StreamSubscription<dynamic>? streamSubscription;
  StreamSubscription<dynamic>? _siteSettingsSubscription;

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
    _siteSettingsSubscription = EventBus.instance.listen(
      EventBus.kUpdateCategorySites,
      (_) => rebuildSites(),
    );

    super.onInit();
  }

  /// 平台显示开关变化后重建首页标签，无需重启
  void rebuildSites() {
    final sites = Sites.visibleSites;
    if (sites.isEmpty) {
      return;
    }
    String? currentId;
    if (_knownSites.isNotEmpty) {
      final currentIndex = tabController.index.clamp(
        0,
        _knownSites.length - 1,
      );
      currentId = _knownSites[currentIndex].id;
    }
    var initialIndex = currentId == null
        ? 0
        : sites.indexWhere((site) => site.id == currentId);
    if (initialIndex < 0) {
      initialIndex = 0;
    }
    _knownSites = sites;
    final old = tabController;
    tabController = TabController(
      length: sites.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
    });
    for (final site in sites) {
      if (!Get.isRegistered<HomeListController>(tag: site.id)) {
        Get.put(HomeListController(site), tag: site.id);
      }
    }
    sitesVersion.value++;
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
    _siteSettingsSubscription?.cancel();
    super.onClose();
  }
}
