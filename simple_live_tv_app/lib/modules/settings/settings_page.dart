import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/settings/settings_controller.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
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
                buildFollowSettings(),
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
      ],
    );
  }

  Widget buildFollowSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.autoUpdateFollowEnableFocusNode,
            autofocus:
                controller.autoUpdateFollowEnableFocusNode.isFoucsed.value,
            title: "自动更新关注",
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
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.autoUpdateFollowDurationFocusNode,
            autofocus:
                controller.autoUpdateFollowDurationFocusNode.isFoucsed.value,
            title: "自动更新间隔",
            items: const {
              5: "5分钟",
              10: "10分钟",
              15: "15分钟",
              20: "20分钟",
              25: "25分钟",
              30: "30分钟",
              60: "1小时",
            },
            value:
                AppSettingsController.instance.autoUpdateFollowDuration.value,
            onChanged: (e) {
              AppSettingsController.instance.setAutoUpdateFollowDuration(e);
              FollowUserService.instance.initTimer();
            },
          ),
        ),
        AppStyle.vGap24,
        Obx(
          () => SettingsItemWidget(
            foucsNode: controller.updateFollowThreadFocusNode,
            autofocus: controller.updateFollowThreadFocusNode.isFoucsed.value,
            title: "更新线程数",
            items: const {
              1: "1",
              2: "2",
              3: "3",
              4: "4",
              6: "6",
              8: "8",
              10: "10",
              12: "12",
            },
            value: AppSettingsController.instance.updateFollowThreadCount.value,
            onChanged: (e) {
              AppSettingsController.instance.setUpdateFollowThreadCount(e);
            },
          ),
        ),
      ],
    );
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
        HighlightListTile(
          focusNode: AppFocusNode(),
          title: "抖音账号",
          subtitle: "无需登录",
          leading: Image.asset(
            "assets/images/douyin.png",
            width: 64.w,
            height: 64.w,
          ),
          onTap: () {
            SmartDialog.showToast("无需登录抖音，您可以直接观看直播");
          },
        )
      ],
    );
  }

  Widget buildAbout() {
    return ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        HighlightListTile(
          focusNode: controller.versionFocusNode,
          title: "版本",
          subtitle: "v${Utils.packageInfo.version}",
          onTap: ()=>{},
        ),
      ],
    );
  }
}
