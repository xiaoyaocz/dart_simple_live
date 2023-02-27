import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';

class CategoryController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  CategoryController() {
    tabController =
        TabController(length: Sites.supportSites.length, vsync: this);
  }

  @override
  void onInit() {
    for (var site in Sites.supportSites) {
      Get.put(CategoryListController(site), tag: site.id);
    }

    super.onInit();
  }
}
