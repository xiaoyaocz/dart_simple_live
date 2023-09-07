import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';

import 'indexed_controller.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return Scaffold(
          body: Row(
            children: [
              Visibility(
                visible: orientation == Orientation.landscape,
                child: Obx(
                  () => NavigationRail(
                    selectedIndex: controller.index.value,
                    onDestinationSelected: controller.setIndex,
                    labelType: NavigationRailLabelType.none,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Remix.home_smile_line),
                        selectedIcon: Icon(Remix.home_smile_fill),
                        label: Text("首页"),
                        padding: AppStyle.edgeInsetsV8,
                      ),
                      NavigationRailDestination(
                        icon: Icon(Remix.heart_line),
                        selectedIcon: Icon(Remix.heart_fill),
                        label: Text("关注"),
                        padding: AppStyle.edgeInsetsV8,
                      ),
                      NavigationRailDestination(
                        icon: Icon(Remix.apps_line),
                        selectedIcon: Icon(Remix.apps_fill),
                        label: Text("分类"),
                        padding: AppStyle.edgeInsetsV8,
                      ),
                      NavigationRailDestination(
                        icon: Icon(Remix.user_smile_line),
                        selectedIcon: Icon(Remix.user_smile_fill),
                        label: Text("我的"),
                        padding: AppStyle.edgeInsetsV8,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.grey.withOpacity(.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: IndexedStack(
                      index: controller.index.value,
                      children: controller.pages,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Visibility(
            visible: orientation == Orientation.portrait,
            child: Obx(
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
          ),
        );
      },
    );
  }
}
