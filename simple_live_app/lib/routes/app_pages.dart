// ignore_for_file: prefer_inlined_adds

import 'dart:io';

import 'package:get/get.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_controller.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_page.dart';
import 'package:simple_live_app/modules/indexed/indexed_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_controller.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_page.dart';
import 'package:simple_live_app/modules/settings/follow_settings_page.dart';
import 'package:simple_live_app/modules/sync/profile_backup/profile_backup_controller.dart';
import 'package:simple_live_app/modules/sync/profile_backup/profile_backup_page.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_config_page.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_page.dart';
import 'package:simple_live_app/modules/sync/sync_page.dart';
import 'package:simple_live_app/modules/sync/remote_sync/room/remote_sync_room_controller.dart';
import 'package:simple_live_app/modules/sync/remote_sync/room/remote_sync_room_page.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_page.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_controller.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_page.dart';
import 'package:simple_live_app/modules/sync/local_sync/scan_qr/sync_scan_qr_controller.dart';
import 'package:simple_live_app/modules/sync/local_sync/scan_qr/sync_scan_qr_page.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';
import 'package:simple_live_app/modules/mine/parse/parse_page.dart';
import 'package:simple_live_app/modules/sync/local_sync/local_sync_controller.dart';
import 'package:simple_live_app/modules/sync/local_sync/local_sync_page.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';
import 'package:simple_live_app/modules/mine/account/account_page.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/qr_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/qr_login_page.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/web_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/web_login_page.dart';
import 'package:simple_live_app/modules/mine/account/douyin/web_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/douyin/web_login_page.dart';
import 'package:simple_live_app/modules/mine/account/kuaishou/web_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/kuaishou/web_login_page.dart';
import 'package:simple_live_app/modules/settings/appstyle_setting_page.dart';
import 'package:simple_live_app/modules/settings/auto_exit_settings_page.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_page.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/modules/mine/history/history_controller.dart';
import 'package:simple_live_app/modules/mine/history/history_page.dart';
import 'package:simple_live_app/modules/settings/indexed_settings/indexed_settings_controller.dart';
import 'package:simple_live_app/modules/settings/indexed_settings/indexed_settings_page.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_page.dart';
import 'package:simple_live_app/modules/settings/multi_room_settings_page.dart';
import 'package:simple_live_app/modules/settings/playback_page_settings_page.dart';
import 'package:simple_live_app/modules/settings/play_settings_page.dart';

import '../modules/indexed/indexed_page.dart';
import 'app_navigation.dart';
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
        //BindingsBuilder.put(() => HomeController()),
      ],
    ),
    // 观看记录
    GetPage(
      name: RoutePath.kHistory,
      page: () => const HistoryPage(),
      bindings: [
        BindingsBuilder.put(() {
          final args = Get.arguments;
          return HistoryController(
            onRoomSelected: args is Map<String, dynamic>
                ? args["onRoomSelected"] as RoomSelectionCallback?
                : null,
          );
        }),
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
      page: () {
        final args = Get.arguments;
        final tag = args is Map ? args["controllerTag"] as String? : null;
        return CategoryDetailPage(tag: tag);
      },
      binding: BindingsBuilder(() {
        final args = Get.arguments;
        if (args is Map<String, dynamic>) {
          Get.put(
            CategoryDetailController(
            site: args["site"],
            subCategory: args["category"],
            onRoomSelected: args["onRoomSelected"] as RoomSelectionCallback?,
            excludedRoomId: args["excludedRoomId"] as String?,
            ),
            tag: args["controllerTag"] as String?,
          );
          return;
        }
        Get.put(
          CategoryDetailController(
            site: args[0],
            subCategory: args[1],
          ),
        );
      }),
    ),
    //直播间
    GetPage(
      name: RoutePath.kLiveRoomDetail,
      page: () => const LiveRoomPage(),
      transition: Platform.isIOS ? Transition.cupertino : null,
      popGesture: Platform.isIOS,
      binding: BindingsBuilder.put(() {
        final args = Get.arguments;
        final site = args is Map<String, dynamic> ? args["site"] : args;
        final initialCollapsed = args is Map<String, dynamic> &&
            args["initialDesktopSidePanelCollapsed"] == true;
        return LiveRoomController(
          pSite: site,
          pRoomId: Get.parameters["roomId"] ?? "",
          initialDesktopSidePanelCollapsed: initialCollapsed,
        );
      }),
    ),
    // 多开同屏
    GetPage(
      name: RoutePath.kMultiRoom,
      page: () => const MultiRoomPage(),
      binding: BindingsBuilder.put(
        () => MultiRoomController(
          (Get.arguments as List?)?.whereType<MultiRoomItem>().toList() ??
              const <MultiRoomItem>[],
        ),
      ),
    ),
    //弹幕设置
    GetPage(
      name: RoutePath.kSettingsDanmu,
      page: () => const DanmuSettingsPage(),
    ),
    //外观设置
    GetPage(
        name: RoutePath.kAppstyleSetting,
        page: () => const AppstyleSettingPage()),
    //播放设置
    GetPage(
      name: RoutePath.kSettingsPlay,
      page: () => const PlaySettingsPage(),
    ),
    //多开设置
    GetPage(
      name: RoutePath.kSettingsMultiRoom,
      page: () => const MultiRoomSettingsPage(),
    ),
    //自动关闭
    GetPage(
      name: RoutePath.kSettingsAutoExit,
      page: () => const AutoExitSettingsPage(),
    ),
    //工具箱
    GetPage(
      name: RoutePath.kTools,
      page: () => const ParsePage(),
      bindings: [
        BindingsBuilder.put(() => ParseController()),
      ],
    ),
    //关键词屏蔽
    GetPage(
      name: RoutePath.kSettingsDanmuShield,
      page: () => const DanmuShieldPage(),
      bindings: [
        BindingsBuilder.put(() => DanmuShieldController()),
      ],
    ),
    //主页设置
    GetPage(
      name: RoutePath.kSettingsIndexed,
      page: () => const IndexedSettingsPage(),
      bindings: [
        BindingsBuilder.put(() => IndexedSettingsController()),
      ],
    ),
    //播放页设置
    GetPage(
      name: RoutePath.kSettingsPlaybackPage,
      page: () => const PlaybackPageSettingsPage(),
      bindings: [
        BindingsBuilder.put(() => IndexedSettingsController()),
      ],
    ),
    //账号设置
    GetPage(
      name: RoutePath.kSettingsAccount,
      page: () => const AccountPage(),
      bindings: [
        BindingsBuilder.put(() => AccountController()),
      ],
    ),
    //哔哩哔哩Web登录
    GetPage(
      name: RoutePath.kBiliBiliWebLogin,
      page: () => const BiliBiliWebLoginPage(),
      bindings: [
        BindingsBuilder.put(() => BiliBiliWebLoginController()),
      ],
    ),
    //哔哩哔哩二维码登录
    GetPage(
      name: RoutePath.kBiliBiliQRLogin,
      page: () => const BiliBiliQRLoginPage(),
      bindings: [
        BindingsBuilder.put(() => BiliBiliQRLoginController()),
      ],
    ),
    //抖音Web登录
    GetPage(
      name: RoutePath.kDouyinWebLogin,
      page: () => const DouyinWebLoginPage(),
      bindings: [
        BindingsBuilder.put(() => DouyinWebLoginController()),
      ],
    ),
    //快手Web登录
    GetPage(
      name: RoutePath.kKuaishouWebLogin,
      page: () => const KuaishouWebLoginPage(),
      bindings: [
        BindingsBuilder.put(() => KuaishouWebLoginController()),
      ],
    ),
    // 数据同步
    GetPage(
      name: RoutePath.kSync,
      page: () => const SyncPage(),
    ),
    GetPage(
      name: RoutePath.kProfileBackup,
      page: () => const ProfileBackupPage(),
      bindings: [
        BindingsBuilder.put(() => ProfileBackupController()),
      ],
    ),
    // 本地同步
    GetPage(
      name: RoutePath.kLocalSync,
      page: () => const LocalSyncPage(),
      bindings: [
        BindingsBuilder.put(
          () => LocalSyncController(
            Get.arguments ?? "",
          ),
        ),
      ],
    ),
    //扫码
    GetPage(
      name: RoutePath.kSyncScan,
      page: () => const SyncScanQRPage(),
      bindings: [
        BindingsBuilder.put(() => SyncScanQRControlelr()),
      ],
    ),
    //同步设备
    GetPage(
      name: RoutePath.kLocalSyncDevice,
      page: () => const SyncDevicePage(),
      bindings: [
        BindingsBuilder.put(
          () => SyncDeviceController(
            client: Get.arguments['client'],
            info: Get.arguments['info'],
          ),
        ),
      ],
    ),
    //远程同步-房间
    GetPage(
      name: RoutePath.kRemoteSyncRoom,
      page: () => const RemoteSyncRoomPage(),
      bindings: [
        BindingsBuilder.put(
          () => RemoteSyncRoomController(Get.arguments ?? ""),
        ),
      ],
    ),
    //远程同步-WebDAV
    GetPage(
      name: RoutePath.kRemoteSyncWebDav,
      page: () => const RemoteSyncWebDAVPage(),
      bindings: [
        BindingsBuilder.put(
          () => RemoteSyncWebDAVController(),
        ),
      ],
    ),
    //远程同步-WebDAVConfig
    GetPage(
      name: RoutePath.kRemoteSyncWebDavConfig,
      page: () => const RemoteSyncWebDAVConfigPage(),
    ),
    //其他设置
    GetPage(
      name: RoutePath.kSettingsOther,
      page: () => const OtherSettingsPage(),
      bindings: [
        BindingsBuilder.put(() => OtherSettingsController()),
      ],
    ),
    //关注设置
    GetPage(
      name: RoutePath.kSettingsFollow,
      page: () => const FollowSettingsPage(),
    ),
  ];
}
