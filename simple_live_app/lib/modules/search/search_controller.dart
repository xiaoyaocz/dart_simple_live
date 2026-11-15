import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';

class AppSearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;

  var searchMode = 0.obs;

  /// 平台显隐变化时自增，触发搜索页重建标签
  final RxInt sitesVersion = 0.obs;
  var _knownSites = Sites.visibleSites;

  AppSearchController() {
    final initialIndex = _resolveInitialIndex();
    index = initialIndex;
    tabController = TabController(
      length: _knownSites.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    if (_knownSites.isNotEmpty) {
      AppSettingsController.instance.setLastSearchSiteId(_knownSites[index].id);
    }
    _bindTabListener();
  }

  void _bindTabListener() {
    tabController.animation?.addListener(() {
      final currentIndex = (tabController.animation?.value ?? 0).round();
      if (index == currentIndex) {
        return;
      }
      final sites = Sites.visibleSites;
      if (sites.isEmpty) {
        return;
      }
      index = currentIndex.clamp(0, sites.length - 1);
      AppSettingsController.instance.setLastSearchSiteId(sites[index].id);
      final controller = Get.find<SearchListController>(tag: sites[index].id);

      if (controller.list.isEmpty &&
          !controller.pageEmpty.value &&
          controller.keyword.isNotEmpty) {
        controller.refreshData();
      }
    });
  }

  /// 平台显示开关变化后重建搜索标签，无需重启
  void rebuildSites() {
    final sites = Sites.visibleSites;
    if (sites.isEmpty) {
      return;
    }
    String? currentId;
    if (_knownSites.isNotEmpty) {
      currentId =
          _knownSites[tabController.index.clamp(0, _knownSites.length - 1)].id;
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
    index = initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
    });
    _bindTabListener();
    for (final site in sites) {
      if (!Get.isRegistered<SearchListController>(tag: site.id)) {
        Get.put(SearchListController(site), tag: site.id);
      }
    }
    AppSettingsController.instance.setLastSearchSiteId(sites[index].id);
    sitesVersion.value++;
  }

  StreamSubscription<dynamic>? streamSubscription;
  StreamSubscription<dynamic>? _siteSettingsSubscription;

  TextEditingController searchController = TextEditingController();

  int _resolveInitialIndex() {
    String? siteId;
    final args = Get.arguments;
    if (args is Map) {
      siteId = args["siteId"]?.toString();
    } else if (args is String) {
      siteId = args;
    }
    siteId ??= AppSettingsController.instance.lastSearchSiteId.value;
    final resolvedIndex =
        Sites.visibleSites.indexWhere((site) => site.id == siteId);
    return resolvedIndex < 0 ? 0 : resolvedIndex;
  }

  @override
  void onInit() {
    for (var site in Sites.visibleSites) {
      // if (site.id == Constant.kDouyin) {
      //   Get.put(DouyinSearchController(site));
      // } else {
      Get.put(
        SearchListController(site),
        tag: site.id,
      );
      //}
    }
    _siteSettingsSubscription = EventBus.instance.listen(
      EventBus.kUpdateCategorySites,
      (_) => rebuildSites(),
    );

    super.onInit();
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      return;
    }
    for (var site in Sites.visibleSites) {
      // if (site.id == Constant.kDouyin) {
      //   var controller = Get.find<DouyinSearchController>();
      //   controller.keyword = searchController.text;
      //   controller.searchMode.value = searchMode.value;
      //   controller.reloadWebView();
      // } else {
      var controller = Get.find<SearchListController>(tag: site.id);
      controller.clear();
      controller.keyword = searchController.text;
      controller.searchMode.value = searchMode.value;
      //}
    }
    // if (Sites.supportSites[index].id != Constant.kDouyin) {
    var controller =
        Get.find<SearchListController>(tag: Sites.visibleSites[index].id);
    controller.refreshData();
    //}
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    _siteSettingsSubscription?.cancel();
    super.onClose();
  }
}
