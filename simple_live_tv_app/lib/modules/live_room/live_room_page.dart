import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_tv_app/modules/live_room/player/player_controls.dart';

class LiveRoomPage extends GetView<LiveRoomController> {
  const LiveRoomPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          requestExitPlayer();
        }
      },
      child: KeyboardListener(
        focusNode: controller.focusNode,
        autofocus: true,
        onKeyEvent: onKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Obx(
            () => buildMediaPlayer(),
          ),
        ),
      ),
    );
  }

  void onKeyEvent(KeyEvent key) {
    if (key is KeyUpEvent) {
      return;
    }
    Log.logPrint(key);

    if (key.logicalKey == LogicalKeyboardKey.escape ||
        key.logicalKey == LogicalKeyboardKey.backspace ||
        key.logicalKey == LogicalKeyboardKey.goBack ||
        key.logicalKey == LogicalKeyboardKey.browserBack) {
      requestExitPlayer();
      return;
    }
    // 遥控器媒体键：播放/暂停
    if (key.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
      controller.togglePlayPause();
      return;
    }
    if (key.logicalKey == LogicalKeyboardKey.mediaPlay) {
      if (controller.userPaused.value) {
        controller.togglePlayPause();
      }
      return;
    }
    if (key.logicalKey == LogicalKeyboardKey.mediaPause) {
      if (!controller.userPaused.value) {
        controller.togglePlayPause();
      }
      return;
    }
    // 点击OK、Enter、Select键时显示/隐藏控制器
    if (key.logicalKey == LogicalKeyboardKey.select ||
        key.logicalKey == LogicalKeyboardKey.enter ||
        key.logicalKey == LogicalKeyboardKey.space) {
      if (!controller.showControlsState.value) {
        controller.showControls();
      } else {
        controller.hideControls();
      }
      return;
    }

    if (controller.handleKeyboardShortcut(key.logicalKey)) {
      return;
    }

    // 点击Menu打开/关闭设置
    if (key.logicalKey == LogicalKeyboardKey.contextMenu ||
        key.logicalKey == LogicalKeyboardKey.arrowRight) {
      showPlayerSettings(controller);
      return;
    }

    // 点击左键显示关注用户
    if (key.logicalKey == LogicalKeyboardKey.arrowLeft) {
      showFollowUser(controller);
      return;
    }

    // // 点击右键关注/取消关注
    // if (key.logicalKey == LogicalKeyboardKey.arrowRight) {
    //   if (controller.followed.value) {
    //     controller.removeFollowUser();
    //   } else {
    //     controller.followUser();
    //   }

    //   return;
    // }

    // 点击上键切换上一个直播
    if (key.logicalKey == LogicalKeyboardKey.arrowUp) {
      controller.prevChannel();
      return;
    }

    // 点击下键切换下一个直播
    if (key.logicalKey == LogicalKeyboardKey.arrowDown) {
      controller.nextChannel();
      return;
    }
  }

  void requestExitPlayer() {
    // 双击返回键退出：第一次只提示，第二次才退出。
    if (controller.doubleClickExit) {
      controller.doubleClickTimer?.cancel();
      controller.doubleClickTimer = null;
      controller.doubleClickExit = false;
      SmartDialog.dismiss();
      Get.back();
      return;
    }
    controller.doubleClickExit = true;
    SmartDialog.dismiss();
    SmartDialog.showToast("再按一次退出播放器");
    controller.doubleClickTimer?.cancel();
    controller.doubleClickTimer = Timer(const Duration(seconds: 2), () {
      controller.doubleClickExit = false;
      controller.doubleClickTimer = null;
    });
  }

  Widget buildMediaPlayer() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    return Stack(
      children: [
        Video(
          key: controller.globalPlayerKey,
          controller: controller.videoController,
          pauseUponEnteringBackgroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          resumeUponEnteringForegroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          controls: (state) {
            return playerControls(state, controller);
          },
          aspectRatio: aspectRatio,
          fit: boxFit,
        ),
        // 暂停状态提示
        Obx(
          () => Visibility(
            visible: controller.userPaused.value &&
                !controller.pageLoadding.value &&
                controller.playbackLoadError.value.isEmpty,
            child: Center(
              child: Container(
                padding: AppStyle.edgeInsetsA24,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pause_circle_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    AppStyle.vGap12,
                    Text(
                      "已暂停 · 按播放键继续",
                      style: AppStyle.textStyleWhite,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Obx(
          () => Visibility(
            visible:
                !controller.liveStatus.value && !controller.pageLoadding.value,
            child: Center(
              child: Text(
                "未开播",
                style: AppStyle.textStyleWhite,
              ),
            ),
          ),
        ),
        if (controller.playbackLoadError.value.isNotEmpty)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: AppStyle.edgeInsetsA24,
              color: Colors.black87,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.playbackLoadError.value,
                    textAlign: TextAlign.center,
                    style: AppStyle.textStyleWhite,
                  ),
                  AppStyle.vGap16,
                  ElevatedButton.icon(
                    autofocus: true,
                    onPressed: controller.refreshRoom,
                    icon: const Icon(Icons.refresh),
                    label: const Text("重试"),
                  ),
                ],
              ),
            ),
          ),
        Obx(
          () => Visibility(
            visible: controller.autoExitEnable.value,
            child: Positioned(
              right: 24,
              top: 24,
              child: Text(
                "${parseDuration(controller.countdown.value)}后自动关闭",
                style: AppStyle.textStyleWhite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String parseDuration(int duration) {
    int hours = duration ~/ 3600;
    int minutes = duration % 3600 ~/ 60;
    int seconds = duration % 60;

    return "${hours.toString().padLeft(2, '0')}:"
        "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}";
  }
}
