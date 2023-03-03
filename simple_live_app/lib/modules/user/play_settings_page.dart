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
        padding: AppStyle.edgeInsetsA12,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
                  child: Text(
                    "硬件解码",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Obx(
                () => Switch(
                  value: controller.hardwareDecode.value,
                  onChanged: (e) {
                    controller.setHardwareDecode(e);
                  },
                ),
              ),
            ],
          ),
          AppStyle.vGap12,
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
