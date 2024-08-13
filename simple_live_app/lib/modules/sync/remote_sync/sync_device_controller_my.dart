import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncDeviceControllerMy extends BaseController {
  final SyncClinet client;
  final SyncClientInfoModel info;
  SyncDeviceControllerMy({required this.client, required this.info});
  SyncClientRequest request = SyncClientRequest();

  Future<bool> showOverlayDialog() async {
    var overlay = await Utils.showAlertDialog(
      "是否覆盖远端数据？",
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  void syncFollow({
    var dataStr = "",
    bool isOverlay = true,
  }) async {
    try {
      var overlay = isOverlay?await showOverlayDialog():isOverlay;
      if(isOverlay){
        SmartDialog.showLoading(msg: "同步中...");
      }
      var users = DBService.instance.getFollowList();
      var data = ""==dataStr?json.encode(users.map((e) => e.toJson()).toList()):json.encode(dataStr);
      await request.syncFollow(client, data, overlay: overlay);
      if(isOverlay) {
        SmartDialog.showToast("已同步关注列表");
      }
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncHistory({
    var dataStr = "",
    bool isOverlay = true,
  }) async {
    try {
      var overlay = isOverlay?await showOverlayDialog():isOverlay;
      if(isOverlay) {
        SmartDialog.showLoading(msg: "同步中...");
      }
      var histores = DBService.instance.getHistores();
      var data = ""==dataStr?json.encode(histores.map((e) => e.toJson()).toList()):json.encode(dataStr);
      await request.syncHistory(client, data, overlay: overlay);
      if(isOverlay) {
        SmartDialog.showToast("已同步历史记录");
      }
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBlockedWord({
    var dataStr = "",
    bool isOverlay = true,
  }) async {
    try {
      var overlay = isOverlay?await showOverlayDialog():isOverlay;
      if(isOverlay) {
        SmartDialog.showLoading(msg: "同步中...");
      }
      var shieldList = AppSettingsController.instance.shieldList;
      var data =""==dataStr? json.encode(shieldList.toList()):json.encode(dataStr);
      await request.syncBlockedWord(client, data, overlay: overlay);
      if(isOverlay) {
        SmartDialog.showToast("已同步屏蔽词");
      }
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBiliAccount({
    String dataStr = "",
    bool isOverlay = true,
  }) async {
    try {
      if (!BiliBiliAccountService.instance.logined.value) {
        if(isOverlay){
          SmartDialog.showToast("未登录哔哩哔哩");
        }
        return;
      }
      if(isOverlay) {
        SmartDialog.showLoading(msg: "同步中...");
      }
      var bilibili = ""==dataStr?BiliBiliAccountService.instance.cookie:dataStr;
      await request.syncBiliAccount(
          client, bilibili);
      if(isOverlay) {
        SmartDialog.showToast("已同步哔哩哔哩账号");
      }
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }
}
