// ignore_for_file: prefer_inlined_adds

import 'package:get/get.dart';
import 'package:simple_live_tv_app/modules/account/bilibili/qr_login_controller.dart';
import 'package:simple_live_tv_app/modules/account/bilibili/qr_login_page.dart';
import 'package:simple_live_tv_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/modules/home/home_page.dart';
import 'package:simple_live_tv_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_tv_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_tv_app/modules/sync/sync_controller.dart';
import 'package:simple_live_tv_app/modules/sync/sync_page.dart';

import 'route_path.dart';

class AppPages {
  AppPages._();
  static final routes = [
    // 首页
    GetPage(
      name: RoutePath.kHome,
      page: () => const HomePage(),
      bindings: [
        BindingsBuilder.put(() => HomeController()),
      ],
    ),
    // 数据同步
    GetPage(
      name: RoutePath.kSync,
      page: () => const SyncPage(),
      bindings: [
        BindingsBuilder.put(() => SyncController()),
      ],
    ),

    // 关注
    GetPage(
      name: RoutePath.kFollow,
      page: () => const FollowUserPage(),
    ),

    //直播间
    GetPage(
      name: RoutePath.kLiveRoomDetail,
      page: () => const LiveRoomPage(),
      binding: BindingsBuilder.put(
        () => LiveRoomController(
          pSite: Get.arguments,
          pRoomId: Get.parameters["roomId"] ?? "",
        ),
      ),
    ),
    //哔哩哔哩二维码登录
    GetPage(
      name: RoutePath.kBiliBiliQRLogin,
      page: () => const BiliBiliQRLoginPage(),
      bindings: [
        BindingsBuilder.put(() => BiliBiliQRLoginController()),
      ],
    ),
  ];
}
