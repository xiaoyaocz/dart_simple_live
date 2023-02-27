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
                  child: const Text(
                    "硬件解码",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              Switch(
                value: controller.hardwareDecode.value,
                onChanged: (e) {
                  controller.setHardwareDecode(e);
                },
              ),
            ],
          ),
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
            child: Text(
              "聊天区文字大小: ${(controller.chatTextSize.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: controller.chatTextSize.value,
            min: 8,
            max: 36,
            onChanged: (e) {
              controller.setChatTextSize(e);
            },
          ),
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
            child: Text(
              "聊天区上下间隔: ${(controller.chatTextGap.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: controller.chatTextGap.value,
            min: 0,
            max: 12,
            onChanged: (e) {
              controller.setChatTextGap(e);
            },
          ),
        ],
      ),
    );
  }
}
