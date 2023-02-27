import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';

class SearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  SearchController() {
    tabController =
        TabController(length: Sites.supportSites.length, vsync: this);
    tabController.animation?.addListener(() {
      var currentIndex = (tabController.animation?.value ?? 0).round();
      if (index == currentIndex) {
        return;
      }

      index = currentIndex;
      var controller =
          Get.find<SearchListController>(tag: Sites.supportSites[index].id);

      if (controller.list.isEmpty &&
          !controller.pageEmpty.value &&
          controller.keyword.isNotEmpty) {
        controller.refreshData();
      }
    });
  }

  StreamSubscription<dynamic>? streamSubscription;

  TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    for (var site in Sites.supportSites) {
      Get.put(
        SearchListController(site),
        tag: site.id,
      );
    }

    super.onInit();
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      return;
    }
    for (var site in Sites.supportSites) {
      var controller = Get.find<SearchListController>(tag: site.id);
      controller.clear();
      controller.keyword = searchController.text;
    }
    var controller =
        Get.find<SearchListController>(tag: Sites.supportSites[index].id);
    controller.refreshData();
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    super.onClose();
  }
}
