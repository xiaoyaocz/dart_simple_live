import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/sync/profile_backup/profile_backup_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class ProfileBackupPage extends GetView<ProfileBackupController> {
  const ProfileBackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("配置包"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "跨平台迁移",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Remix.download_2_line),
                  title: const Text("导出配置包"),
                  subtitle: const Text("包含设置、关注、历史、屏蔽词、屏蔽用户和预设"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.exportProfile,
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.upload_2_line),
                  title: const Text("导入配置包"),
                  subtitle: const Text("支持合并或覆盖，不导入 WebDAV 密码"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.importProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
