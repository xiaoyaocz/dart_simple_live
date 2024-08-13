import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';

class SyncDataController extends BaseController {
  SyncClientRequest request = SyncClientRequest();

  void syncAll() async {
    try {
      var userName = AppSettingsController.instance.userName.value;
      var syncUrl = AppSettingsController.instance.syncUrl.value;
      // SmartDialog.showLoading(msg: "同步中...");
      var users = DBService.instance.getFollowList();
      var histores = DBService.instance.getHistores();
      var shieldList = AppSettingsController.instance.shieldList.toList();
      var bilibili = BiliBiliAccountService.instance.cookie;
      var jsonData = {
        'userData': users,
        'shieldListData': shieldList,
        'historesData': histores,
        'bilibiliData': bilibili,
      };
      var params = {
        "uuid": userName+"LiveData",
        "encrypted": jsonData
      };
      var parmsStr = json.encode(params);
      // SmartDialog.showToast("已同步");
      await request.syncAll(parmsStr,syncUrl);
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

}
