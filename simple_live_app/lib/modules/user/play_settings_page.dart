import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

class PlaySettingsPage extends GetView<AppSettingsController> {
  const PlaySettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("播放设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          Obx(
            () => SwitchListTile(
              title: Text(
                "进入直播间自动全屏",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              value: controller.autoFullScreen.value,
              onChanged: (e) {
                controller.setAutoFullScreen(e);
              },
            ),
          ),
          Obx(
            () => SwitchListTile(
              title: Text(
                "硬件解码",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              value: controller.hardwareDecode.value,
              onChanged: (e) {
                controller.setHardwareDecode(e);
              },
            ),
          ),
          Obx(
            () => Visibility(
              visible: Platform.isAndroid,
              child: SwitchListTile(
                title: Text(
                  "兼容模式",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text("若播放卡顿可尝试打开此选项"),
                value: controller.playerCompatMode.value,
                onChanged: (e) {
                  controller.setPlayerCompatMode(e);
                },
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
                  child: Text(
                    "默认清晰度设置",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                height: 36,
                child: Obx(
                  () => DropdownButtonFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: AppStyle.edgeInsetsH12,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          "最高",
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          "中等",
                        ),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          "最低",
                        ),
                      ),
                    ],
                    value: controller.qualityLevel.value,
                    onChanged: (e) {
                      controller.setQualityLevel(e ?? 1);
                    },
                  ),
                ),
              ),
              AppStyle.hGap12,
            ],
          ),
          AppStyle.vGap12,
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
                  child: Text(
                    "画面尺寸",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                height: 36,
                child: Obx(
                  () => DropdownButtonFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: AppStyle.edgeInsetsH12,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          "适应",
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          "拉伸",
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          "铺满",
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(
                          "16:9",
                        ),
                      ),
                      DropdownMenuItem(
                        value: 4,
                        child: Text(
                          "4:3",
                        ),
                      ),
                    ],
                    value: controller.scaleMode.value,
                    onChanged: (e) {
                      controller.setScaleMode(e ?? 0);
                    },
                  ),
                ),
              ),
              AppStyle.hGap12,
            ],
          ),
          AppStyle.vGap12,
          Obx(
            () => Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
              child: Text(
                "聊天区文字大小: ${(controller.chatTextSize.value).toInt()}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Obx(
            () => Slider(
              value: controller.chatTextSize.value,
              min: 8,
              max: 36,
              onChanged: (e) {
                controller.setChatTextSize(e);
              },
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
            child: Obx(
              () => Text(
                "聊天区上下间隔: ${(controller.chatTextGap.value).toInt()}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Obx(
            () => Slider(
              value: controller.chatTextGap.value,
              min: 0,
              max: 12,
              onChanged: (e) {
                controller.setChatTextGap(e);
              },
            ),
          ),
        ],
      ),
    );
  }
}
