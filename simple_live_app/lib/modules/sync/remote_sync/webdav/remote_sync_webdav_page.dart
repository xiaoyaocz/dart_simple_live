import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
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
                children: [
                  Visibility(
                    visible: controller.notLogin.value,
                    child: ListTile(
                      title: const Text("点击登录"),
                      leading: const Icon(Icons.login),
                      subtitle: const Text("登录后可以同步您的所有数据"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Get.toNamed(RoutePath.kRemoteSyncWebDavConfig);
                      },
                    ),
                  ),
                  Visibility(
                    visible: !controller.notLogin.value,
                    child: ListTile(
                      title: const Text("已登录"),
                      leading: const Icon(Icons.cloud_circle_outlined),
                      subtitle: Text(controller.user.value),
                      trailing: const Icon(Icons.logout),
                      onTap: () {
                        controller.doWebDAVLogout();
                      },
                    ),
                  ),
                  Visibility(
                    visible: !controller.notLogin.value,
                    child: ListTile(
                      title: const Text("上传到云端"),
                      subtitle: const Text("同步"),
                      leading: const Icon(Icons.cloud_upload_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        controller.doWebDAVUpload();
                      },
                    ),
                  ),
                  Visibility(
                    visible: !controller.notLogin.value,
                    child: controller.isExpanded.value
                        ? ExpansionTile(
                            title: const Text("恢复到本地"),
                            subtitle: const Text("选择您要同步的数据"),
                            leading: const Icon(Icons.cloud_download_outlined),
                            initiallyExpanded: controller.isExpanded.value,
                            onExpansionChanged: (bool expanded) {
                              controller.isExpanded.value = expanded;
                            },
                            children: [
                              AppStyle.divider,
                              ListTile(
                                leading: const Icon(Remix.heart_line),
                                title: const Text("同步关注列表"),
                                trailing: Icon(controller.isSyncFollows.value
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank),
                                onTap: () {
                                  controller.changeIsSyncFollows();
                                },
                              ),
                              AppStyle.divider,
                              ListTile(
                                leading: const Icon(Icons.history),
                                title: const Text("同步播放历史记录"),
                                trailing: Icon(controller.isSyncHistories.value
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank),
                                onTap: () {
                                  controller.changeIsSyncHistories();
                                },
                              ),
                              AppStyle.divider,
                              ListTile(
                                leading: const Icon(Remix.shield_keyhole_line),
                                title: const Text("同步屏蔽字"),
                                trailing: Icon(controller.isSyncBlockWord.value
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank),
                                onTap: () {
                                  controller.changeIsSyncBlockWord();
                                },
                              ),
                              AppStyle.divider,
                              ListTile(
                                leading: const Icon(Remix.account_circle_line),
                                title: const Text("同步哔哩哔哩账号"),
                                trailing: Icon(
                                    controller.isSyncBilibiliAccount.value
                                        ? Icons.check_box_outlined
                                        : Icons.check_box_outline_blank),
                                onTap: () {
                                  controller.changeIsSyncBilibiliAccount();
                                },
                              ),
                              AppStyle.divider,
                              ElevatedButton(
                                onPressed: () {
                                  controller.changeExpanded();
                                },
                                child: const Text("确认选择"),
                              ),
                            ],
                          )
                        : ListTile(
                            title: const Text("恢复到本地"),
                            subtitle: const Text("长按弹出同步数据种类选项"),
                            leading: const Icon(Icons.cloud_download_outlined),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              controller.doWebDAVRecovery();
                            },
                            onLongPress: (){
                              controller.changeExpanded();
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
