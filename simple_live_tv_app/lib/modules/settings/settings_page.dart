import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/settings/settings_controller.dart';
import 'package:simple_live_tv_app/modules/settings/follow_update_interval_options.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/services/kuaishou_account_service.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';
import 'package:simple_live_tv_app/widgets/settings_item_widget.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "设置",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
            ],
          ),
          AppStyle.vGap48,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Obx(
                () => HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.play_circle_outline,
                  text: "播放",
                  selected: controller.tabIndex.value == 0,
                  onTap: () {
                    controller.tabController.animateTo(0);
                  },
                ),
              ),
              AppStyle.hGap32,
              Obx(
                () => HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.subtitles_outlined,
                  text: "弹幕",
                  selected: controller.tabIndex.value == 1,
                  onTap: () {
                    controller.tabController.animateTo(1);
                  },
                ),
              ),
              AppStyle.hGap32,
              Obx(
                () => HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.favorite_border,
                  text: "关注",
                  selected: controller.tabIndex.value == 2,
                  onTap: () {
                    controller.tabController.animateTo(2);
                  },
                ),
              ),
              AppStyle.hGap32,
              Obx(
                () => HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.account_circle_outlined,
                  selected: controller.tabIndex.value == 3,
                  text: "账号",
                  onTap: () {
                    controller.tabController.animateTo(3);
                  },
                ),
              ),
              AppStyle.hGap32,
              Obx(
                () => HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.info_outline,
                  selected: controller.tabIndex.value == 4,
                  text: "关于",
                  onTap: () {
                    controller.tabController.animateTo(4);
                  },
                ),
              ),
            ],
          ),
          Expanded(
              child: SizedBox(
            width: 800.w,
            child: TabBarView(
              controller: controller.tabController,
              children: [
                buildPlayerSettings(),
                buildDanmakuSettings(),
                buildFollowSettings(context),
                buildAccountSettings(),
                buildAbout(),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget buildPlayerSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        Text(
          "部分电视或盒子如果出现黑屏、只有声音没有画面，优先尝试打开“兼容模式”，仍异常时再关闭“硬件解码”。",
          style: AppStyle.subTextStyleWhite,
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuEmojiFoucsNode,
            autofocus: controller.danmakuEmojiFoucsNode.isFoucsed.value,
            title: "显示弹幕表情",
            items: const {
              0: "关",
              1: "开",
            },
            value:
                AppSettingsController.instance.danmuRenderEmoji.value ? 1 : 0,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuRenderEmoji(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.mpvProfileFocusNode,
            autofocus: controller.mpvProfileFocusNode.isFoucsed.value,
            title: "mpv档位",
            items: MpvOptionsService.profileLabels,
            value: AppSettingsController.instance.mpvProfile.value,
            onChanged: (e) {
              AppSettingsController.instance.setMpvProfile(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.hardwareDecodeFocusNode,
            autofocus: controller.hardwareDecodeFocusNode.isFoucsed.value,
            title: "硬件解码",
            items: const {
              0: "关",
              1: "开",
            },
            value: AppSettingsController.instance.hardwareDecode.value ? 1 : 0,
            onChanged: (e) {
              AppSettingsController.instance
                  .setHardwareDecode(e == 1 ? true : false);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.compatibleModeFocusNode,
            autofocus: controller.compatibleModeFocusNode.isFoucsed.value,
            title: "兼容模式",
            items: const {
              0: "关",
              1: "开",
            },
            value:
                AppSettingsController.instance.playerCompatMode.value ? 1 : 0,
            onChanged: (e) {
              AppSettingsController.instance
                  .setPlayerCompatMode(e == 1 ? true : false);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: AppFocusNode(),
            title: "关播后自动换下一个直播间",
            items: const {0: "关", 1: "开"},
            value: AppSettingsController.instance.autoSwitchNextOnLiveEnd.value
                ? 1
                : 0,
            onChanged: (e) {
              AppSettingsController.instance.setAutoSwitchNextOnLiveEnd(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: AppFocusNode(),
            title: "播放失败后自动换下一个直播间",
            items: const {0: "关", 1: "开"},
            value: AppSettingsController
                    .instance.autoSwitchNextOnPlaybackFailure.value
                ? 1
                : 0,
            onChanged: (e) {
              AppSettingsController.instance
                  .setAutoSwitchNextOnPlaybackFailure(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.scaleFoucsNode,
            autofocus: controller.scaleFoucsNode.isFoucsed.value,
            title: "画面比例",
            items: const {
              0: "适应",
              1: "拉伸",
              2: "铺满",
              3: "16:9",
              4: "4:3",
            },
            value: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.defaultQualityFocusNode,
            autofocus: controller.defaultQualityFocusNode.isFoucsed.value,
            title: "默认清晰度",
            items: const {
              0: "最低画质",
              1: "中等画质",
              2: "最高画质",
            },
            value: AppSettingsController.instance.qualityLevel.value,
            onChanged: (e) {
              AppSettingsController.instance.setQualityLevel(e);
            },
          ),
        ),
        AppStyle.vGap24,
      ],
    );
  }

  Widget buildFollowSettings(BuildContext context) {
    return ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        Text(
          "关注刷新分为两种：定时刷新关注状态，以及进入关注页时立即刷新；两者可以分别开关。大量关注时，刷新会等待上一轮完成。",
          style: AppStyle.subTextStyleWhite,
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.autoUpdateFollowEnableFocusNode,
            autofocus:
                controller.autoUpdateFollowEnableFocusNode.isFoucsed.value,
            title: "定时刷新关注状态",
            items: const {
              0: "关",
              1: "开",
            },
            value: AppSettingsController.instance.autoUpdateFollowEnable.value
                ? 1
                : 0,
            onChanged: (e) {
              AppSettingsController.instance
                  .setAutoUpdateFollowEnable(e == 1 ? true : false);
              FollowUserService.instance.initTimer();
              if (e == 1) {
                unawaited(
                  FollowUserService.instance
                      .refreshImmediatelyIfAutomaticEnabled(),
                );
              }
            },
          ),
        ),
        AppStyle.vGap24,
        _buildFollowUpdateDurationSetting(context),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.updateFollowThreadFocusNode,
            autofocus: controller.updateFollowThreadFocusNode.isFoucsed.value,
            title: "更新线程数",
            items: const {
              0: "自动",
              1: "1",
              2: "2",
              3: "3",
              4: "4",
              5: "5",
              6: "6",
              7: "7",
              8: "8",
            },
            value:
                AppSettingsController.instance.effectiveUpdateFollowThreadCount,
            onChanged: (e) {
              AppSettingsController.instance.setUpdateFollowThreadCount(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.followPageSizeFocusNode,
            autofocus: controller.followPageSizeFocusNode.isFoucsed.value,
            title: "关注每页数量",
            items: const {
              50: "50",
              100: "100",
              150: "150",
              200: "200",
              300: "300",
              400: "400",
            },
            value: AppSettingsController.instance.followPageSize.value,
            onChanged: (e) {
              AppSettingsController.instance.setFollowPageSize(e);
              FollowUserService.instance.applyPageSizeSetting();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpdateDurationSetting(BuildContext context) {
    if (_isDesktopTv) {
      return Obx(
        () => HighlightListTile(
          focusNode: controller.autoUpdateFollowDurationFocusNode,
          autofocus:
              controller.autoUpdateFollowDurationFocusNode.isFoucsed.value,
          title: "定时刷新间隔",
          subtitle: _formatFollowUpdateDuration(
            AppSettingsController.instance.autoUpdateFollowDuration.value,
          ),
          leading: const Icon(Icons.timer_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setFollowUpdateTimer(context);
          },
        ),
      );
    }
    return Obx(() {
      final value = _normalizePresetDurationForBuild(
        AppSettingsController.instance.autoUpdateFollowDuration.value,
      );
      return SettingsItemWidget(
        foucsNode: controller.autoUpdateFollowDurationFocusNode,
        autofocus: controller.autoUpdateFollowDurationFocusNode.isFoucsed.value,
        title: "定时刷新间隔",
        items: FollowUpdateIntervalOptions.presetLabels,
        value: value,
        onChanged: (e) {
          AppSettingsController.instance.setAutoUpdateFollowDuration(e as int);
          FollowUserService.instance.initTimer();
        },
      );
    });
  }

  bool get _isDesktopTv =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  String _formatFollowUpdateDuration(int minutes) {
    return FollowUpdateIntervalOptions.format(minutes);
  }

  int _normalizePresetDurationForBuild(int minutes) {
    final value = FollowUpdateIntervalOptions.normalizeToPreset(minutes);
    if (value != minutes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (AppSettingsController.instance.autoUpdateFollowDuration.value !=
            minutes) {
          return;
        }
        AppSettingsController.instance.setAutoUpdateFollowDuration(value);
        FollowUserService.instance.initTimer();
      });
    }
    return value;
  }

  void setFollowUpdateTimer(BuildContext context) async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour:
            AppSettingsController.instance.autoUpdateFollowDuration.value ~/ 60,
        minute:
            AppSettingsController.instance.autoUpdateFollowDuration.value % 60,
      ),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (_, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (value == null || (value.hour == 0 && value.minute == 0)) {
      return;
    }
    final duration = Duration(hours: value.hour, minutes: value.minute);
    AppSettingsController.instance
        .setAutoUpdateFollowDuration(duration.inMinutes);
    FollowUserService.instance.initTimer();
  }

  Widget buildDanmakuSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuFoucsNode,
            autofocus: controller.danmakuFoucsNode.isFoucsed.value,
            title: "弹幕开关",
            items: const {
              0: "关",
              1: "开",
            },
            value: AppSettingsController.instance.danmuEnable.value ? 1 : 0,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuEnable(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuSizeFoucsNode,
            autofocus: controller.danmakuSizeFoucsNode.isFoucsed.value,
            title: "弹幕大小",
            items: {
              24.0: "24",
              32.0: "32",
              40.0: "40",
              48.0: "48",
              56.0: "56",
              64.0: "64",
              72.0: "72",
            },
            value: AppSettingsController.instance.danmuSize.value,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuSize(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuSpeedFoucsNode,
            autofocus: controller.danmakuSpeedFoucsNode.isFoucsed.value,
            title: "弹幕速度",
            items: {
              18.0: "很慢",
              14.0: "较慢",
              12.0: "慢",
              10.0: "正常",
              8.0: "快",
              6.0: "较快",
              4.0: "很快",
            },
            value: AppSettingsController.instance.danmuSpeed.value,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuSpeed(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuAreaFoucsNode,
            autofocus: controller.danmakuAreaFoucsNode.isFoucsed.value,
            title: "显示区域",
            items: {
              0.25: "1/4",
              0.5: "1/2",
              0.75: "3/4",
              1.0: "全屏",
            },
            value: AppSettingsController.instance.danmuArea.value,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuArea(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuOpacityFoucsNode,
            autofocus: controller.danmakuOpacityFoucsNode.isFoucsed.value,
            title: "不透明度",
            items: {
              0.1: "10%",
              0.2: "20%",
              0.3: "30%",
              0.4: "40%",
              0.5: "50%",
              0.6: "60%",
              0.7: "70%",
              0.8: "80%",
              0.9: "90%",
              1.0: "100%",
            },
            value: AppSettingsController.instance.danmuOpacity.value,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuOpacity(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuStorkeFoucsNode,
            autofocus: controller.danmakuStorkeFoucsNode.isFoucsed.value,
            title: "描边宽度",
            items: {
              2.0: "2",
              4.0: "4",
              6.0: "6",
              8.0: "8",
              10.0: "10",
              12.0: "12",
              14.0: "14",
              16.0: "16",
            },
            value: AppSettingsController.instance.danmuStrokeWidth.value,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuStrokeWidth(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.liveEventFlowFoucsNode,
            autofocus: controller.liveEventFlowFoucsNode.isFoucsed.value,
            title: "重点动态",
            items: const {
              0: "关",
              1: "开",
            },
            value: AppSettingsController.instance.liveEventFlowEnable.value
                ? 1
                : 0,
            onChanged: (e) {
              AppSettingsController.instance.setLiveEventFlowEnable(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.liveEventFlowOverlayFoucsNode,
            autofocus: controller.liveEventFlowOverlayFoucsNode.isFoucsed.value,
            title: "全屏显示重点动态",
            items: const {
              0: "关",
              1: "开",
            },
            value:
                AppSettingsController.instance.liveEventFlowOverlayEnable.value
                    ? 1
                    : 0,
            onChanged: (e) {
              AppSettingsController.instance
                  .setLiveEventFlowOverlayEnable(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.liveEventFlowWindowFoucsNode,
            autofocus: controller.liveEventFlowWindowFoucsNode.isFoucsed.value,
            title: "动态统计跨度",
            items: const {
              5: "5秒",
              10: "10秒",
              15: "15秒",
              30: "30秒",
              60: "60秒",
              120: "120秒",
            },
            value: AppSettingsController
                .instance.effectiveLiveEventFlowWindowSeconds,
            onChanged: (e) {
              AppSettingsController.instance.setLiveEventFlowWindowSeconds(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.liveEventFlowDisplayFoucsNode,
            autofocus: controller.liveEventFlowDisplayFoucsNode.isFoucsed.value,
            title: "动态展示时间",
            items: const {
              3: "3秒",
              5: "5秒",
              10: "10秒",
              15: "15秒",
              30: "30秒",
              60: "60秒",
            },
            value: AppSettingsController
                .instance.effectiveLiveEventFlowDisplaySeconds,
            onChanged: (e) {
              AppSettingsController.instance.setLiveEventFlowDisplaySeconds(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.liveEventFlowMinCountFoucsNode,
            autofocus:
                controller.liveEventFlowMinCountFoucsNode.isFoucsed.value,
            title: "动态起显次数",
            items: const {
              2: "2次",
              3: "3次",
              5: "5次",
              8: "8次",
              10: "10次",
              20: "20次",
            },
            value:
                AppSettingsController.instance.effectiveLiveEventFlowMinCount,
            onChanged: (e) {
              AppSettingsController.instance.setLiveEventFlowMinCount(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuDedupeFoucsNode,
            autofocus: controller.danmakuDedupeFoucsNode.isFoucsed.value,
            title: "重复过滤",
            items: const {
              0: "关",
              1: "开",
            },
            value:
                AppSettingsController.instance.danmuDedupeEnable.value ? 1 : 0,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuDedupeEnable(e == 1);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.danmakuDedupeModeFoucsNode,
            autofocus: controller.danmakuDedupeModeFoucsNode.isFoucsed.value,
            title: "过滤模式",
            items: const {
              AppSettingsController.kDanmuDedupeModeUser: "普通",
              AppSettingsController.kDanmuDedupeModeStrict: "刷屏严父",
            },
            value: AppSettingsController.instance.danmuDedupeMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuDedupeMode(e);
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(() {
          final strictMode =
              AppSettingsController.instance.danmuDedupeStrictMode;
          return SettingsItemWidget(
            foucsNode: controller.danmakuDedupeWindowFoucsNode,
            autofocus: controller.danmakuDedupeWindowFoucsNode.isFoucsed.value,
            title: "过滤窗口",
            items: strictMode
                ? const {
                    5: "5条",
                    10: "10条",
                    20: "20条",
                    30: "30条",
                    50: "50条",
                    100: "100条",
                  }
                : const {
                    1: "1条",
                    5: "5条",
                    10: "10条",
                    20: "20条",
                    30: "30条",
                    50: "50条",
                    100: "100条",
                  },
            value: AppSettingsController.instance.effectiveDanmuDedupeWindow,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuDedupeWindow(e);
              if (AppSettingsController.instance.danmuDedupeStrictMode &&
                  AppSettingsController.instance.danmuDedupeWindow.value >
                      AppSettingsController.kDanmuDedupeStrictWarnWindow) {
                SmartDialog.showToast("过滤窗口超过 20 条后，弹幕可能会明显变少");
              }
            },
          );
        }),
        Obx(() {
          if (AppSettingsController.instance.danmuDedupeStrictMode) {
            return const SizedBox.shrink();
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppStyle.vGap24,
              SettingsItemWidget(
                foucsNode: controller.danmakuDedupeStepFoucsNode,
                autofocus:
                    controller.danmakuDedupeStepFoucsNode.isFoucsed.value,
                title: "过滤步长",
                items: const {
                  1: "1",
                  2: "2",
                  3: "3",
                  5: "5",
                },
                value: AppSettingsController.instance.danmuDedupeStep.value,
                onChanged: (e) {
                  AppSettingsController.instance.setDanmuDedupeStep(e);
                },
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget buildAccountSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        Obx(
          () => HighlightListTile(
            focusNode: controller.bilibiliFoucsNode,
            autofocus: controller.bilibiliFoucsNode.isFoucsed.value,
            title: "哔哩哔哩账号",
            subtitle: BiliBiliAccountService.instance.logined.value
                ? "已登录：${BiliBiliAccountService.instance.name.value}"
                : "未登录，点击登录",
            leading: Image.asset(
              "assets/images/bilibili.png",
              width: 64.w,
              height: 64.w,
            ),
            onTap: controller.bilibiliTap,
          ),
        ),
        AppStyle.vGap24,
        HighlightListTile(
          focusNode: AppFocusNode(),
          title: "斗鱼账号",
          subtitle: "无需登录",
          leading: Image.asset(
            "assets/images/douyu.png",
            width: 64.w,
            height: 64.w,
          ),
          onTap: () {
            SmartDialog.showToast("无需登录斗鱼，您可以直接观看直播");
          },
        ),
        AppStyle.vGap24,
        HighlightListTile(
          focusNode: AppFocusNode(),
          title: "虎牙账号",
          subtitle: "无需登录",
          leading: Image.asset(
            "assets/images/huya.png",
            width: 64.w,
            height: 64.w,
          ),
          onTap: () {
            SmartDialog.showToast("无需登录虎牙，您可以直接观看直播");
          },
        ),
        AppStyle.vGap24,
        Obx(
          () => HighlightListTile(
            focusNode: AppFocusNode(),
            title: "抖音账号",
            subtitle: DouyinAccountService.instance.hasCookie.value
                ? "已配置 Cookie，可用于抖音搜索和大批量刷新"
                : "可手动粘贴，或从手机/电脑端同步抖音 Cookie",
            leading: Image.asset(
              "assets/images/douyin.png",
              width: 64.w,
              height: 64.w,
            ),
            onTap: controller.douyinTap,
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => HighlightListTile(
            focusNode: AppFocusNode(),
            title: "快手账号",
            subtitle: KuaishouAccountService.instance.hasCookie.value
                ? "已配置 Cookie，可用于快手搜索和弹幕"
                : "未配置 Cookie，部分搜索和弹幕可能受限",
            leading: Image.asset(
              "assets/images/kuaishou.png",
              width: 64.w,
              height: 64.w,
            ),
            onTap: controller.kuaishouTap,
          ),
        ),
      ],
    );
  }

  Widget buildAbout() {
    return GetBuilder<SettingsController>(
      builder: (controller) => ListView(
        padding: AppStyle.edgeInsetsA48,
        children: [
          HighlightListTile(
            focusNode: controller.versionFocusNode,
            title: "版本",
            subtitle: "v${Utils.packageInfo.version}",
            onTap: () => {},
          ),
          AppStyle.vGap24,
          HighlightListTile(
            focusNode: AppFocusNode(),
            title: "同步服务",
            subtitle:
                "${SignalRService.configuredServerLabel}\n${SignalRService.configuredUrl}",
            onTap: controller.editSyncServerUrl,
          ),
          AppStyle.vGap24,
          HighlightListTile(
            focusNode: AppFocusNode(),
            title: "同步代理",
            subtitle: SignalRService.proxyDisplayName,
            onTap: controller.editSyncProxyUrl,
          ),
        ],
      ),
    );
  }
}
