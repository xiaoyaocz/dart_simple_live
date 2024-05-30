import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/user/other/other_settings_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class OtherSettingsPage extends GetView<OtherSettingsController> {
  const OtherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("其他设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: AppSettingsController.instance.logEnable.value,
                    title: "开启日志记录",
                    subtitle: "开启后将记录调试日志，可以将日志文件提供给开发者用于排查问题",
                    onChanged: controller.setLogEnable,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: AppStyle.edgeInsetsL12,
            visualDensity: VisualDensity.compact,
            title: Text(
              "日志列表",
              style: Get.textTheme.titleSmall,
            ),
            trailing: TextButton.icon(
              onPressed: () {
                controller.cleanLog();
              },
              label: const Text("清空日志"),
              icon: const Icon(Icons.clear_all),
            ),
          ),
          SettingsCard(
            child: SizedBox(
              height: 200,
              child: Obx(
                () => ListView.separated(
                  itemCount: controller.logFiles.length,
                  separatorBuilder: (context, index) => AppStyle.divider,
                  itemBuilder: (context, index) {
                    var item = controller.logFiles[index];
                    return ListTile(
                      visualDensity: VisualDensity.compact,
                      contentPadding: AppStyle.edgeInsetsL12.copyWith(right: 4),
                      title: Text(item.name),
                      subtitle: Text(Utils.parseFileSize(item.size)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!Platform.isLinux)
                            IconButton(
                              onPressed: () {
                                controller.shareLogFile(item);
                              },
                              icon: const Icon(Icons.share),
                            ),
                          IconButton(
                            onPressed: () {
                              controller.saveLogFile(item);
                            },
                            icon: const Icon(Icons.save),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
