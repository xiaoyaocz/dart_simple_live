import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
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
        padding: AppStyle.pagePadding(),
        children: [
          SettingsCard(
            child: Padding(
              padding: AppStyle.edgeInsetsA4,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: controller.exportConfig,
                      label: const Text("导出配置包"),
                      icon: const Icon(Remix.export_line),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: controller.importConfig,
                      label: const Text("导入配置包"),
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
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
              child: Text(
                "桌面窗口",
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Obx(
                () => SettingsSwitch(
                  value: AppSettingsController
                      .instance.rememberWindowPlacement.value,
                  title: "记住窗口大小和位置",
                  subtitle: "开启后恢复上次普通窗口位置和最大化状态",
                  onChanged:
                      AppSettingsController.instance.setRememberWindowPlacement,
                ),
              ),
            ),
            if (Platform.isWindows) ...[
              Padding(
                padding: AppStyle.edgeInsetsA12.copyWith(top: 16),
                child: Text(
                  "图形处理器",
                  style: Get.textTheme.titleSmall,
                ),
              ),
              SettingsCard(
                child: Obx(
                  () => SettingsMenu<String>(
                    title: "Windows GPU 偏好",
                    subtitle: "选择高性能/NVIDIA 可减少游戏本误用核显；修改后必须完全重启应用",
                    value: AppSettingsController
                        .instance.windowsGpuPreference.value,
                    valueMap: AppSettingsController.windowsGpuPreferenceOptions,
                    onChanged: (value) {
                      AppSettingsController.instance
                          .setWindowsGpuPreference(value);
                      SmartDialog.showToast("GPU 偏好已保存，重启应用后生效");
                    },
                  ),
                ),
              ),
            ],
          ],
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
                  () => SettingsMenu(
                    title: Platform.isIOS ? "mpv 性能档位（桌面端）" : "mpv 性能档位",
                    subtitle: Platform.isIOS
                        ? "iOS 仅使用其中的自动硬解设置，不影响画质与功耗"
                        : "流畅适合核显/低功耗，均衡为默认，画质适合高性能显卡",
                    value: AppSettingsController.instance.mpvProfile.value,
                    valueMap: MpvOptionsService.profileLabels,
                    onChanged: (e) {
                      AppSettingsController.instance.setMpvProfile(e);
                    },
                  ),
                ),
                AppStyle.divider,
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
                GetBuilder<OtherSettingsController>(
                  builder: (controller) => SettingsAction(
                    title: "高级 mpv options",
                    subtitle: "每行一个 key=value，覆盖内置档位和可视化设置",
                    value: AppSettingsController
                            .instance.mpvAdvancedOptions.value.isEmpty
                        ? "未设置"
                        : "已设置",
                    onTap: controller.editMpvAdvancedOptions,
                  ),
                ),
                AppStyle.divider,
                GetBuilder<OtherSettingsController>(
                  builder: (controller) => SettingsAction(
                    title: "导入 mpv.conf",
                    subtitle: "导入后复制到应用私有目录，覆盖同名 mpv option",
                    value: AppSettingsController
                            .instance.importedMpvConfPath.value.isEmpty
                        ? "未导入"
                        : "已导入",
                    onTap: controller.importMpvConf,
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
