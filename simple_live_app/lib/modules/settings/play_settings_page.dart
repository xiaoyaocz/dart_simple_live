import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class PlaySettingsPage extends GetView<AppSettingsController> {
  const PlaySettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final overridePlatform = debugDefaultTargetPlatformOverride;
    final showWindowsEnhancements =
        overridePlatform == TargetPlatform.windows ||
            (overridePlatform == null && Platform.isWindows);
    final showMobileEnhancements =
        overridePlatform == TargetPlatform.android ||
            overridePlatform == TargetPlatform.iOS ||
            (overridePlatform == null && (Platform.isAndroid || Platform.isIOS));
    return Scaffold(
      appBar: AppBar(
        title: const Text("直播间设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "播放器",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: "进入后台自动暂停",
                    value: controller.playerAutoPause.value,
                    onChanged: (e) {
                      controller.setPlayerAutoPause(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsMenu<int>(
                    title: "画面尺寸",
                    value: controller.scaleMode.value,
                    valueMap: const {
                      0: "适应",
                      1: "拉伸",
                      2: "铺满",
                      3: "16:9",
                      4: "4:3",
                    },
                    onChanged: (e) {
                      controller.setScaleMode(e);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "直播间",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: "进入直播间自动全屏",
                    value: controller.autoFullScreen.value,
                    onChanged: (e) {
                      controller.setAutoFullScreen(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => Visibility(
                    visible: Platform.isAndroid,
                    child: SettingsSwitch(
                      title: "进入小窗隐藏弹幕",
                      value: controller.pipHideDanmu.value,
                      onChanged: (e) {
                        controller.setPIPHideDanmu(e);
                      },
                    ),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "播放器中显示SC",
                    value: controller.playershowSuperChat.value,
                    onChanged: (e) {
                      controller.setPlayerShowSuperChat(e);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "聊天区",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsNumber(
                    title: "文字大小",
                    value: controller.chatTextSize.value.toInt(),
                    min: 8,
                    max: 36,
                    onChanged: (e) {
                      controller.setChatTextSize(e.toDouble());
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsNumber(
                    title: "上下间隔",
                    value: controller.chatTextGap.value.toInt(),
                    min: 0,
                    max: 12,
                    onChanged: (e) {
                      controller.setChatTextGap(e.toDouble());
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "气泡样式",
                    value: controller.chatBubbleStyle.value,
                    onChanged: (e) {
                      controller.setChatBubbleStyle(e);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (showWindowsEnhancements) ...[
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
              child: Text(
                "画质与音频增强",
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      title: "AI 超分增强（FSRCNNX）",
                      subtitle: "1080p 放大到 2K/4K 时锐化细节；独显推荐，低配或想省电可关闭",
                      value: controller.windowsSuperResolution.value,
                      onChanged: controller.setWindowsSuperResolution,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "动态画面平滑（补帧）",
                      subtitle: "mpv 时间域帧平滑（非 AI 光流）；高刷屏可按需开启，可能轻微增加延迟",
                      value: controller.windowsInterpolation.value,
                      onChanged: controller.setWindowsInterpolation,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "WASAPI 音频独占",
                      subtitle: "绕过系统混音直出声卡；开启后播放直播时其他软件将静音，重进直播间生效",
                      value: controller.windowsAudioExclusive.value,
                      onChanged: controller.setWindowsAudioExclusive,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showMobileEnhancements) ...[
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
              child: Text(
                "画质与流畅增强",
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      title: "画面去色带（Deband）",
                      subtitle: "消除直播暗部压缩色块与断层；GPU 开销极低，默认开启",
                      value: controller.mobileDeband.value,
                      onChanged: controller.setMobileDeband,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "高刷动态画面平滑（补帧）",
                      subtitle:
                          "mpv 时间域帧平滑（非 AI 光流）；90/120Hz 旗舰机可按需开启，可能轻微增加功耗与延迟",
                      value: controller.mobileInterpolation.value,
                      onChanged: controller.setMobileInterpolation,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
