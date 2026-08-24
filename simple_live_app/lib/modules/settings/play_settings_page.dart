import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlaySettingsPage extends GetView<AppSettingsController> {
  const PlaySettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("直播间设置"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
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
                    title: Platform.isIOS ? "硬件加速" : "硬件解码",
                    value: controller.hardwareDecode.value,
                    subtitle: Platform.isIOS
                        ? "建议保持开启；关闭后更耗电，仅在排查黑屏时临时使用"
                        : "播放失败可尝试关闭此选项",
                    onChanged: (e) {
                      controller.setHardwareDecode(e);
                    },
                  ),
                ),
                if (Platform.isIOS) AppStyle.divider,
                if (Platform.isIOS)
                  Obx(
                    () => SettingsSwitch(
                      title: "原画省电优化",
                      subtitle: "限制渲染纹理不超过屏幕实际像素，不降低直播源清晰度；异常时可关闭",
                      value: controller.iosOriginalQualityPowerSaving.value,
                      onChanged: controller.setIosOriginalQualityPowerSaving,
                    ),
                  ),
                if (Platform.isAndroid) AppStyle.divider,
                Obx(
                  () => Visibility(
                    visible: Platform.isAndroid,
                    child: SettingsSwitch(
                      title: "兼容模式",
                      subtitle: "若播放卡顿可尝试打开此选项",
                      value: controller.playerCompatMode.value,
                      onChanged: (e) {
                        controller.setPlayerCompatMode(e);
                      },
                    ),
                  ),
                ),
                // AppStyle.divider,
                // Obx(
                //   () => SettingsNumber(
                //     title: "缓冲区大小",
                //     subtitle: "若播放卡顿可尝试调高此选项",
                //     value: controller.playerBufferSize.value,
                //     min: 32,
                //     max: 1024,
                //     step: 4,
                //     unit: "MB",
                //     onChanged: (e) {
                //       controller.setPlayerBufferSize(e);
                //     },
                //   ),
                // ),
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
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "使用HTTPS链接",
                    subtitle: "将http链接替换为https",
                    value: controller.playerForceHttps.value,
                    onChanged: (e) {
                      controller.setPlayerForceHttps(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "滑动调节音量/亮度",
                    subtitle: "播放页左右两侧上下滑动调节亮度和音量",
                    value: controller.playerGestureControlEnable.value,
                    onChanged: (e) {
                      controller.setPlayerGestureControlEnable(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "允许后台继续播放",
                    subtitle: "移动端仍可能被系统省电策略关闭，返回前台时会尽量自动恢复",
                    value: controller.allowBackgroundPlayback.value,
                    onChanged: (e) {
                      controller.setAllowBackgroundPlayback(e);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (LiveSubtitleService.instance.uiEnabled) ...[
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
              child: Text(
                "实时字幕（实验）",
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      title: "启用实时字幕",
                      subtitle:
                          "需要先选择本机模型路径，${LiveSubtitleService.instance.platformStatusLabel}",
                      value: controller.liveSubtitleEnable.value,
                      onChanged: (e) async {
                        if (e) {
                          if (!LiveSubtitleService.instance.canStartRuntime) {
                            SmartDialog.showToast("当前平台暂不支持实时字幕识别");
                            return;
                          }
                          final hasModel = await LiveSubtitleService.instance
                              .validateModelPath(
                            controller.liveSubtitleModelPath.value,
                          );
                          if (!hasModel) {
                            SmartDialog.showToast("请先选择有效的字幕模型路径");
                            return;
                          }
                        }
                        controller.setLiveSubtitleEnable(e);
                        await LiveSubtitleService.instance
                            .syncPreviewFromSettings();
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () {
                      final modelPath = controller.liveSubtitleModelPath.value;
                      final label =
                          modelPath.isEmpty ? "未选择" : p.basename(modelPath);
                      return SettingsAction(
                        title: "模型关键文件",
                        subtitle: LiveSubtitleService.instance
                            .modelPathSubtitle(modelPath),
                        value: label,
                        onTap: pickSubtitleModelPath,
                      );
                    },
                  ),
                  AppStyle.divider,
                  SettingsAction(
                    title: "模型推荐下载",
                    subtitle: "按设备性能选择高级 / 中级 / 甜点级模型",
                    onTap: showSubtitleModelRecommendations,
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<String>(
                      title: "字幕语言",
                      value: controller.liveSubtitleLanguage.value,
                      valueMap: const {
                        "auto": "自动",
                        "zh": "中文",
                        "en": "英语",
                        "ja": "日语",
                        "ko": "韩语",
                      },
                      onChanged: (e) async {
                        controller.setLiveSubtitleLanguage(e);
                        await LiveSubtitleService.instance
                            .syncPreviewFromSettings();
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsNumber(
                      title: "字幕字号",
                      value: controller.liveSubtitleFontSize.value.toInt(),
                      min: 12,
                      max: 36,
                      unit: "px",
                      onChanged: (e) {
                        controller.setLiveSubtitleFontSize(e.toDouble());
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsNumber(
                      title: "水平位置",
                      value:
                          (controller.liveSubtitleOffsetX.value * 100).round(),
                      min: 5,
                      max: 95,
                      unit: "%",
                      onChanged: (e) {
                        controller.setLiveSubtitleOffset(x: e / 100);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsNumber(
                      title: "垂直位置",
                      value:
                          (controller.liveSubtitleOffsetY.value * 100).round(),
                      min: 8,
                      max: 92,
                      unit: "%",
                      onChanged: (e) {
                        controller.setLiveSubtitleOffset(y: e / 100);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "字幕颜色",
                      value: controller.liveSubtitleColor.value,
                      valueMap: const {
                        0xffffffff: "白色",
                        0xffffeb3b: "黄色",
                        0xff80cbc4: "青绿色",
                        0xffffb3c7: "粉色",
                        0xff111111: "黑色",
                      },
                      onChanged: (e) {
                        controller.setLiveSubtitleColor(e);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "字幕粗细",
                      value: controller.liveSubtitleFontWeight.value,
                      valueMap: const {
                        4: "正常",
                        5: "中等",
                        6: "半粗",
                        7: "加粗",
                        8: "很粗",
                      },
                      onChanged: (e) {
                        controller.setLiveSubtitleFontWeight(e);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "字幕背景",
                      value: controller.liveSubtitleBackgroundEnable.value,
                      onChanged: (e) {
                        controller.setLiveSubtitleBackgroundEnable(e);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "锁定字幕位置",
                      subtitle: "锁定后播放页只显示字幕，鼠标悬停时显示解锁按钮",
                      value: controller.liveSubtitlePositionLocked.value,
                      onChanged: (e) {
                        controller.setLiveSubtitlePositionLocked(e);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  () => SettingsSwitch(
                    title: "关播后自动换下一个直播间",
                    subtitle: "当前房间确认已下播后，自动切到关注列表里下一个正在直播的房间",
                    value: controller.autoSwitchNextOnLiveEnd.value,
                    onChanged: (e) {
                      controller.setAutoSwitchNextOnLiveEnd(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "播放失败后自动换下一个直播间",
                    subtitle: "当前房间重试和线路切换都失败后，自动切到下一个正在直播的房间",
                    value: controller.autoSwitchNextOnPlaybackFailure.value,
                    onChanged: (e) {
                      controller.setAutoSwitchNextOnPlaybackFailure(e);
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
                if (Platform.isAndroid) AppStyle.divider,
                Obx(
                  () => Visibility(
                    visible: Platform.isAndroid,
                    child: SettingsSwitch(
                      title: "退出时自动小窗",
                      subtitle: "按 Home 键或系统手势退到后台时进入小窗；应用内返回仍回到主页",
                      value: controller.autoPipOnExit.value,
                      onChanged: (e) {
                        controller.setAutoPipOnExit(e);
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
              "弹幕显示优化",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 小窗弹幕设置（桌面端）
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
                  Padding(
                    padding: AppStyle.edgeInsetsA12,
                    child: Text(
                      "小窗弹幕",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Get.theme.primaryColor,
                      ),
                    ),
                  ),
                  Obx(
                    () => SettingsNumber(
                      title: "小窗字体缩放",
                      subtitle: "相对于正常播放时的弹幕大小",
                      value: (controller.smallWindowDanmuScale.value * 10).round(),
                      min: 5,
                      max: 10,
                      step: 1,
                      unit: "",
                      displayValue: "${(controller.smallWindowDanmuScale.value * 10).round() / 10}x",
                      onChanged: (v) => controller.setSmallWindowDanmuScale(v / 10),
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsNumber(
                      title: "小窗最大行数",
                      subtitle: "限制小窗时的弹幕行数，避免遮挡画面",
                      value: controller.smallWindowDanmuMaxLines.value,
                      min: 3,
                      max: 10,
                      step: 1,
                      unit: "行",
                      onChanged: controller.setSmallWindowDanmuMaxLines,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "小窗自动透明",
                      subtitle: "小窗时自动降低弹幕透明度（70%）",
                      value: controller.smallWindowDanmuAutoTransparent.value,
                      onChanged: controller.setSmallWindowDanmuAutoTransparent,
                    ),
                  ),
                ],
                // PIP弹幕设置（Android）
                if (Platform.isAndroid) ...[
                  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) AppStyle.divider,
                  Padding(
                    padding: AppStyle.edgeInsetsA12,
                    child: Text(
                      "PIP 弹幕（画中画）",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Get.theme.primaryColor,
                      ),
                    ),
                  ),
                  Obx(
                    () => SettingsSwitch(
                      title: "PIP 显示弹幕",
                      subtitle: "画中画模式下显示弹幕（仅滚动弹幕，限制区域）",
                      value: controller.enablePipDanmu.value,
                      onChanged: controller.setEnablePipDanmu,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsNumber(
                      title: "PIP 字体缩放",
                      subtitle: "相对于正常播放时的弹幕大小",
                      value: (controller.pipDanmuScale.value * 20).round(),
                      min: 10,
                      max: 20,
                      step: 1,
                      unit: "",
                      displayValue: "${(controller.pipDanmuScale.value * 20).round() / 20}x",
                      onChanged: (v) => controller.setPipDanmuScale(v / 20),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // SuperChat 全屏滚动
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: "SC 全屏滚动",
                    subtitle: "SuperChat 在全屏时作为弹幕滚动显示，格式：【头条】用户名：内容",
                    value: controller.superChatScrollInFullscreen.value,
                    onChanged: controller.setSuperChatScrollInFullscreen,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "清晰度",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsMenu<int>(
                    title: "默认清晰度",
                    value: controller.qualityLevel.value,
                    valueMap: const {
                      0: "最低",
                      1: "中等",
                      2: "最高",
                    },
                    onChanged: (e) {
                      controller.setQualityLevel(e);
                    },
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsMenu<int>(
                    title: "数据网络清晰度",
                    value: controller.qualityLevelCellular.value,
                    valueMap: const {
                      0: "最低",
                      1: "中等",
                      2: "最高",
                    },
                    onChanged: (e) {
                      controller.setQualityLevelCellular(e);
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
        ],
      ),
    );
  }

  Future<void> pickSubtitleModelPath() async {
    String? selectedPath;
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: "选择字幕模型关键 onnx 文件",
        type: FileType.custom,
        allowedExtensions: const ["onnx"],
      );
      selectedPath = result?.files.single.path;
    } catch (_) {
      selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择字幕模型文件夹",
      );
    }
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }
    final info = await LiveSubtitleService.instance.inspectModelPath(
      selectedPath,
    );
    if (info == null) {
      SmartDialog.showToast("未识别模型，请选择推荐模型的关键 onnx 文件");
      return;
    }
    if (!info.isValid) {
      SmartDialog.showToast("模型缺少：${info.missingFileNames.join("、")}");
      return;
    }
    controller.setLiveSubtitleModelPath(info.keyFilePath);
    await LiveSubtitleService.instance.syncPreviewFromSettings();
  }

  void showSubtitleModelRecommendations() {
    Get.dialog(
      AlertDialog(
        title: const Text("字幕模型推荐"),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "选一个档位，下载该档位列出的全部文件，放到同一个文件夹；App 里选择关键 onnx 文件。其他 .weights、非 int8 onnx 和 test_wavs 不用下载。蓝奏云/百度网盘镜像链接看 README。",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              _SubtitleModelTile(
                title: "高级（高性能桌面）",
                subtitle:
                    "下载：large-v3-encoder.int8.onnx、large-v3-decoder.int8.onnx、large-v3-tokens.txt。App 里选 encoder 这个 onnx。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-large-v3",
              ),
              _SubtitleModelTile(
                title: "中级（中文直播优先）",
                subtitle:
                    "下载：model.int8.onnx、tokens.txt、config.yaml、am.mvn。App 里选 model.int8.onnx。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14",
              ),
              _SubtitleModelTile(
                title: "甜点级（先试这个）",
                subtitle:
                    "下载：encoder-epoch-99-avg-1.int8.onnx、decoder-epoch-99-avg-1.int8.onnx、joiner-epoch-99-avg-1.int8.onnx、tokens.txt、bpe.model、bpe.vocab。App 里选 encoder 这个 onnx。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }
}

class _SubtitleModelTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;

  const _SubtitleModelTile({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () {
        launchUrlString(url, mode: LaunchMode.externalApplication);
      },
    );
  }
}
