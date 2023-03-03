import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

class DanmuSettingsPage extends GetView<AppSettingsController> {
  const DanmuSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("弹幕设置"),
      ),
      body: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsA12,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
                    child: Text(
                      "弹幕默认开关",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Switch(
                  value: controller.danmuEnable.value,
                  onChanged: (e) {
                    controller.setDanmuEnable(e);
                  },
                ),
              ],
            ),
            Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(top: 24),
              child: Text(
                "弹幕区域: ${(controller.danmuArea.value * 100).toInt()}%",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Slider(
              value: controller.danmuArea.value,
              max: 1.0,
              min: 0.1,
              onChanged: (e) {
                controller.setDanmuArea(e);
              },
            ),
            Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
              child: Text(
                "不透明度: ${(controller.danmuOpacity.value * 100).toInt()}%",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Slider(
              value: controller.danmuOpacity.value,
              max: 1.0,
              min: 0.1,
              onChanged: (e) {
                controller.setDanmuOpacity(e);
              },
            ),
            Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
              child: Text(
                "弹幕大小: ${(controller.danmuSize.value).toInt()}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Slider(
              value: controller.danmuSize.value,
              min: 8,
              max: 36,
              onChanged: (e) {
                controller.setDanmuSize(e);
              },
            ),
            Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
              child: Text(
                "弹幕速度: ${(controller.danmuSpeed.value).toInt()} (越小越快)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Slider(
              value: controller.danmuSpeed.value,
              min: 4,
              max: 20,
              onChanged: (e) {
                controller.setDanmuSpeed(e);
              },
            ),
          ],
        ),
      ),
    );
  }
}
