import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class DanmuSettingsPage extends StatelessWidget {
  const DanmuSettingsPage({Key? key}) : super(key: key);

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
  final String? siteId;
  final double? previewViewportHeight;

  const DanmuSettingsView({
    this.onTapDanmuShield,
    this.danmakuController,
    this.siteId,
    this.previewViewportHeight,
    super.key,
  });

  double _resolvePreviewViewportHeight(BuildContext context) {
    if (previewViewportHeight != null && previewViewportHeight! > 0) {
      return previewViewportHeight!;
    }
    final size = MediaQuery.sizeOf(context);
    final shortest = size.width < size.height ? size.width : size.height;
    return (shortest * 9 / 16).clamp(180.0, size.height);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveViewportHeight = _resolvePreviewViewportHeight(context);

    void updatePreviewOption({
      double? area,
      double? fontSize,
      int? fontWeight,
      int? duration,
      double? opacity,
    }) {
      final previewController = danmakuController;
      if (previewController == null) {
        return;
      }
      final resolvedFontSize = fontSize ?? controller.danmuSize.value;
      final resolvedArea = controller.resolveDanmuEffectiveArea(
        viewportHeight: effectiveViewportHeight,
        area: area ?? controller.danmuArea.value,
        fontSize: resolvedFontSize,
        lineCount: controller.danmuLineCount.value,
      );
      updateDanmuOption(
        previewController.option.copyWith(
          area: resolvedArea,
          fontSize: resolvedFontSize,
          fontWeight: fontWeight ?? controller.danmuFontWeight.value,
          duration: duration ?? controller.danmuSpeed.value.toInt(),
          opacity: opacity ?? controller.danmuOpacity.value,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
          child: Text(
            "弹幕屏蔽",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsSwitch(
                  title: "启用弹幕屏蔽",
                  subtitle: "关闭后，关键词和用户屏蔽都会暂时失效",
                  value: controller.danmuShieldEnable.value,
                  onChanged: controller.setDanmuShieldEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "启用关键词屏蔽",
                  value: controller.danmuKeywordShieldEnable.value,
                  onChanged: controller.setDanmuKeywordShieldEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "启用用户屏蔽",
                  subtitle: "也可以在直播间点击用户名，快速屏蔽或取消屏蔽",
                  value: controller.danmuUserShieldEnable.value,
                  onChanged: controller.setDanmuUserShieldEnable,
                ),
              ),
              AppStyle.divider,
              SettingsAction(
                title: "打开屏蔽管理",
                onTap: onTapDanmuShield ??
                    () => Get.toNamed(RoutePath.kSettingsDanmuShield),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
          child: Text(
            "弹幕显示",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsSwitch(
                  title: "默认开启",
                  value: controller.danmuEnable.value,
                  onChanged: controller.setDanmuEnable,
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
                    final nextArea = e / 100.0;
                    controller.setDanmuArea(nextArea);
                    final nextMaxLines =
                        controller.estimateDanmuMaxVisibleLineCount(
                      viewportHeight: effectiveViewportHeight,
                      area: nextArea,
                    );
                    if (controller.danmuLineCount.value > nextMaxLines) {
                      controller.setDanmuLineCount(nextMaxLines);
                    }
                    updatePreviewOption(area: nextArea);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => Column(
                  children: [
                    SettingsNumber(
                      title: "显示几行",
                      subtitle: "和显示区域一起决定同屏弹幕密度，比直接调上下间距更直观",
                      value: controller.danmuLineCount.value.clamp(
                        1,
                        controller.estimateDanmuMaxVisibleLineCount(
                          viewportHeight: effectiveViewportHeight,
                        ),
                      ),
                      min: 1,
                      max: controller.estimateDanmuMaxVisibleLineCount(
                        viewportHeight: effectiveViewportHeight,
                      ),
                      onChanged: (e) {
                        controller.setDanmuLineCount(e);
                        updatePreviewOption();
                      },
                    ),
                    Padding(
                      padding: AppStyle.edgeInsetsH16.copyWith(
                        top: 4,
                        bottom: 12,
                      ),
                      child: _buildDanmuLineHint(
                        context,
                        effectiveViewportHeight,
                      ),
                    ),
                  ],
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
                    updatePreviewOption(opacity: e / 100.0);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "字体大小",
                  value: controller.danmuSize.value.toInt(),
                  min: 8,
                  max: 48,
                  onChanged: (e) {
                    final nextFontSize = e.toDouble();
                    controller.setDanmuSize(nextFontSize);
                    final nextMaxLines =
                        controller.estimateDanmuMaxVisibleLineCount(
                      viewportHeight: effectiveViewportHeight,
                      fontSize: nextFontSize,
                    );
                    if (controller.danmuLineCount.value > nextMaxLines) {
                      controller.setDanmuLineCount(nextMaxLines);
                    }
                    updatePreviewOption(fontSize: nextFontSize);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "字体粗细",
                  value: controller.danmuFontWeight.value,
                  min: 1,
                  max: 9,
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
                    "极粗",
                  ][controller.danmuFontWeight.value - 1],
                  onChanged: (e) {
                    controller.setDanmuFontWeight(e);
                    updatePreviewOption(fontWeight: e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "滚动速度",
                  subtitle: "弹幕持续时间（秒），越小速度越快",
                  value: controller.danmuSpeed.value.toInt(),
                  min: 4,
                  max: 20,
                  onChanged: (e) {
                    controller.setDanmuSpeed(e.toDouble());
                    updatePreviewOption(duration: e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: siteId == null ? "全局弹幕延迟" : "全局延迟兜底",
                  subtitle: "单位毫秒，适合不同平台节奏不同或网络抖动时微调",
                  value: controller.danmuDelayMs.value,
                  min: 0,
                  max: 5000,
                  step: 100,
                  unit: "ms",
                  onChanged: (e) => controller.setDanmuDelayMs(e),
                ),
              ),
              if (siteId != null) ...[
                AppStyle.divider,
                Obx(
                  () => SettingsNumber(
                    title: "${controller.resolveShieldSiteLabel(siteId)} 平台补偿",
                    subtitle: "只对当前平台生效，会覆盖上面的全局延迟",
                    value: controller.getDanmuDelayMs(siteId),
                    min: 0,
                    max: 5000,
                    step: 100,
                    unit: "ms",
                    onChanged: (e) => controller.setDanmuDelayMs(
                      e,
                      siteId: siteId,
                    ),
                  ),
                ),
              ],
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "顶部安全边距",
                  subtitle: "异形屏或状态栏遮挡时可微调",
                  value: controller.danmuTopMargin.value.toInt(),
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
                  title: "底部安全边距",
                  subtitle: "导航栏或手势条遮挡时可微调",
                  value: controller.danmuBottomMargin.value.toInt(),
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
      ],
    );
  }

  Widget _buildDanmuLineHint(BuildContext context, double viewportHeight) {
    final maxLines = controller.estimateDanmuMaxVisibleLineCount(
      viewportHeight: viewportHeight,
    );
    final actualLines = controller.resolveDanmuActualLineCount(
      viewportHeight: viewportHeight,
    );
    final threshold = controller.estimateDanmuSparseWarningThreshold(
      viewportHeight: viewportHeight,
    );
    final isSparse = actualLines <= threshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "按当前区域和字体估算，最多大约能排满 $maxLines 行；你现在会显示约 $actualLines 行。",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        if (isSparse) ...[
          AppStyle.vGap4,
          Text(
            "你选的行数太少了！我心里空落落的~",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }
}
