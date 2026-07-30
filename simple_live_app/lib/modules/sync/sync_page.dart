import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("数据同步"),
        actions: [
          Visibility(
            visible: GetPlatform.isAndroid || GetPlatform.isIOS,
            child: TextButton.icon(
              onPressed: () async {
                var result = await Get.toNamed(RoutePath.kSyncScan);
                if (result == null || result.isEmpty) {
                  return;
                }
                if (result.length == SignalRService.kRoomIdLength) {
                  Get.toNamed(RoutePath.kRemoteSyncRoom, arguments: result);
                } else {
                  Get.toNamed(RoutePath.kLocalSync, arguments: result);
                }
              },
              icon: const Icon(Remix.qr_scan_line),
              label: const Text("扫一扫"),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "远程同步",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: ListTile(
              leading: const Icon(Remix.cloud_line),
              title: Text("当前服务：${SignalRService.configuredServerLabel}"),
              subtitle: Text(
                "${SignalRService.configuredUrl}\n"
                "两台设备必须选择相同服务；自建服务器与 Cloudflare 的房间不互通。",
              ),
            ),
          ),
          AppStyle.vGap12,
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text("配置包导入导出"),
                  leading: const Icon(Remix.file_transfer_line),
                  subtitle: const Text("跨平台迁移设置、关注、历史和屏蔽数据"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kProfileBackup);
                  },
                ),
                AppStyle.divider,
                ListTile(
                  title: const Text("创建房间"),
                  leading: const Icon(Remix.home_wifi_line),
                  subtitle: const Text("其他设备可以通过房间号加入"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kRemoteSyncRoom);
                  },
                ),
                AppStyle.divider,
                ListTile(
                  title: const Text("加入房间"),
                  leading: const Icon(Remix.add_circle_line),
                  subtitle: const Text("加入其他设备创建的房间"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    var input = await Utils.showEditTextDialog(
                      "",
                      title: "加入房间",
                      hintText: "请输入房间号,不区分大小写",
                      validate: (text) {
                        if (text.isEmpty) {
                          SmartDialog.showToast("房间号不能为空");
                          return false;
                        }
                        if (text.trim().length !=
                            SignalRService.kRoomIdLength) {
                          SmartDialog.showToast(
                              "请输入${SignalRService.kRoomIdLength}位房间号");
                          return false;
                        }
                        return true;
                      },
                    );
                    if (input != null && input.isNotEmpty) {
                      Get.toNamed(RoutePath.kRemoteSyncRoom,
                          arguments: input.trim().toUpperCase());
                    }
                  },
                ),
                AppStyle.divider,
                ListTile(
                  title: const Text("WebDAV"),
                  leading: const Icon(Icons.cloud_upload_outlined),
                  subtitle: const Text("通过WebDAV同步数据"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kRemoteSyncWebDav);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "局域网同步",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text("局域网同步"),
                  subtitle: const Text("在局域网内同步数据"),
                  leading: const Icon(Remix.device_line),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kLocalSync);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
