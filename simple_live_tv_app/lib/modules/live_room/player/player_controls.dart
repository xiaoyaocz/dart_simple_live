import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';
import 'package:simple_live_tv_app/widgets/settings_item_widget.dart';

Widget playerControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  return buildControls(
    videoState,
    controller,
  );
}

Widget buildControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  return Stack(
    children: [
      Container(),
      buildDanmuView(videoState, controller),

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
              : -100.w,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 100.w,
            padding: EdgeInsets.only(
              left: 32.w,
              right: 32.w,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.transparent,
                  Colors.black87,
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${controller.detail.value?.title} - ${controller.detail.value?.userName}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.titleStyleWhite,
                  ),
                ),
                const Spacer(),
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
                colors: [
                  Colors.transparent,
                  Colors.black87,
                ],
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
                      () => Text("清晰度: ${controller.currentQualityInfo.value}",
                          style: AppStyle.textStyleWhite),
                    ),
                    //线路
                    AppStyle.hGap32,
                    Obx(
                      () => Text("线路：${controller.currentLineInfo.value}",
                          style: AppStyle.textStyleWhite),
                    ),
                  ],
                ),
                AppStyle.vGap12,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text(
                      "设置",
                      style: AppStyle.titleStyleWhite,
                    ),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_up_rounded,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text(
                      "上一频道",
                      style: AppStyle.titleStyleWhite,
                    ),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_down_rounded,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text(
                      "下一频道",
                      style: AppStyle.titleStyleWhite,
                    ),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_left_outlined,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text(
                      "关注列表",
                      style: AppStyle.titleStyleWhite,
                    ),
                    AppStyle.hGap32,
                    Icon(
                      Icons.arrow_circle_right_outlined,
                      color: Colors.white,
                      size: 40.w,
                    ),
                    AppStyle.hGap16,
                    Text(
                      "添加/取消关注",
                      style: AppStyle.titleStyleWhite,
                    ),
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

Widget buildDanmuView(VideoState videoState, LiveRoomController controller) {
  var padding = MediaQuery.of(videoState.context).padding;
  controller.danmakuView ??= DanmakuView(
    key: controller.globalDanmuKey,
    createdController: controller.initDanmakuController,
    option: DanmakuOption(
      fontSize: 40.w,
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
  var qualityFoucsNode = AppFocusNode()..isFoucsed.value = true;
  var lineFoucsNode = AppFocusNode();
  var scaleFoucsNode = AppFocusNode();
  var danmakuFoucsNode = AppFocusNode();
  Utils.showRightDialog(
    width: 800.w,
    useSystem: true,
    child: ListView(
      padding: AppStyle.edgeInsetsA48,
      children: [
        AppStyle.vGap12,
        // 清晰度切换
        Obx(
          () => SettingsItemWidget(
            title: "清晰度",
            foucsNode: qualityFoucsNode,
            autofocus: qualityFoucsNode.isFoucsed.value,
            items: controller.qualites
                .asMap()
                .map(
                  (i, e) => MapEntry(
                    i,
                    e.quality,
                  ),
                )
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
                .map(
                  (i, e) => MapEntry(
                    i,
                    "线路${i + 1}",
                  ),
                )
                .cast<int, String>(),
            value: controller.currentLineIndex,
            onChanged: (e) {
              Get.back();
              controller.changePlayLine(e);
            },
          ),
        ),
        AppStyle.vGap32,
        Obx(
          () => SettingsItemWidget(
            foucsNode: danmakuFoucsNode,
            autofocus: danmakuFoucsNode.isFoucsed.value,
            title: "弹幕开关",
            items: const {
              0: "关",
              1: "开",
            },
            value: controller.showDanmakuState.value ? 1 : 0,
            onChanged: (e) {
              controller.showDanmakuState.value = e == 1;
            },
          ),
        ),
        AppStyle.vGap32,
        Obx(
          () => SettingsItemWidget(
            foucsNode: scaleFoucsNode,
            autofocus: scaleFoucsNode.isFoucsed.value,
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
              controller.updateScaleMode();
            },
          ),
        ),
        // RadioListTile(
        //   value: 0,
        //   contentPadding: AppStyle.edgeInsetsH4,
        //   title: const Text("适应"),
        //   visualDensity: VisualDensity.compact,
        //   groupValue: AppSettingsController.instance.scaleMode.value,
        //   onChanged: (e) {
        //     AppSettingsController.instance.setScaleMode(e ?? 0);
        //     controller.updateScaleMode();
        //   },
        // ),
        // RadioListTile(
        //   value: 1,
        //   contentPadding: AppStyle.edgeInsetsH4,
        //   title: const Text("拉伸"),
        //   visualDensity: VisualDensity.compact,
        //   groupValue: AppSettingsController.instance.scaleMode.value,
        //   onChanged: (e) {
        //     AppSettingsController.instance.setScaleMode(e ?? 1);
        //     controller.updateScaleMode();
        //   },
        // ),
        // RadioListTile(
        //   value: 2,
        //   contentPadding: AppStyle.edgeInsetsH4,
        //   title: const Text("铺满"),
        //   visualDensity: VisualDensity.compact,
        //   groupValue: AppSettingsController.instance.scaleMode.value,
        //   onChanged: (e) {
        //     AppSettingsController.instance.setScaleMode(e ?? 2);
        //     controller.updateScaleMode();
        //   },
        // ),
        // RadioListTile(
        //   value: 3,
        //   contentPadding: AppStyle.edgeInsetsH4,
        //   title: const Text("16:9"),
        //   visualDensity: VisualDensity.compact,
        //   groupValue: AppSettingsController.instance.scaleMode.value,
        //   onChanged: (e) {
        //     AppSettingsController.instance.setScaleMode(e ?? 3);
        //     controller.updateScaleMode();
        //   },
        // ),
        // RadioListTile(
        //   value: 4,
        //   contentPadding: AppStyle.edgeInsetsH4,
        //   title: const Text("4:3"),
        //   visualDensity: VisualDensity.compact,
        //   groupValue: AppSettingsController.instance.scaleMode.value,
        //   onChanged: (e) {
        //     AppSettingsController.instance.setScaleMode(e ?? 4);
        //     controller.updateScaleMode();
        //   },
        // ),
      ],
    ),
  );
}

void showFollowUser(LiveRoomController controller) {
  Utils.showRightDialog(
    width: 800.w,
    useSystem: true,
    child: Obx(
      () => ListView.separated(
        itemCount: FollowUserService.instance.livingList.length,
        separatorBuilder: (context, index) => AppStyle.vGap32,
        padding: AppStyle.edgeInsetsA40.copyWith(left: 48.w, right: 48.w),
        itemBuilder: (_, i) {
          var item = FollowUserService.instance.livingList[i];
          var site = Sites.allSites[item.siteId]!;
          return AnchorCard(
            face: item.face,
            name: item.userName,
            siteId: item.siteId,
            liveStatus: item.liveStatus.value,
            roomId: item.roomId,
            autofocus: i == 0,
            onTap: () {
              controller.resetRoom(site, item.roomId);
              Get.back();
            },
          );
        },
      ),
    ),
  );
}
