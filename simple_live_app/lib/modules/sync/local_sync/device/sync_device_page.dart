import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class SyncDevicePage extends GetView<SyncDeviceController> {
  const SyncDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("同步"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
        children: [
          SettingsCard(
            child: ListTile(
              leading: buildIcon(),
              title: Text(controller.info.name),
              subtitle: Text(
                  "${controller.info.type.toUpperCase()}   ${controller.client.address}:${controller.client.port}"),
            ),
          ),
          Obx(() {
            final status = controller.lastSyncStatus.value;
            if (status.isEmpty) return const SizedBox.shrink();
            final isErr = controller.lastSyncError.value;
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SettingsCard(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isErr ? Icons.error_outline : Icons.check_circle_outline,
                    color: isErr ? Colors.redAccent : Colors.green,
                  ),
                  title: Text(
                    status,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 16),
            child: Text(
              "发送本机数据到 ${controller.info.name}",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text("一键发送全部数据"),
              subtitle: const Text(
                "包含关注与标签、观看记录、弹幕屏蔽、哔哩哔哩与 WebDAV 账号",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.syncAll,
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 16),
            child: Text(
              "从 ${controller.info.name} 拉取数据到本机",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: ListTile(
              leading: const Icon(Remix.download_2_line),
              title: const Text("一键拉取全部数据"),
              subtitle: const Text(
                "包含关注与标签、观看记录、弹幕屏蔽、哔哩哔哩与 WebDAV 账号",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.pullAll,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIcon() {
    var icon = controller.info.type.toLowerCase();

    if (icon == "android") {
      return const Icon(Remix.android_line);
    } else if (icon == "ios") {
      return const Icon(Remix.apple_line);
    } else if (icon == "tv") {
      return const Icon(Remix.tv_2_line);
    } else if (icon == "windows") {
      return const Icon(Remix.microsoft_fill);
    } else if (icon == "macos") {
      return const Icon(Remix.mac_line);
    } else if (icon == "linux") {
      return const Icon(Remix.ubuntu_line);
    } else {
      return const Icon(Remix.device_line);
    }
  }
}
