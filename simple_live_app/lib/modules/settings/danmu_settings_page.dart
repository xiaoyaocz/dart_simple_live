import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class DanmuSettingsPage extends StatelessWidget {
  const DanmuSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("弹幕设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: const [
          DanmuSettingsView(),
        ],
      ),
    );
  }
}

class DanmuSettingsView extends GetView<AppSettingsController> {
  final Function()? onTapDanmuShield;
  final DanmakuController? danmakuController;

  const DanmuSettingsView({
    this.onTapDanmuShield,
    this.danmakuController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
          child: Text(
            "弹幕筛选",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsAction(
                title: "关键词屏蔽",
                onTap: onTapDanmuShield ??
                    () => Get.toNamed(RoutePath.kSettingsDanmuShield),
              ),
              Obx(
                () => SettingsSwitch(
                  title: "弹幕去重",
                  subtitle: "测试性功能",
                  value: controller.danmakuMaskEnable.value,
                  onChanged: (e) {
                    controller.setDanmakuMaskEnable(e);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
          child: Text(
            "弹幕设置",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsSwitch(
                  title: "默认开关",
                  value: controller.danmuEnable.value,
                  onChanged: (e) {
                    controller.setDanmuEnable(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "显示区域",
                  value: (controller.danmuArea.value * 100).toInt(),
                  min: 10,
                  max: 100,
                  step: 10,
                  unit: "%",
                  onChanged: (e) {
                    controller.setDanmuArea(e / 100.0);
                    updateDanmuOption(
                      danmakuController?.option.copyWith(area: e / 100.0),
                    );
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "不透明度",
                  value: (controller.danmuOpacity.value * 100).toInt(),
                  min: 10,
                  max: 100,
                  step: 10,
                  unit: "%",
                  onChanged: (e) {
                    controller.setDanmuOpacity(e / 100.0);
                    updateDanmuOption(
                      danmakuController?.option.copyWith(opacity: e / 100.0),
                    );
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "字体大小",
                  value: controller.danmuSize.toInt(),
                  min: 8,
                  max: 48,
                  onChanged: (e) {
                    controller.setDanmuSize(e.toDouble());
                    updateDanmuOption(
                      danmakuController?.option
                          .copyWith(fontSize: e.toDouble()),
                    );
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "字体粗细",
                  value: controller.danmuFontWeight.value,
                  min: 0,
                  max: 8,
                  step: 1,
                  displayValue: [
                    "极细",
                    "很细",
                    "细",
                    "正常",
                    "小粗",
                    "偏粗",
                    "粗",
                    "很粗",
                    "极粗"
                  ][controller.danmuFontWeight.value]
                      .toString(),
                  onChanged: (e) {
                    controller.setDanmuFontWeight(e);
                    updateDanmuOption(
                      danmakuController?.option.copyWith(
                        fontWeight: e,
                      ),
                    );
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "滚动速度",
                  subtitle: "弹幕持续时间(秒)，越小速度越快",
                  value: controller.danmuSpeed.toInt(),
                  min: 4,
                  max: 20,
                  onChanged: (e) {
                    controller.setDanmuSpeed(e.toDouble());
                    updateDanmuOption(
                      danmakuController?.option.copyWith(duration: e),
                    );
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "字体描边",
                  value: controller.danmuStrokeWidth.toInt(),
                  min: 0,
                  max: 10,
                  onChanged: (e) {
                    controller.setDanmuStrokeWidth(e.toDouble());
                    updateDanmuOption(
                      danmakuController?.option.copyWith(showStroke: e >= 1),
                    );
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "顶部边距",
                  subtitle: "曲面屏显示不全可设置此选项",
                  value: controller.danmuTopMargin.toInt(),
                  min: 0,
                  max: 48,
                  step: 4,
                  onChanged: (e) {
                    controller.setDanmuTopMargin(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "底部边距",
                  subtitle: "曲面屏显示不全可设置此选项",
                  value: controller.danmuBottomMargin.toInt(),
                  min: 0,
                  max: 48,
                  step: 4,
                  onChanged: (e) {
                    controller.setDanmuBottomMargin(e.toDouble());
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
          child: Text(
            "弹幕去重参数设置",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsNumber(
                  title: "去重窗口大小(秒)",
                  value: AppSettingsController.instance.danmuWindowMs.value,
                  step: 1,
                  max: 45,
                  min: 10,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuWindowMs(e);
                  },
                ),
              ),
              Obx(
                () => SettingsSwitch(
                  value: AppSettingsController
                      .instance.danmuTextNormalization.value,
                  title: "文本归一化",
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuTextNormalization(e);
                  },
                ),
              ),
              Obx(
                () => SettingsSwitch(
                  value: AppSettingsController
                      .instance.danmuFrequencyControl.value,
                  title: "弹幕显示频率",
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuFrequencyControl(e);
                  },
                ),
              ),
              Obx(
                () => Visibility(
                  visible: AppSettingsController
                      .instance.danmuFrequencyControl.value,
                  child: SettingsNumber(
                    title: "显示频率(次)",
                    value: AppSettingsController
                        .instance.danmuMaxFrequency.value,
                    step: 1,
                    max: 10,
                    min: 1,
                    onChanged: (e) {
                      AppSettingsController.instance.setDanmuMaxFrequency(e);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }
}
