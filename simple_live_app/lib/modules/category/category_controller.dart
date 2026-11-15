import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';

class CategoryController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;

  /// 平台显隐变化时自增，触发页面用新 TabController 重建
  final RxInt sitesVersion = 0.obs;
  CategoryController() {
    tabController =
        TabController(length: Sites.visibleSites.length, vsync: this);
  }
  StreamSubscription<dynamic>? streamSubscription;
  StreamSubscription<dynamic>? _siteSettingsSubscription;
  var _knownSites = Sites.visibleSites;
  @override
  void onInit() {
    _knownSites = Sites.visibleSites;
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

    _siteSettingsSubscription = EventBus.instance.listen(
      EventBus.kUpdateSiteTabs,
      (_) => rebuildSites(),
    );

    super.onInit();
  }

  /// 平台显示开关变化后重建标签，无需重启
  void rebuildSites() {
    final sites = Sites.visibleSites;
    if (sites.isEmpty) {
      return;
    }
    // 记住当前平台，排序/显隐变化后仍停在同一个平台
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
      if (!Get.isRegistered<CategoryListController>(tag: site.id)) {
        Get.put(CategoryListController(site), tag: site.id);
      }
    }
    sitesVersion.value++;
  }

  String get currentSiteId {
    final sites = Sites.visibleSites;
    if (sites.isEmpty) {
      return Constant.kDouyin;
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
    _siteSettingsSubscription?.cancel();
    super.onClose();
  }
}
