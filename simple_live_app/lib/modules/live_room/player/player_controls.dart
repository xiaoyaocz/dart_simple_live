import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';

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
  return Stack(
    children: [
      Container(),
      buildDanmuView(controller),

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
          onVerticalDragStart: controller.onVerticalDragStart,
          onVerticalDragUpdate: controller.onVerticalDragUpdate,
          onVerticalDragEnd: controller.onVerticalDragEnd,
          onLongPress: controller.showDebugInfo,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
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
              : -48,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 48,
            padding: EdgeInsets.only(
              left: padding.left + 12,
              right: padding.right + 12,
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
                  onPressed: Get.back,
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
              : -80,
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
                TextButton(
                  onPressed: () {
                    showQualitesInfo(controller);
                  },
                  child: Obx(
                    () => Text(
                      controller.currentQualityInfo.value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    showLinesInfo(controller);
                  },
                  child: Text(
                    controller.currentUrlInfo.value,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.exitFull();
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
  return Stack(
    children: [
      Container(),
      buildDanmuView(controller),
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
          onVerticalDragStart: controller.onVerticalDragStart,
          onVerticalDragUpdate: controller.onVerticalDragUpdate,
          onVerticalDragEnd: controller.onVerticalDragEnd,
          onLongPress: controller.showDebugInfo,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
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
                      controller.currentUrlInfo.value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
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

Widget buildDanmuView(LiveRoomController controller) {
  controller.danmakuView ??= DanmakuView(
    key: controller.globalDanmuKey,
    createdController: controller.initDanmakuController,
    option: DanmakuOption(
      fontSize: 16,
    ),
  );
  return Positioned.fill(
    child: Obx(
      () => Offstage(
        offstage: !controller.showDanmakuState.value,
        child: controller.danmakuView!,
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
          selected: controller.currentUrl == i,
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
            controller.currentUrl = i;
            controller.setPlayer();
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
    child: Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕区域: ${(AppSettingsController.instance.danmuArea.value * 100).toInt()}%",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuArea.value,
            max: 1.0,
            min: 0.1,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuArea(e);
              controller.updateDanmuOption(
                controller.danmakuController?.option.copyWith(area: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "不透明度: ${(AppSettingsController.instance.danmuOpacity.value * 100).toInt()}%",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuOpacity.value,
            max: 1.0,
            min: 0.1,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuOpacity(e);
              controller.updateDanmuOption(
                controller.danmakuController?.option.copyWith(opacity: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕大小: ${(AppSettingsController.instance.danmuSize.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuSize.value,
            min: 8,
            max: 36,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuSize(e);
              controller.updateDanmuOption(
                controller.danmakuController?.option.copyWith(fontSize: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕速度: ${(AppSettingsController.instance.danmuSpeed.value).toInt()} (越小越快)",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuSpeed.value,
            min: 4,
            max: 20,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuSpeed(e);
              controller.updateDanmuOption(
                controller.danmakuController?.option.copyWith(duration: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕描边: ${(AppSettingsController.instance.danmuStrokeWidth.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuStrokeWidth.value,
            min: 0,
            max: 10,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuStrokeWidth(e);
              controller.updateDanmuOption(
                controller.danmakuController?.option.copyWith(strokeWidth: e),
              );
            },
          ),
        ],
      ),
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
            },
          ),
        ],
      ),
    ),
  );
}
