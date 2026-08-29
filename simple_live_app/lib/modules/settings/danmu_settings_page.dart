import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
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
        padding: AppStyle.pagePadding(),
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
      final resolvedLineCount = controller.resolveDanmuTargetLineCount(
        viewportHeight: effectiveViewportHeight,
        area: area ?? controller.danmuArea.value,
        fontSize: resolvedFontSize,
        lineCount: controller.danmuLineCount.value,
      );
      final hideDanmu = resolvedLineCount <= 0;
      final resolvedArea = controller.resolveDanmuEffectiveArea(
        viewportHeight: effectiveViewportHeight,
        area: area ?? controller.danmuArea.value,
        fontSize: resolvedFontSize,
        lineCount: controller.danmuLineCount.value,
      );
      if (hideDanmu) {
        previewController.clear();
      }
      updateDanmuOption(
        previewController.option.copyWith(
          area: resolvedArea,
          lineHeight: controller.resolveDanmuLineHeight(
            viewportHeight: effectiveViewportHeight,
            area: area ?? controller.danmuArea.value,
            fontSize: resolvedFontSize,
            lineCount: controller.danmuLineCount.value,
          ),
          fontSize: resolvedFontSize,
          fontWeight: fontWeight ?? controller.danmuFontWeight.value,
          duration: duration ?? controller.danmuSpeed.value.toInt(),
          opacity: opacity ?? controller.danmuOpacity.value,
          hideTop: hideDanmu,
          hideBottom: hideDanmu,
          hideScroll: hideDanmu,
          hideSpecial: hideDanmu,
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
                () => SettingsSwitch(
                  title: "显示弹幕表情",
                  value: controller.danmuRenderEmoji.value,
                  onChanged: controller.setDanmuRenderEmoji,
                ),
              ),
              AppStyle.divider,
              // 显示区域和显示几行 - 提到前面
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
                    SettingsMenu<int>(
                      title: "显示几行",
                      subtitle: "优先按这里显示，超过当前区域和字体能容纳的上限时自动收紧",
                      value: controller.resolveDanmuTargetLineCount(
                        viewportHeight: effectiveViewportHeight,
                      ),
                      valueMap: _buildDanmuLineValueMap(
                        controller.estimateDanmuMaxVisibleLineCount(
                          viewportHeight: effectiveViewportHeight,
                        ),
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
              // 动态设置 - 移到后面
              Obx(
                () => SettingsSwitch(
                  title: "重点动态",
                  subtitle: "汇总短时间内重复较多的弹幕内容",
                  value: controller.liveEventFlowEnable.value,
                  onChanged: controller.setLiveEventFlowEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "全屏显示重点动态",
                  subtitle: "在播放器全屏时显示当前重复弹幕摘要",
                  value: controller.liveEventFlowOverlayEnable.value,
                  onChanged: controller.setLiveEventFlowOverlayEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态统计跨度",
                  subtitle: "多少秒内的重复弹幕合并计数",
                  value: controller.liveEventFlowWindowSeconds.value,
                  min: AppSettingsController.kLiveEventFlowMinWindowSeconds,
                  max: AppSettingsController.kLiveEventFlowMaxWindowSeconds,
                  step: 5,
                  onChanged: controller.setLiveEventFlowWindowSeconds,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态展示时间",
                  subtitle: "一条动态多久没有更新后自动消失",
                  value: controller.liveEventFlowDisplaySeconds.value,
                  min: AppSettingsController.kLiveEventFlowMinDisplaySeconds,
                  max: AppSettingsController.kLiveEventFlowMaxDisplaySeconds,
                  step: 1,
                  onChanged: controller.setLiveEventFlowDisplaySeconds,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态起显次数",
                  subtitle: "同一句重复达到多少次后进入重点动态",
                  value: controller.liveEventFlowMinCount.value,
                  min: AppSettingsController.kLiveEventFlowMinCount,
                  max: AppSettingsController.kLiveEventFlowMaxCount,
                  step: 1,
                  onChanged: controller.setLiveEventFlowMinCount,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态保留数量",
                  subtitle: "控制动态页最多保留多少条摘要",
                  value: controller.liveEventFlowLimit.value,
                  min: AppSettingsController.kLiveEventFlowMinLimit,
                  max: AppSettingsController.kLiveEventFlowMaxLimit,
                  step: 50,
                  onChanged: controller.setLiveEventFlowLimit,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "重复弹幕过滤",
                  subtitle: controller.danmuDedupeStrictMode
                      ? "刷屏严父：不同用户重复发同一句也只显示一次"
                      : "普通：同一用户在最近若干条内重复发同一句只显示一次",
                  value: controller.danmuDedupeEnable.value,
                  onChanged: controller.setDanmuDedupeEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsMenu<int>(
                  title: "过滤模式",
                  subtitle: "刷屏严父会忽略用户，只按弹幕内容去重",
                  value: controller.danmuDedupeMode.value,
                  valueMap: const {
                    AppSettingsController.kDanmuDedupeModeUser: "普通",
                    AppSettingsController.kDanmuDedupeModeStrict: "刷屏严父",
                  },
                  onChanged: controller.setDanmuDedupeMode,
                ),
              ),
              AppStyle.divider,
              Obx(() {
                final strictMode = controller.danmuDedupeStrictMode;
                return SettingsNumber(
                  title: "过滤窗口",
                  subtitle: strictMode
                      ? "严父默认 10 条；超过 20 条可能会让弹幕明显变少"
                      : "默认 10 条；窗口越大越容易过滤刷屏",
                  value: controller.danmuDedupeWindow.value,
                  min: controller.danmuDedupeWindowMin,
                  max: AppSettingsController.kDanmuDedupeMaxWindow,
                  onChanged: (e) {
                    controller.setDanmuDedupeWindow(e);
                    if (controller.danmuDedupeStrictMode &&
                        controller.danmuDedupeWindow.value >
                            AppSettingsController
                                .kDanmuDedupeStrictWarnWindow) {
                      SmartDialog.showToast("过滤窗口超过 20 条后，弹幕可能会明显变少");
                    }
                  },
                );
              }),
              Obx(() {
                if (controller.danmuDedupeStrictMode) {
                  return const SizedBox.shrink();
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppStyle.divider,
                    SettingsNumber(
                      title: "过滤步长",
                      subtitle: "默认 2；数值越大检查窗口移动越少",
                      value: controller.danmuDedupeStep.value,
                      min: 1,
                      max: 20,
                      onChanged: controller.setDanmuDedupeStep,
                    ),
                  ],
                );
              }),
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
                  max: 72,
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

  Map<int, String> _buildDanmuLineValueMap(int maxLines) {
    return {
      0: "不显示弹幕",
      for (int i = 1; i <= maxLines; i++) i: "$i 行",
    };
  }

  Widget _buildDanmuLineHint(BuildContext context, double viewportHeight) {
    final maxLines = controller.estimateDanmuMaxVisibleLineCount(
      viewportHeight: viewportHeight,
    );
    final actualLines = controller.resolveDanmuActualLineCount(
      viewportHeight: viewportHeight,
    );
    if (actualLines <= 0) {
      return Text(
        "按当前区域和字体估算，最多大约能排满 $maxLines 行；你现在选择不显示弹幕。",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
      );
    }

    return Text(
      "按当前区域和字体估算，最多大约能排满 $maxLines 行；你现在会显示约 $actualLines 行。",
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
    );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }
}
