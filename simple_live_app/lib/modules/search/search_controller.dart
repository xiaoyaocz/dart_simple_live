import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/site_tabs_mixin.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';

class AppSearchController extends GetxController
    with GetSingleTickerProviderStateMixin, SiteTabsMixin {
  int index = 0;

  var searchMode = 0.obs;

  AppSearchController() {
    final initialIndex = _resolveInitialIndex();
    index = initialIndex;
    initSiteTabs(initialIndex: initialIndex);
    if (Sites.visibleSites.isNotEmpty) {
      AppSettingsController.instance.setLastSearchSiteId(
        Sites.visibleSites[index].id,
      );
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

  @override
  void registerSiteListController(Site site) {
    if (!Get.isRegistered<SearchListController>(tag: site.id)) {
      Get.put(SearchListController(site), tag: site.id);
    }
  }

  @override
  void unregisterSiteListController(Site site) {
    if (Get.isRegistered<SearchListController>(tag: site.id)) {
      Get.delete<SearchListController>(tag: site.id);
    }
  }

  @override
  void onSiteTabsRebuilt(int initialIndex) {
    index = initialIndex;
    _bindTabListener();
    AppSettingsController.instance.setLastSearchSiteId(
      Sites.visibleSites[initialIndex].id,
    );
  }

  StreamSubscription<dynamic>? streamSubscription;

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
    listenSiteTabsChanged();

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
    super.onClose();
  }
}
