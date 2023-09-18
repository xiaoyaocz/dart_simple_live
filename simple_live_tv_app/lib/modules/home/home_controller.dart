import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/home/home_list_controller.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  var tabIndex = 0.obs;
  HomeController() {
    tabController =
        TabController(length: Sites.supportSites.length, vsync: this);
  }

  @override
  void onInit() {
    for (var site in Sites.supportSites) {
      Get.put(HomeListController(site), tag: site.id);
    }
    tabController.addListener(() {
      tabIndex.value = tabController.index;
    });
    super.onInit();
  }

  void refreshOrScrollTop() {
    var tabIndex = tabController.index;
    BasePageController controller;
    controller =
        Get.find<HomeListController>(tag: Sites.supportSites[tabIndex].id);
    controller.scrollToTopOrRefresh();
  }
}
