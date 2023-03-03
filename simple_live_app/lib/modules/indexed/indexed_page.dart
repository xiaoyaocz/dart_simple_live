import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';

import 'indexed_controller.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.index.value,
          children: controller.pages,
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.index.value,
          onDestinationSelected: controller.setIndex,
          height: 56,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [
            NavigationDestination(
              icon: Icon(Remix.home_smile_line),
              label: "首页",
            ),
            NavigationDestination(
              icon: Icon(Remix.heart_line),
              label: "关注",
            ),
            NavigationDestination(
              icon: Icon(Remix.apps_line),
              label: "分类",
            ),
            NavigationDestination(
              icon: Icon(Remix.user_smile_line),
              label: "我的",
            ),
          ],
        ),
      ),
      // bottomNavigationBar: Obx(
      //   () => BottomNavigationBar(
      //     currentIndex: controller.index.value,
      //     onTap: controller.setIndex,
      //     selectedFontSize: 12,
      //     unselectedFontSize: 12,
      //     iconSize: 24,
      //     type: BottomNavigationBarType.fixed,
      //     showSelectedLabels: true,
      //     showUnselectedLabels: true,
      //     elevation: 4,
      //     landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      //     items: const [
      //       BottomNavigationBarItem(
      //         icon: Icon(Remix.home_smile_line),
      //         activeIcon: Icon(Remix.home_smile_fill),
      //         label: "首页",
      //       ),
      //       BottomNavigationBarItem(
      //         icon: Icon(Remix.apps_line),
      //         activeIcon: Icon(Remix.apps_fill),
      //         label: "分类",
      //       ),
      //       BottomNavigationBarItem(
      //         icon: Icon(Remix.tools_line),
      //         activeIcon: Icon(Remix.tools_fill),
      //         label: "工具箱",
      //       ),
      //       BottomNavigationBarItem(
      //         icon: Icon(Remix.user_smile_line),
      //         activeIcon: Icon(Remix.user_smile_fill),
      //         label: "我的",
      //       ),
      //     ],
      //   ),
      // ),
    );
  }
}
