import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/modules/home/home_page.dart';

class IndexedController extends GetxController
    with GetTickerProviderStateMixin {
  final AppFocusNode userFocusNode = AppFocusNode();
  final AppFocusNode searchFocusNode = AppFocusNode();
  final AppFocusNode settingsFocusNode = AppFocusNode();
  final List<HomePageItem> items = [
    HomePageItem(
      iconData: Remix.home_smile_line,
      name: "首页",
      index: 0,
    ),
    HomePageItem(
      iconData: Remix.heart_line,
      name: "关注",
      index: 1,
    ),
    HomePageItem(
      iconData: Remix.apps_line,
      name: "分类",
      index: 2,
    ),
  ];

  final RxInt currentIndex = 0.obs;

  RxList<Widget> pages = RxList<Widget>([
    const HomePage(),
    const SizedBox(),
    const SizedBox(),
  ]);

  void setIndex(int i) {
    if (pages[i] is SizedBox) {
      switch (items[i].index) {
        case 0:
          Get.put(HomeController());
          pages[i] = const HomePage();
          break;
        case 1:
          // Get.put(FollowUserController());
          // pages[i] = const FollowUserPage();
          break;
        case 2:
          //Get.put(CategoryController());
          // pages[i] = const CategoryPage();
          break;

        default:
      }
    }

    currentIndex.value = i;
  }
}

class HomePageItem {
  final String name;
  final IconData iconData;
  final int index;
  AppFocusNode appFocusNode = AppFocusNode();
  HomePageItem({
    required this.name,
    required this.iconData,
    required this.index,
  });
}
