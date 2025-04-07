import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class RemoteSyncWebDAVPage extends GetView<RemoteSyncWebDAVController> {
  const RemoteSyncWebDAVPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WebDAV同步"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          SettingsCard(
            child: Obx(
              () => Column(
                children: controller.notLogin.value
                    ? [
                        ListTile(
                          title: const Text("点击登录"),
                          leading: const Icon(Icons.login),
                          subtitle: const Text("登录后可以同步您的所有数据"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Get.toNamed(RoutePath.kRemoteSyncWebDavConfig);
                          },
                        ),
                      ]
                    : [
                        ListTile(
                          title: const Text("已登录"),
                          leading: const Icon(Icons.cloud_circle_outlined),
                          subtitle: Text(controller.user.value),
                          trailing: const Icon(Icons.logout),
                          onTap: () {
                            controller.onLogout();
                          },
                        ),
                        AppStyle.divider,
                        ListTile(
                          title: const Text("上传到云端"),
                          subtitle: Text("上次上传：${controller.lastUploadTime}"),
                          leading: const Icon(Icons.cloud_upload_outlined),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            controller.doWebDAVUpload();
                          },
                        ),
                        AppStyle.divider,
                        ListTile(
                          title: const Text("恢复到本地"),
                          subtitle: Text("上次恢复：${controller.lastRecoverTime}"),
                          leading: const Icon(Icons.cloud_download_outlined),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: showSetting,
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            controller.doWebDAVRecovery();
                          },
                          onLongPress: showSetting,
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showSetting() {
    Utils.showBottomSheet(
      title: '同步选项',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStyle.divider,
          Obx(
            () => CheckboxListTile(
              secondary: const Icon(Remix.heart_line),
              title: const Text("同步关注列表"),
              value: controller.isSyncFollows.value,
              controlAffinity: ListTileControlAffinity.trailing,
              onChanged: (value) => controller.changeIsSyncFollows(),
            ),
          ),
          AppStyle.divider,
          Obx(
            () => CheckboxListTile(
              secondary: const Icon(Icons.history),
              title: const Text("同步播放历史记录"),
              value: controller.isSyncHistories.value,
              controlAffinity: ListTileControlAffinity.trailing,
              onChanged: (value) => controller.changeIsSyncHistories(),
            ),
          ),
          AppStyle.divider,
          Obx(
            () => CheckboxListTile(
              secondary: const Icon(Remix.shield_keyhole_line),
              title: const Text("同步屏蔽字"),
              value: controller.isSyncBlockWord.value,
              controlAffinity: ListTileControlAffinity.trailing,
              onChanged: (value) => controller.changeIsSyncBlockWord(),
            ),
          ),
          AppStyle.divider,
          Obx(
            () => CheckboxListTile(
              secondary: const Icon(Remix.account_circle_line),
              title: const Text("同步哔哩哔哩账号"),
              value: controller.isSyncBilibiliAccount.value,
              controlAffinity: ListTileControlAffinity.trailing,
              onChanged: (value) => controller.changeIsSyncBilibiliAccount(),
            ),
          ),
          AppStyle.divider,
        ],
      ),
    );
  }
}
