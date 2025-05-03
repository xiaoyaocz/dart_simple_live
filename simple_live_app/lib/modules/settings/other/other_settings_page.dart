import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
            child: Padding(
              padding: AppStyle.edgeInsetsA4,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: controller.exportConfig,
                      label: const Text("导出配置"),
                      icon: const Icon(Remix.export_line),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: controller.importConfig,
                      label: const Text("导入配置"),
                      icon: const Icon(Remix.import_line),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: controller.resetDefaultConfig,
                      label: const Text("重置配置"),
                      icon: const Icon(Remix.restart_line),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "播放器高级设置",
              style: Get.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text.rich(
              TextSpan(
                text: "请勿随意修改以下设置，除非你知道自己在做什么。\n在修改以下设置前，你应该先查阅",
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () {
                        launchUrlString(
                            "https://mpv.io/manual/stable/#video-output-drivers");
                      },
                      child: const Text(
                        "MPV的文档",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    value:
                        AppSettingsController.instance.customPlayerOutput.value,
                    title: "自定义输出驱动与硬件加速",
                    onChanged: (e) {
                      AppSettingsController.instance.setCustomPlayerOutput(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsMenu(
                    title: "视频输出驱动(--vo)",
                    value:
                        AppSettingsController.instance.videoOutputDriver.value,
                    valueMap: controller.videoOutputDrivers,
                    onChanged: (e) {
                      AppSettingsController.instance.setVideoOutputDriver(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsMenu(
                    title: "音频输出驱动(--ao)",
                    value:
                        AppSettingsController.instance.audioOutputDriver.value,
                    valueMap: controller.audioOutputDrivers,
                    onChanged: (e) {
                      AppSettingsController.instance.setAudioOutputDriver(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsMenu(
                    title: "硬件解码器(--hwdec)",
                    value: AppSettingsController
                        .instance.videoHardwareDecoder.value,
                    valueMap: controller.hardwareDecoder,
                    onChanged: (e) {
                      AppSettingsController.instance.setVideoHardwareDecoder(e);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "日志记录",
              style: Get.textTheme.titleSmall,
            ),
          ),
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
              height: 300,
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
