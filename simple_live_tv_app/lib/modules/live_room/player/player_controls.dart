import 'dart:io';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';
import 'package:simple_live_tv_app/widgets/settings_item_widget.dart';
import 'package:simple_live_tv_app/widgets/status/app_empty_widget.dart';

Widget playerControls(VideoState videoState, LiveRoomController controller) {
  return buildControls(videoState, controller);
}

Widget buildControls(VideoState videoState, LiveRoomController controller) {
  return Stack(
    children: [
      Container(),
      buildDanmuView(videoState, controller),
      _buildLiveEventFlowOverlay(controller),
      // 点击播放器打开设置
      Positioned.fill(
        child: GestureDetector(onTap: () => showPlayerSettings(controller)),
      ),
      Center(
        child: // 中间
            StreamBuilder(
          stream: videoState.widget.controller.player.stream.buffering,
          initialData: videoState.widget.controller.player.state.buffering,
          builder: (_, s) => Visibility(
            visible: s.data ?? false,
            child: SizedBox(
              width: 64.w,
              height: 64.w,
              child: CircularProgressIndicator(
                strokeWidth: 8.w,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

      // 顶部
      Obx(
        () => AnimatedPositioned(
          left: 0,
          right: 0,
          top: (controller.showControlsState.value &&
                  !controller.lockControlsState.value)
              ? 0
              : -200.w,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: EdgeInsets.only(
              left: 32.w,
              right: 32.w,
              top: 24.w,
              bottom: 24.w,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        controller.detail.value?.title ?? '正在读取直播信息...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyle.textStyleWhite,
                      ),
                      Text(
                        "${controller.detail.value?.userName} · ${controller.followed.value ? "已关注" : "未关注"}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => Text(
                    controller.datetime.value,
                    style: AppStyle.titleStyleWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // 底部
      Obx(
        () => AnimatedPositioned(
          left: 0,
          right: 0,
          bottom: (controller.showControlsState.value &&
                  !controller.lockControlsState.value)
              ? 0
              : -300.w,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            padding: EdgeInsets.only(
              left: 32.w,
              right: 32.w,
              bottom: 24.w,
              top: 24.w,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    //清晰度
                    Obx(
                      () => Text(
                        "清晰度: ${controller.currentQualityInfo.value}",
                        style: AppStyle.textStyleWhite,
                      ),
                    ),
                    //线路
                    AppStyle.hGap32,
                    Obx(
                      () => Text(
                        "线路：${controller.currentLineInfo.value}",
                        style: AppStyle.textStyleWhite,
                      ),
                    ),
                    //弹幕开关
                    AppStyle.hGap32,
                    Obx(
                      () => Text(
                        "弹幕: ${controller.showDanmakuState.value ? "开" : "关"}",
                        style: AppStyle.textStyleWhite,
                      ),
                    ),
                    //分辨率
                    AppStyle.hGap32,
                    Obx(
                      () => Text(
                        "分辨率: ${controller.width.value}x${controller.height.value}",
                        style: AppStyle.textStyleWhite,
                      ),
                    ),
                  ],
                ),
                AppStyle.vGap12,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_circle_up_rounded,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text("上一频道", style: AppStyle.textStyleWhite),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_down_rounded,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text("下一频道", style: AppStyle.textStyleWhite),
                    AppStyle.hGap32,
                    Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text("暂停/继续", style: AppStyle.textStyleWhite),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_left_outlined,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text("关注列表", style: AppStyle.textStyleWhite),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_right_outlined,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Icon(Icons.menu, color: Colors.white, size: 44.w),
                    AppStyle.hGap16,
                    Text("设置", style: AppStyle.textStyleWhite),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildLiveEventFlowOverlay(LiveRoomController controller) {
  return Positioned(
    right: 32.w,
    top: 108.w,
    child: Obx(() {
      final settings = AppSettingsController.instance;
      if (!settings.liveEventFlowEnable.value ||
          !settings.liveEventFlowOverlayEnable.value ||
          controller.liveEventFlows.isEmpty) {
        return const SizedBox.shrink();
      }
      return IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in controller.liveEventFlows.take(3))
              TweenAnimationBuilder<double>(
                key: ValueKey("${item.text}-${item.count}"),
                tween: Tween(begin: 1.08, end: 1),
                duration: const Duration(milliseconds: 180),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.centerRight,
                    child: child,
                  );
                },
                child: Container(
                  constraints: BoxConstraints(maxWidth: 420.w),
                  margin: EdgeInsets.only(bottom: 10.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 10.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(6.w),
                  ),
                  child: Text(
                    item.displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.textStyleWhite.copyWith(
                      fontSize: 24.w,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }),
  );
}

Widget buildDanmuView(VideoState videoState, LiveRoomController controller) {
  var padding = MediaQuery.of(videoState.context).padding;
  controller.danmakuView ??= DanmakuScreen(
    key: controller.globalDanmuKey,
    createdController: controller.initDanmakuController,
    option: DanmakuOption(
      fontSize: AppSettingsController.instance.danmuSize.value.w,
      fontFamily: Platform.isWindows ? "Microsoft YaHei" : null,
      area: AppSettingsController.instance.danmuArea.value,
      lineHeight: 1.25,
      emojiScale: 1.4,
      duration: AppSettingsController.instance.danmuSpeed.value.toInt(),
      opacity: AppSettingsController.instance.danmuOpacity.value,
    ),
  );
  return Positioned.fill(
    top: padding.top,
    bottom: padding.bottom,
    child: Obx(
      () => Offstage(
        offstage: !controller.showDanmakuState.value,
        child: Padding(
          padding: controller.fullScreenState.value
              ? EdgeInsets.only(
                  top: AppSettingsController.instance.danmuTopMargin.value,
                  bottom:
                      AppSettingsController.instance.danmuBottomMargin.value,
                )
              : EdgeInsets.zero,
          child: controller.danmakuView!,
        ),
      ),
    ),
  );
}

// void showLinesInfo(LiveRoomController controller) {
//   Utils.showRightDialog(
//     title: "线路",
//     useSystem: true,
//     child: ListView.builder(
//       padding: EdgeInsets.zero,
//       itemCount: controller.playUrls.length,
//       itemBuilder: (_, i) {
//         return ListTile(
//           selected: controller.currentLineIndex == i,
//           title: Text.rich(
//             TextSpan(
//               text: "线路${i + 1}",
//               children: [
//                 WidgetSpan(
//                     child: Container(
//                   decoration: BoxDecoration(
//                     borderRadius: AppStyle.radius4,
//                     border: Border.all(
//                       color: Colors.grey,
//                     ),
//                   ),
//                   padding: AppStyle.edgeInsetsH4,
//                   margin: AppStyle.edgeInsetsL8,
//                   child: Text(
//                     controller.playUrls[i].contains(".flv") ? "FLV" : "HLS",
//                     style: const TextStyle(
//                       fontSize: 12,
//                     ),
//                   ),
//                 )),
//               ],
//             ),
//             style: const TextStyle(fontSize: 14),
//           ),
//           minLeadingWidth: 16,
//           onTap: () {
//             Utils.hideRightDialog();
//             //controller.currentLineIndex = i;
//             //controller.setPlayer();
//             controller.changePlayLine(i);
//           },
//         );
//       },
//     ),
//   );
// }

// void showQualitesInfo(LiveRoomController controller) {
//   Utils.showRightDialog(
//     title: "清晰度",
//     useSystem: true,
//     child: ListView.builder(
//       padding: EdgeInsets.zero,
//       itemCount: controller.qualites.length,
//       itemBuilder: (_, i) {
//         var item = controller.qualites[i];
//         return ListTile(
//           selected: controller.currentQuality == i,
//           title: Text(
//             item.quality,
//             style: const TextStyle(fontSize: 14),
//           ),
//           minLeadingWidth: 16,
//           onTap: () {
//             Utils.hideRightDialog();
//             controller.currentQuality = i;
//             controller.getPlayUrl();
//           },
//         );
//       },
//     ),
//   );
// }

void showPlayerSettings(LiveRoomController controller) {
  // 移除焦点
  controller.focusNode.unfocus();

  var followFocusNode = AppFocusNode()..isFoucsed.value = true;
  var specialFollowFocusNode = AppFocusNode();
  var followTagFocusNode = AppFocusNode();
  var qualityFoucsNode = AppFocusNode();
  var lineFoucsNode = AppFocusNode();
  var scaleFoucsNode = AppFocusNode();
  var danmakuFoucsNode = AppFocusNode();
  var danmakuSizeFoucsNode = AppFocusNode();
  var danmakuSpeedFoucsNode = AppFocusNode();
  var danmakuAreaFoucsNode = AppFocusNode();
  var danmakuOpacityFoucsNode = AppFocusNode();
  Utils.showSystemRightDialog(
    width: 800.w,
    child: Column(
      children: [
        AppStyle.vGap24,
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppStyle.hGap48,
            HighlightButton(
              focusNode: AppFocusNode(),
              iconData: Icons.arrow_back,
              text: "返回",
              onTap: () {
                //Utils.hideRightDialog();
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
        Expanded(
          child: ListView(
            padding: AppStyle.edgeInsetsA48,
            children: [
              Obx(
                () => SettingsItemWidget(
                  foucsNode: followFocusNode,
                  autofocus: followFocusNode.isFoucsed.value,
                  title: "关注用户",
                  items: const {false: "否", true: "是"},
                  value: controller.followed.value,
                  onChanged: (e) {
                    if (e) {
                      controller.followUser();
                    } else {
                      controller.removeFollowUser();
                    }
                  },
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: specialFollowFocusNode,
                  autofocus: specialFollowFocusNode.isFoucsed.value,
                  title: "特别关注",
                  items: const {false: "否", true: "是"},
                  value: controller.specialFollowed.value,
                  onChanged: (e) {
                    controller.toggleSpecialFollow(e);
                  },
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () {
                  final options = FollowUserService.instance.tagOptions;
                  final items = <int, String>{
                    for (var i = 0; i < options.length; i++) i: options[i],
                  };
                  final current = DBService.instance.followBox
                      .get("${controller.rxSite.value.id}_${controller.roomId}")
                      ?.tag;
                  final value =
                      options.indexOf(current ?? FollowUserService.allTagName);
                  return SettingsItemWidget(
                    foucsNode: followTagFocusNode,
                    title: "关注标签",
                    items: items,
                    value: value < 0 ? 0 : value,
                    onChanged: (e) {
                      controller.setCurrentFollowTag(options[e as int]);
                    },
                  );
                },
              ),

              Divider(color: Colors.grey.withAlpha(50), height: 36.w),
              AppStyle.vGap24,
              Padding(
                padding: AppStyle.edgeInsetsH20,
                child: Text(
                  "清晰度与线路",
                  style: AppStyle.textStyleWhite.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppStyle.vGap24,

              // 清晰度切换
              Obx(
                () => SettingsItemWidget(
                  title: "清晰度",
                  foucsNode: qualityFoucsNode,
                  autofocus: qualityFoucsNode.isFoucsed.value,
                  items: controller.qualites
                      .asMap()
                      .map((i, e) => MapEntry(i, e.quality))
                      .cast<int, String>(),
                  value: controller.currentQuality,
                  onChanged: (e) {
                    Get.back();
                    controller.currentQuality = e;
                    controller.getPlayUrl();
                  },
                ),
              ),

              AppStyle.vGap32,
              // 线路切换
              Obx(
                () => SettingsItemWidget(
                  title: "线路",
                  foucsNode: lineFoucsNode,
                  autofocus: lineFoucsNode.isFoucsed.value,
                  items: controller.playUrls
                      .asMap()
                      .map((i, e) => MapEntry(i, "线路${i + 1}"))
                      .cast<int, String>(),
                  value: controller.currentLineIndex,
                  onChanged: (e) {
                    Get.back();
                    controller.changePlayLine(e);
                  },
                ),
              ),
              Divider(color: Colors.grey.withAlpha(50), height: 36.w),
              Padding(
                padding: AppStyle.edgeInsetsH20,
                child: Text(
                  "播放器",
                  style: AppStyle.textStyleWhite.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: scaleFoucsNode,
                  autofocus: scaleFoucsNode.isFoucsed.value,
                  title: "画面比例",
                  items: const {0: "适应", 1: "拉伸", 2: "铺满", 3: "16:9", 4: "4:3"},
                  value: AppSettingsController.instance.scaleMode.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setScaleMode(e);
                    controller.updateScaleMode();
                  },
                ),
              ),
              Divider(color: Colors.grey.withAlpha(50), height: 36.w),
              Padding(
                padding: AppStyle.edgeInsetsH20,
                child: Text(
                  "弹幕",
                  style: AppStyle.textStyleWhite.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: danmakuFoucsNode,
                  autofocus: danmakuFoucsNode.isFoucsed.value,
                  title: "弹幕开关",
                  items: const {0: "关", 1: "开"},
                  value: controller.showDanmakuState.value ? 1 : 0,
                  onChanged: (e) {
                    controller.showDanmakuState.value = e == 1;
                    AppSettingsController.instance.setDanmuEnable(e == 1);
                  },
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: danmakuSizeFoucsNode,
                  autofocus: danmakuSizeFoucsNode.isFoucsed.value,
                  title: "弹幕大小",
                  items: {
                    24.0: "24",
                    32.0: "32",
                    40.0: "40",
                    48.0: "48",
                    56.0: "56",
                    64.0: "64",
                    72.0: "72",
                    96.0: "96",
                    120.0: "120",
                    144.0: "144",
                  },
                  value: AppSettingsController.instance.danmuSize.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuSize(e);
                    controller.updateDanmuOption(
                      controller.danmakuController?.option.copyWith(
                        fontSize: (e as double).w,
                        lineHeight: 1.25,
                        emojiScale: 1.4,
                      ),
                    );
                  },
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: danmakuSpeedFoucsNode,
                  autofocus: danmakuSpeedFoucsNode.isFoucsed.value,
                  title: "弹幕速度",
                  items: {
                    18.0: "很慢",
                    14.0: "较慢",
                    12.0: "慢",
                    10.0: "正常",
                    8.0: "快",
                    6.0: "较快",
                    4.0: "很快",
                    2.0: "极速",
                    1.0: "最快",
                  },
                  value: AppSettingsController.instance.danmuSpeed.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuSpeed(e);
                    controller.updateDanmuOption(
                      controller.danmakuController?.option.copyWith(
                        duration: (e as double).toInt(),
                      ),
                    );
                  },
                ),
              ),

              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: danmakuAreaFoucsNode,
                  autofocus: danmakuAreaFoucsNode.isFoucsed.value,
                  title: "显示区域",
                  items: {0.25: "1/4", 0.5: "1/2", 0.75: "3/4", 1.0: "全屏"},
                  value: AppSettingsController.instance.danmuArea.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuArea(e);
                    controller.updateDanmuOption(
                      controller.danmakuController?.option.copyWith(
                        area: e as double,
                      ),
                    );
                  },
                ),
              ),
              AppStyle.vGap24,
              Obx(
                () => SettingsItemWidget(
                  foucsNode: danmakuOpacityFoucsNode,
                  autofocus: danmakuOpacityFoucsNode.isFoucsed.value,
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
                    controller.updateDanmuOption(
                      controller.danmakuController?.option.copyWith(
                        opacity: e as double,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ).then((value) {
    // 还原焦点
    controller.focusNode.requestFocus();
  });
}

void showFollowUser(LiveRoomController controller) {
  var currentIndex = 0;
  if (controller.followed.value) {
    currentIndex = FollowUserService.instance.livingList.indexWhere(
      (e) =>
          e.id ==
          "${controller.rxSite.value.id}_${controller.detail.value?.roomId}",
    );
    if (currentIndex == -1) {
      currentIndex = 0;
    }
  }
  final followScrollController = ScrollController(
    initialScrollOffset: currentIndex * 172.w,
  );
  final currentFocusNode = AppFocusNode();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (currentIndex > 0 && followScrollController.hasClients) {
      followScrollController.jumpTo(
        (currentIndex * 172.w)
            .clamp(0.0, followScrollController.position.maxScrollExtent),
      );
    }
    currentFocusNode.requestFocus();
  });

  Utils.showSystemRightDialog(
    width: 800.w,
    child: Column(
      children: [
        AppStyle.vGap24,
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppStyle.hGap48,
            HighlightButton(
              focusNode: AppFocusNode(),
              iconData: Icons.arrow_back,
              text: "返回",
              autofocus: currentIndex == 0 &&
                  FollowUserService.instance.livingList.isEmpty,
              onTap: () {
                // Utils.hideRightDialog();
                Get.back();
              },
            ),
            AppStyle.hGap32,
            Text(
              "我的关注",
              style: AppStyle.titleStyleWhite.copyWith(
                fontSize: 36.w,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppStyle.hGap24,
            const Spacer(),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              Obx(
                () => ListView.separated(
                  controller: followScrollController,
                  itemCount: FollowUserService.instance.livingList.length,
                  separatorBuilder: (context, index) => AppStyle.vGap32,
                  padding: AppStyle.edgeInsetsA40.copyWith(
                    left: 48.w,
                    right: 48.w,
                  ),
                  itemBuilder: (_, i) {
                    var item = FollowUserService.instance.livingList[i];
                    var site = Sites.allSites[item.siteId]!;
                    return AnchorCard(
                      face: item.face,
                      name: item.userName,
                      siteId: item.siteId,
                      liveStatus: item.liveStatus.value,
                      roomId: item.roomId,
                      autofocus: i == currentIndex,
                      focusNode: i == currentIndex ? currentFocusNode : null,
                      onTap: () {
                        controller.resetRoom(site, item.roomId);
                        Get.back();
                      },
                    );
                  },
                ),
              ),
              Obx(
                () => Visibility(
                  visible: FollowUserService.instance.list.isEmpty,
                  child: const AppEmptyWidget(text: "关注列表为空，快去关注一些主播吧"),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ).then((value) {
    followScrollController.dispose();
    currentFocusNode.dispose();
    // 还原焦点
    controller.focusNode.requestFocus();
  });
}
