// ignore_for_file: prefer_inlined_adds

import 'package:get/get.dart';
import 'package:simple_live_app/modules/categoty_detail/category_detail_controller.dart';
import 'package:simple_live_app/modules/categoty_detail/category_detail_page.dart';
import 'package:simple_live_app/modules/home/home_controller.dart';
import 'package:simple_live_app/modules/indexed/indexed_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_page.dart';
import 'package:simple_live_app/modules/toolbox/toolbox_controller.dart';
import 'package:simple_live_app/modules/toolbox/toolbox_page.dart';
import 'package:simple_live_app/modules/user/auto_exit_settings_page.dart';
import 'package:simple_live_app/modules/user/danmu_settings_page.dart';
import 'package:simple_live_app/modules/user/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/user/follow_user/follow_user_page.dart';
import 'package:simple_live_app/modules/user/history/history_controller.dart';
import 'package:simple_live_app/modules/user/history/history_page.dart';
import 'package:simple_live_app/modules/user/play_settings_page.dart';

import '../modules/indexed/indexed_page.dart';
import 'route_path.dart';

class AppPages {
  AppPages._();
  static final routes = [
    // 首页
    GetPage(
      name: RoutePath.kIndex,
      page: () => const IndexedPage(),
      bindings: [
        BindingsBuilder.put(() => IndexedController()),
        BindingsBuilder.put(() => HomeController()),
      ],
    ),
    // 观看记录
    GetPage(
      name: RoutePath.kHistory,
      page: () => const HistoryPage(),
      bindings: [
        BindingsBuilder.put(() => HistoryController()),
      ],
    ),
    // 关注用户
    GetPage(
      name: RoutePath.kFollowUser,
      page: () => const FollowUserPage(),
      bindings: [
        BindingsBuilder.put(() => FollowUserController()),
      ],
    ),
    // 搜索
    GetPage(
      name: RoutePath.kSearch,
      page: () => const SearchPage(),
      bindings: [
        BindingsBuilder.put(() => AppSearchController()),
      ],
    ),
    //分类详情
    GetPage(
      name: RoutePath.kCategoryDetail,
      page: () => const CategoryDetailPage(),
      binding: BindingsBuilder.put(
        () => CategoryDetailController(
          site: Get.arguments[0],
          subCategory: Get.arguments[1],
        ),
      ),
    ),
    //直播间
    GetPage(
      name: RoutePath.kLiveRoomDetail,
      page: () => const LiveRoomPage(),
      binding: BindingsBuilder.put(
        () => LiveRoomController(
          site: Get.arguments,
          roomId: Get.parameters["roomId"] ?? "",
        ),
      ),
    ),
    //弹幕设置
    GetPage(
      name: RoutePath.kSettingsDanmu,
      page: () => const DanmuSettingsPage(),
    ),
    //播放设置
    GetPage(
      name: RoutePath.kSettingsPlay,
      page: () => const PlaySettingsPage(),
    ),
    //播放设置
    GetPage(
      name: RoutePath.kSettingsAutoExit,
      page: () => const AutoExitSettingsPage(),
    ),
    //工具箱
    GetPage(
      name: RoutePath.kTools,
      page: () => const ToolBoxPage(),
      bindings: [
        BindingsBuilder.put(() => ToolBoxController()),
      ],
    ),
  ];
}
