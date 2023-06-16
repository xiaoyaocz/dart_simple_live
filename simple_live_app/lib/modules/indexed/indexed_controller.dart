import 'package:flutter/widgets.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/category/category_controller.dart';
import 'package:simple_live_app/modules/category/category_page.dart';
import 'package:simple_live_app/modules/home/home_page.dart';
import 'package:simple_live_app/modules/user/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/user/follow_user/follow_user_page.dart';
import 'package:simple_live_app/modules/user/user_page.dart';

class IndexedController extends GetxController {
  var index = 0.obs;
  RxList<Widget> pages = RxList<Widget>([
    const HomePage(),
    const SizedBox(),
    const SizedBox(),
    const SizedBox(),
  ]);

  void setIndex(i) {
    if (pages[i] is SizedBox) {
      switch (i) {
        case 1:
          Get.put(FollowUserController());
          pages[i] = const FollowUserPage();
          break;
        case 2:
          Get.put(CategoryController());
          pages[i] = const CategoryPage();
          break;

        case 3:
          pages[i] = const UserPage();
          break;
        default:
      }
    }

    index.value = i;
  }

  @override
  void onInit() {
    Future.delayed(Duration.zero, showFirstRun);
    super.onInit();
  }

  void showFirstRun() async {
    var settingsController = Get.find<AppSettingsController>();
    if (settingsController.firstRun) {
      settingsController.setNoFirstRun();
      await Utils.showStatement();
      Utils.checkUpdate();
    } else {
      Utils.checkUpdate();
    }
  }
}
