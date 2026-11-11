import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/mobile_safe_insets.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class AppstyleSettingPage extends GetView<AppSettingsController> {
  const AppstyleSettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("外观设置"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          if (Platform.isAndroid || Platform.isIOS) ...[
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
              child: Text(
                "安全区域调整",
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Obx(
                () => Column(
                  children: [
                    SettingsNumber(
                      title: "顶部额外留白",
                      subtitle: "在系统安全区域之外，将顶栏向下移动",
                      value: controller.mobileTopExtraInset.value,
                      max: mobileExtraInsetMax,
                      unit: "dp",
                      onChanged: controller.setMobileTopExtraInset,
                    ),
                    AppStyle.divider,
                    SettingsNumber(
                      title: "底部额外留白",
                      subtitle: "将底栏向上移动，全屏和画中画不受影响",
                      value: controller.mobileBottomExtraInset.value,
                      max: mobileExtraInsetMax,
                      unit: "dp",
                      onChanged: controller.setMobileBottomExtraInset,
                    ),
                    AppStyle.divider,
                    SettingsAction(
                      title: "恢复自动安全区域",
                      subtitle: "额外留白归零，仅使用系统安全区域；只保存在本设备",
                      onTap: () {
                        controller.setMobileTopExtraInset(0);
                        controller.setMobileBottomExtraInset(0);
                      },
                    ),
                  ],
                ),
              ),
            ),
            AppStyle.vGap12,
          ],
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "显示主题",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => RadioGroup(
                groupValue: controller.themeMode.value,
                onChanged: (e) {
                  controller.setTheme(e ?? 0);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<int>(
                      title: Text(
                        "跟随系统",
                      ),
                      visualDensity: VisualDensity.compact,
                      value: 0,
                      contentPadding: AppStyle.edgeInsetsH12,
                    ),
                    RadioListTile<int>(
                      title: Text(
                        "浅色模式",
                      ),
                      visualDensity: VisualDensity.compact,
                      value: 1,
                      contentPadding: AppStyle.edgeInsetsH12,
                    ),
                    RadioListTile<int>(
                      title: Text(
                        "深色模式",
                      ),
                      visualDensity: VisualDensity.compact,
                      value: 2,
                      contentPadding: AppStyle.edgeInsetsH12,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppStyle.vGap12,
          Padding(
            padding: AppStyle.edgeInsetsA12,
            child: Text(
              "主题颜色",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsSwitch(
                    value: controller.isDynamic.value,
                    title: "动态取色",
                    onChanged: (e) {
                      controller.setIsDynamic(e);
                      Get.forceAppUpdate();
                    },
                  ),
                  if (!controller.isDynamic.value) AppStyle.divider,
                  if (!controller.isDynamic.value)
                    Padding(
                      padding: AppStyle.edgeInsetsA12,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Color>[
                          const Color(0xffEF5350),
                          const Color(0xff3498db),
                          const Color(0xffF06292),
                          const Color(0xff9575CD),
                          const Color(0xff26C6DA),
                          const Color(0xff26A69A),
                          const Color(0xffFFF176),
                          const Color(0xffFF9800),
                        ]
                            .map(
                              (e) => GestureDetector(
                                onTap: () {
                                  controller.setStyleColor(e.toARGB32());
                                  Get.forceAppUpdate();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: e,
                                    borderRadius: AppStyle.radius4,
                                    border: Border.all(
                                      color: Colors.grey.withAlpha(50),
                                      width: 1,
                                    ),
                                  ),
                                  child: Obx(
                                    () => Center(
                                      child: Icon(
                                        Icons.check,
                                        color: controller.styleColor.value ==
                                                e.toARGB32()
                                            ? Colors.white
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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

// extension ColorExt on Color {
//   static int _floatToInt8(double x) {
//     return (x * 255.0).round() & 0xff;
//   }

//   int get v =>
//       _floatToInt8(a) << 24 |
//       _floatToInt8(r) << 16 |
//       _floatToInt8(g) << 8 |
//       _floatToInt8(b) << 0;
// }
