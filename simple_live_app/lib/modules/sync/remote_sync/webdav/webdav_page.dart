import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_controller.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class WebdavSyncPage extends GetView<WebDAVController> {
  const WebdavSyncPage({super.key});

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
            child: Column(
              children: [
                Obx(
                  () => ListTile(
                    title: controller.webdavAct.isNotEmpty
                        ? const Text("已登录")
                        : const Text("点击登录"),
                    leading: controller.webdavAct.isNotEmpty
                        ? const Icon(Icons.logout)
                        : const Icon(Icons.login),
                    subtitle: controller.webdavAct.isNotEmpty
                        ? const Text("点击注销")
                        : const Text("登录后可以同步关注列表"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      if (controller.webdavAct.isNotEmpty) {
                        var result = await Utils.showAlertDialog(
                            "确定要注销已登录的WebDAV账号吗？下次需要重新登录",
                            title: "退出登录");
                        if (result) {
                          // 删除webdav账号信息
                          controller.deleteWebDAVAccount();
                          SmartDialog.showToast("已退出登录");
                          Get.back();
                        }
                      } else {
                        // 登录webdav账号
                        var act = await Utils.showEditTextDialog(
                          "",
                          title: "请输入账户",
                          hintText: "请输入账户",
                        );
                        if (act == null || act.isEmpty) {
                          return;
                        }
                        controller.setActInfo(act);
                        var psd = await Utils.showEditTextDialog(
                          "",
                          title: "请输入密码",
                          hintText: "请输入密码",
                        );
                        if (psd == null || psd.isEmpty) {
                          return;
                        }
                        controller.setPsdInfo(psd);
                        var link = await Utils.showEditTextDialog(
                          "",
                          title: "请输入服务器地址",
                          hintText: "请输入服务器地址",
                        );
                        if (link == null || link.isEmpty) {
                          return;
                        }
                        controller.setLinkInfo(link);
                        SmartDialog.showToast("WebDAV信息已保存！");
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text("同步到WebDAV"),
                  subtitle: const Text("仅同步关注列表，会覆盖云端的数据，建议先下载再上传"),
                  leading: const Icon(Remix.device_line),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.sendFavoritesToWebDAV();
                  },
                ),
                ListTile(
                  title: const Text("从WebDAV同步"),
                  leading: const Icon(Remix.heart_line),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.getFavoritesFromWebDAV();
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
