import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:window_manager/window_manager.dart';

Widget playerControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  return Obx(() {
    if (controller.fullScreenState.value) {
      return buildFullControls(
        videoState,
        controller,
      );
    }
    return buildControls(
      videoState.context.orientation == Orientation.portrait,
      videoState,
      controller,
    );
  });
}

Widget buildFullControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  var padding = MediaQuery.of(videoState.context).padding;
  GlobalKey volumeButtonkey = GlobalKey();
  return DragToMoveArea(
    child: Stack(
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
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: controller.onTap,
            onDoubleTapDown: controller.onDoubleTap,
            onLongPress: () {
              if (controller.lockControlsState.value) {
                return;
              }
              showFollowUser(controller);
            },
            onVerticalDragStart: controller.onVerticalDragStart,
            onVerticalDragUpdate: controller.onVerticalDragUpdate,
            onVerticalDragEnd: controller.onVerticalDragEnd,
            child: MouseRegion(
              onHover: (PointerHoverEvent event) {
                controller.onHover(event, videoState.context);
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
                // child: Visibility(
                //   //拖拽区域
                //   visible: controller.smallWindowState.value,
                //   child: DragToMoveArea(
                //       child: Container(
                //     width: double.infinity,
                //     height: double.infinity,
                //     color: Colors.transparent,
                //   )),
                // ),
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
                : -(48 + padding.top),
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 48 + padding.top,
              padding: EdgeInsets.only(
                left: padding.left + 12,
                right: padding.right + 12,
                top: padding.top,
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
                  IconButton(
                    onPressed: () {
                      if (controller.smallWindowState.value) {
                        controller.exitSmallWindow();
                      } else {
                        controller.exitFull();
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: Text(
                      "${controller.detail.value?.title} - ${controller.detail.value?.userName}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  AppStyle.hGap12,
                  IconButton(
                    onPressed: () {
                      controller.saveScreenshot();
                    },
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showFollowUser(controller);
                    },
                    icon: const Icon(
                      Remix.play_list_2_line,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Visibility(
                    visible: Platform.isAndroid,
                    child: IconButton(
                      onPressed: () {
                        controller.enablePIP();
                      },
                      icon: const Icon(
                        Icons.picture_in_picture,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showPlayerSettings(controller);
                    },
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 24,
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
                : -(80 + padding.bottom),
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
                left: padding.left + 12,
                right: padding.right + 12,
                bottom: padding.bottom,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      controller.refreshRoom();
                    },
                    icon: const Icon(
                      Remix.refresh_line,
                      color: Colors.white,
                    ),
                  ),
                  Offstage(
                    offstage: controller.showDanmakuState.value,
                    child: IconButton(
                      onPressed: () => controller.showDanmakuState.value =
                          !controller.showDanmakuState.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_open.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !controller.showDanmakuState.value,
                    child: IconButton(
                      onPressed: () => controller.showDanmakuState.value =
                          !controller.showDanmakuState.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_close.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showDanmakuSettings(controller);
                    },
                    icon: const ImageIcon(
                      AssetImage('assets/icons/icon_danmaku_setting.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(child: Center()),
                  Visibility(
                    visible: !Platform.isAndroid && !Platform.isIOS,
                    child: IconButton(
                      key: volumeButtonkey,
                      onPressed: () {
                        controller
                            .showVolumeSlider(volumeButtonkey.currentContext!);
                      },
                      icon: const Icon(
                        Icons.volume_down,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showQualitesInfo(controller);
                    },
                    child: Obx(
                      () => Text(
                        controller.currentQualityInfo.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showLinesInfo(controller);
                    },
                    child: Text(
                      controller.currentLineInfo.value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (controller.smallWindowState.value) {
                        controller.exitSmallWindow();
                      } else {
                        controller.exitFull();
                      }
                    },
                    icon: const Icon(
                      Remix.fullscreen_exit_fill,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 右侧锁定
        Obx(
          () => AnimatedPositioned(
            top: 0,
            bottom: 0,
            right: controller.showControlsState.value
                ? padding.right + 12
                : -(64 + padding.right),
            duration: const Duration(milliseconds: 200),
            child: buildLockButton(controller),
          ),
        ),
        // 左侧锁定
        Obx(
          () => AnimatedPositioned(
            top: 0,
            bottom: 0,
            left: controller.showControlsState.value
                ? padding.left + 12
                : -(64 + padding.right),
            duration: const Duration(milliseconds: 200),
            child: buildLockButton(controller),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: !controller.showGestureTip.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.gestureTipText.value,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildLockButton(LiveRoomController controller) {
  return Center(
    child: InkWell(
      onTap: () {
        controller.setLockState();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: AppStyle.radius8,
        ),
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            controller.lockControlsState.value
                ? Icons.lock_outline_rounded
                : Icons.lock_open_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    ),
  );
}

Widget buildControls(
  bool isPortrait,
  VideoState videoState,
  LiveRoomController controller,
) {
  GlobalKey volumeButtonkey = GlobalKey();
  return Stack(
    children: [
      Container(),
      buildDanmuView(videoState, controller),
      // 中间
      Center(
        child: StreamBuilder(
          stream: videoState.widget.controller.player.stream.buffering,
          initialData: videoState.widget.controller.player.state.buffering,
          builder: (_, s) => Visibility(
            visible: s.data ?? false,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          onTap: controller.onTap,
          onDoubleTapDown: controller.onDoubleTap,
          onVerticalDragStart: controller.onVerticalDragStart,
          onVerticalDragUpdate: controller.onVerticalDragUpdate,
          onVerticalDragEnd: controller.onVerticalDragEnd,
          //onLongPress: controller.showDebugInfo,
          child: MouseRegion(
            onEnter: controller.onEnter,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),
      ),
      Obx(
        () => AnimatedPositioned(
          left: 0,
          right: 0,
          bottom: controller.showControlsState.value ? 0 : -48,
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
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    controller.refreshRoom();
                  },
                  icon: const Icon(
                    Remix.refresh_line,
                    color: Colors.white,
                  ),
                ),
                Offstage(
                  offstage: controller.showDanmakuState.value,
                  child: IconButton(
                    onPressed: () => controller.showDanmakuState.value =
                        !controller.showDanmakuState.value,
                    icon: const ImageIcon(
                      AssetImage('assets/icons/icon_danmaku_open.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
                Offstage(
                  offstage: !controller.showDanmakuState.value,
                  child: IconButton(
                    onPressed: () => controller.showDanmakuState.value =
                        !controller.showDanmakuState.value,
                    icon: const ImageIcon(
                      AssetImage('assets/icons/icon_danmaku_close.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.showDanmuSettingsSheet();
                  },
                  icon: const ImageIcon(
                    AssetImage('assets/icons/icon_danmaku_setting.png'),
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const Expanded(child: Center()),
                Visibility(
                  visible: !Platform.isAndroid && !Platform.isIOS,
                  child: IconButton(
                    key: volumeButtonkey,
                    onPressed: () {
                      controller.showVolumeSlider(
                        volumeButtonkey.currentContext!,
                      );
                    },
                    icon: const Icon(
                      Icons.volume_down,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
                Offstage(
                  offstage: isPortrait,
                  child: TextButton(
                    onPressed: () {
                      controller.showQualitySheet();
                    },
                    child: Obx(
                      () => Text(
                        controller.currentQualityInfo.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ),
                Offstage(
                  offstage: isPortrait,
                  child: TextButton(
                    onPressed: () {
                      controller.showPlayUrlsSheet();
                    },
                    child: Text(
                      controller.currentLineInfo.value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
                Visibility(
                  visible: !Platform.isAndroid && !Platform.isIOS,
                  child: IconButton(
                    onPressed: () {
                      controller.enterSmallWindow();
                    },
                    icon: const Icon(
                      Icons.picture_in_picture,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.enterFullScreen();
                  },
                  icon: const Icon(
                    Remix.fullscreen_line,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Obx(
        () => Offstage(
          offstage: !controller.showGestureTip.value,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                controller.gestureTipText.value,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
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
      fontSize: 16,
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

void showLinesInfo(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showPlayUrlsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "线路",
    useSystem: true,
    child: ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: controller.playUrls.length,
      itemBuilder: (_, i) {
        return ListTile(
          selected: controller.currentLineIndex == i,
          title: Text.rich(
            TextSpan(
              text: "线路${i + 1}",
              children: [
                WidgetSpan(
                    child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppStyle.radius4,
                    border: Border.all(
                      color: Colors.grey,
                    ),
                  ),
                  padding: AppStyle.edgeInsetsH4,
                  margin: AppStyle.edgeInsetsL8,
                  child: Text(
                    controller.playUrls[i].contains(".flv") ? "FLV" : "HLS",
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                )),
              ],
            ),
            style: const TextStyle(fontSize: 14),
          ),
          minLeadingWidth: 16,
          onTap: () {
            Utils.hideRightDialog();
            //controller.currentLineIndex = i;
            //controller.setPlayer();
            controller.changePlayLine(i);
          },
        );
      },
    ),
  );
}

void showQualitesInfo(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showQualitySheet();
    return;
  }
  Utils.showRightDialog(
    title: "清晰度",
    useSystem: true,
    child: ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: controller.qualites.length,
      itemBuilder: (_, i) {
        var item = controller.qualites[i];
        return ListTile(
          selected: controller.currentQuality == i,
          title: Text(
            item.quality,
            style: const TextStyle(fontSize: 14),
          ),
          minLeadingWidth: 16,
          onTap: () {
            Utils.hideRightDialog();
            controller.currentQuality = i;
            controller.getPlayUrl();
          },
        );
      },
    ),
  );
}

void showDanmakuSettings(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showDanmuSettingsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "弹幕设置",
    width: 400,
    useSystem: true,
    child: ListView(
      padding: AppStyle.edgeInsetsA12,
      children: [
        DanmuSettingsView(
          danmakuController: controller.danmakuController,
        ),
      ],
    ),
  );
}

void showPlayerSettings(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showPlayerSettingsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "设置",
    width: 320,
    useSystem: true,
    child: Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsH16,
            child: Text(
              "画面尺寸",
              style: Get.textTheme.titleMedium,
            ),
          ),
          RadioListTile(
            value: 0,
            contentPadding: AppStyle.edgeInsetsH4,
            title: const Text("适应"),
            visualDensity: VisualDensity.compact,
            groupValue: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e ?? 0);
              controller.updateScaleMode();
            },
          ),
          RadioListTile(
            value: 1,
            contentPadding: AppStyle.edgeInsetsH4,
            title: const Text("拉伸"),
            visualDensity: VisualDensity.compact,
            groupValue: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e ?? 1);
              controller.updateScaleMode();
            },
          ),
          RadioListTile(
            value: 2,
            contentPadding: AppStyle.edgeInsetsH4,
            title: const Text("铺满"),
            visualDensity: VisualDensity.compact,
            groupValue: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e ?? 2);
              controller.updateScaleMode();
            },
          ),
          RadioListTile(
            value: 3,
            contentPadding: AppStyle.edgeInsetsH4,
            title: const Text("16:9"),
            visualDensity: VisualDensity.compact,
            groupValue: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e ?? 3);
              controller.updateScaleMode();
            },
          ),
          RadioListTile(
            value: 4,
            contentPadding: AppStyle.edgeInsetsH4,
            title: const Text("4:3"),
            visualDensity: VisualDensity.compact,
            groupValue: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e ?? 4);
              controller.updateScaleMode();
            },
          ),
        ],
      ),
    ),
  );
}

void showFollowUser(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showFollowUserSheet();
    return;
  }

  Utils.showRightDialog(
    title: "关注列表",
    width: 400,
    useSystem: true,
    child: Obx(
      () => Stack(
        children: [
          RefreshIndicator(
            onRefresh: FollowService.instance.loadData,
            child: ListView.builder(
              itemCount: FollowService.instance.liveList.length,
              itemBuilder: (_, i) {
                var item = FollowService.instance.liveList[i];
                return Obx(
                  () => FollowUserItem(
                    item: item,
                    playing: controller.rxSite.value.id == item.siteId &&
                        controller.rxRoomId.value == item.roomId,
                    onTap: () {
                      Utils.hideRightDialog();
                      controller.resetRoom(
                        Sites.allSites[item.siteId]!,
                        item.roomId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            Positioned(
              right: 12,
              bottom: 12,
              child: Obx(
                () => DesktopRefreshButton(
                  refreshing: FollowService.instance.updating.value,
                  onPressed: FollowService.instance.loadData,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
