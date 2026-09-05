import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/platform_utils.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

typedef RoomSelectionCallback = void Function(Site site, String roomId);

/// APP页面跳转封装
/// * 需要参数的页面都应使用此类
/// * 如不需要参数，可以使用Get.toNamed
class AppNavigator {
  static final Map<String, DateTime> _lastLiveRoomOpenAt = {};
  static int _categoryDetailRouteId = 0;

  static String _nextCategoryDetailTag() {
    _categoryDetailRouteId += 1;
    return "category-detail-$_categoryDetailRouteId";
  }

  /// 跳转至观看记录
  static Future<dynamic> toHistory({
    RoomSelectionCallback? onRoomSelected,
  }) {
    return Get.toNamed(
          RoutePath.kHistory,
          arguments: onRoomSelected == null
              ? null
              : {
                  "onRoomSelected": onRoomSelected,
                },
        ) ??
        Future.value();
  }

  /// 跳转至分类详情
  static void toCategoryDetail(
      {required Site site,
      required LiveSubCategory category,
      RoomSelectionCallback? onRoomSelected,
      String? excludedRoomId}) {
    Get.toNamed(
      RoutePath.kCategoryDetail,
      preventDuplicates: false,
      arguments: {
        "site": site,
        "category": category,
        "controllerTag": _nextCategoryDetailTag(),
        if (onRoomSelected != null) "onRoomSelected": onRoomSelected,
        if (excludedRoomId != null) "excludedRoomId": excludedRoomId,
      },
    );
  }

  /// 跳转至直播间
  static void toLiveRoomDetail({
    required Site site,
    required String roomId,
    bool initialDesktopSidePanelCollapsed = false,
  }) async {
    final roomKey = "${site.id}_$roomId";
    final lastOpenAt = _lastLiveRoomOpenAt[roomKey];
    final now = DateTime.now();
    if (lastOpenAt != null &&
        now.difference(lastOpenAt) < const Duration(milliseconds: 1500)) {
      SmartDialog.showToast("正在打开直播间，请稍候");
      return;
    }
    _lastLiveRoomOpenAt[roomKey] = now;

    if (site.id == Constant.kBiliBili &&
        !BiliBiliAccountService.instance.logined.value &&
        AppSettingsController.instance.bilibiliLoginTip.value) {
      var result = await Utils.showAlertDialog(
        "哔哩哔哩需要登录才能观看高清直播，是否前往登录？",
        title: "登录哔哩哔哩",
        actions: [
          TextButton(
            onPressed: () {
              AppSettingsController.instance.setBiliBiliLoginTip(false);
              Get.back(result: false);
            },
            child: const Text("不再提示"),
          ),
        ],
      );
      if (result == true) {
        await toBiliBiliLogin();
        if (!BiliBiliAccountService.instance.logined.value) {
          SmartDialog.showToast("未完成登录");
        }
      }
    }

    Get.toNamed(
      RoutePath.kLiveRoomDetail,
      arguments: {
        "site": site,
        "initialDesktopSidePanelCollapsed": initialDesktopSidePanelCollapsed,
      },
      parameters: {
        "roomId": roomId,
      },
    );
  }

  static Future<dynamic> toMultiRoom(List<MultiRoomItem> rooms) {
    if (!PlatformUtils.supportsInlineMultiRoom) {
      SmartDialog.showToast("当前移动端版本已关闭多开同屏");
      return Future.value();
    }
    return Get.toNamed(
          RoutePath.kMultiRoom,
          arguments: rooms,
        ) ??
        Future.value();
  }

  /// 跳转至哔哩哔哩登录
  static Future toBiliBiliLogin() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Get.toNamed(RoutePath.kBiliBiliWebLogin);
    } else {
      await Get.toNamed(RoutePath.kBiliBiliQRLogin);
    }
  }

  /// 跳转至同步设备
  static Future toSyncDevice(
      SyncClinet client, SyncClientInfoModel info) async {
    await Get.toNamed(
      RoutePath.kLocalSyncDevice,
      arguments: {
        "client": client,
        "info": info,
      },
    );
  }
}
