import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/tv_client_info_model.dart';
import 'package:simple_live_app/requests/tv_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';

import 'package:simple_live_app/services/tv_service.dart';

class TVSyncController extends BaseController {
  @override
  void onInit() {
    TVService.instance.refreshClients();
    super.onInit();
  }

  TextEditingController addressController = TextEditingController();

  TVClientRequest request = TVClientRequest();

  void connect() async {
    var address = addressController.text;
    if (address.isEmpty) {
      SmartDialog.showToast("请输入地址");
      return;
    }
    if (address.startsWith('http')) {
      var uri = Uri.tryParse(address);
      if (uri != null) {
        address = uri.host;
      }
    } else if (address.contains(':')) {
      var parts = address.split(":");
      address = parts.first;
    }

    var client = TVClinet(
      deviceIp: address,
      devicePort: TVService.httpPort,
      deviceName: "手动输入",
    );
    connectClient(client);
  }

  void connectClient(TVClinet client) async {
    try {
      SmartDialog.showLoading(msg: "连接中...");
      var info = await request.getClientInfo(client);
      showClientSheet(client, info);
    } catch (e) {
      SmartDialog.showToast("连接失败:$e");
    } finally {
      SmartDialog.dismiss();
    }
  }

  void showClientSheet(TVClinet client, TVClientInfoModel info) {
    Utils.showBottomSheet(
      title: info.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Remix.heart_line),
            title: const Text("同步关注列表"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              syncFollow(client);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("同步观看记录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              syncHistory(client);
            },
          ),
          ListTile(
            leading: const Icon(Remix.shield_keyhole_line),
            title: const Text("同步弹幕屏蔽词"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              syncBlockedWord(client);
            },
          ),
          ListTile(
            leading: const Icon(Remix.account_circle_line),
            title: const Text("同步哔哩哔哩账号"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              syncBlockedWord(client);
            },
          ),
        ],
      ),
    );
  }

  void syncFollow(TVClinet client) async {
    try {
      SmartDialog.showLoading(msg: "同步中...");
      var users = DBService.instance.getFollowList();
      var data = json.encode(users.map((e) => e.toJson()).toList());
      await request.syncFollow(client, data);
      SmartDialog.showToast("已同步关注列表");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncHistory(TVClinet client) async {
    try {
      SmartDialog.showLoading(msg: "同步中...");
      var histores = DBService.instance.getHistores();
      var data = json.encode(histores.map((e) => e.toJson()).toList());
      await request.syncHistory(client, data);
      SmartDialog.showToast("已同步历史记录");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBlockedWord(TVClinet client) async {
    try {
      SmartDialog.showLoading(msg: "同步中...");
      var shieldList = AppSettingsController.instance.shieldList;
      var data = json.encode(shieldList.toList());
      await request.syncBlockedWord(client, data);
      SmartDialog.showToast("已同步屏蔽词");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBiliAccount(TVClinet client) async {
    try {
      if (!BiliBiliAccountService.instance.logined.value) {
        SmartDialog.showToast("未登录哔哩哔哩");
        return;
      }
      SmartDialog.showLoading(msg: "同步中...");

      await request.syncBiliAccount(
          client, BiliBiliAccountService.instance.cookie);
      SmartDialog.showToast("已同步哔哩哔哩账号");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }
}
