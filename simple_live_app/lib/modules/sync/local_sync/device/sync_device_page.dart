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
                  "${controller.info.type.toUpperCase()}   ${controller.info.address}"),
            ),
          ),
          AppStyle.vGap12,
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Remix.heart_line),
                  title: const Text("同步关注列表"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncFollowAndTag();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text("同步观看记录"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncHistory();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.shield_keyhole_line),
                  title: const Text("同步弹幕屏蔽词"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncBlockedWord();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.account_circle_line),
                  title: const Text("同步哔哩哔哩账号"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncBiliAccount();
                  },
                ),
              ],
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
