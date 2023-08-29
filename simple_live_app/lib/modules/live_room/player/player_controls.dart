import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/live_room/live_room_new_controller.dart';

Widget playerControls(
  VideoState videoState,
  LiveRoomNewController controller,
) {
  return Obx(() {
    if (controller.fullScreenState.value) {
      return buildFullControls(
        videoState,
        controller,
      );
    }
    return OrientationBuilder(
      builder: (context, orientation) {
        Log.d(orientation.toString());
        return buildControls(
          orientation == Orientation.portrait,
          videoState,
          controller,
        );
      },
    );
  });
}

Widget buildFullControls(
  VideoState videoState,
  LiveRoomNewController controller,
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
          top: controller.showControlsState.value ? 0 : -48,
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
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Text(
                    "${controller.detail.value?.title} - ${controller.detail.value?.userName}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                IconButton(
                  onPressed: () {
                    controller.showDanmakuSettingState.value = true;
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
          bottom: controller.showControlsState.value ? 0 : -80,
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
                    controller.showDanmakuSettingState.value = true;
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
                    controller.showQualites.value = true;
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
                    controller.showLines.value = true;
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
      //清晰度
      Obx(
        () => AnimatedPositioned(
          right: controller.showQualites.value ? 0 : -200,
          top: 0,
          bottom: 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 200,
            color: Colors.grey.shade900,
            padding: EdgeInsets.only(right: padding.right),
            child: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.zero),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: controller.qualites.length,
                itemBuilder: (_, i) {
                  var item = controller.qualites[i];
                  return ListTile(
                    selected: controller.currentQuality == i,
                    textColor: Colors.white,
                    title: Text(
                      item.quality,
                      style: const TextStyle(fontSize: 14),
                    ),
                    minLeadingWidth: 16,
                    onTap: () {
                      controller.showQualites.value = false;
                      controller.currentQuality = i;
                      controller.getPlayUrl();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
      //线路
      Obx(
        () => AnimatedPositioned(
          right: controller.showLines.value ? 0 : -200,
          top: 0,
          bottom: 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 200,
            color: Colors.grey.shade900,
            padding: EdgeInsets.only(right: padding.right),
            child: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.zero),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: controller.playUrls.length,
                itemBuilder: (_, i) {
                  return ListTile(
                    selected: controller.currentUrl == i,
                    textColor: Colors.white,
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
                              controller.playUrls[i].contains(".flv")
                                  ? "FLV"
                                  : "HLS",
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
                      controller.showLines.value = false;
                      controller.currentUrl = i;
                      controller.setPlayer();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
      //设置
      Obx(
        () => AnimatedPositioned(
          right: controller.showDanmakuSettingState.value ? 0 : -400,
          top: 0,
          bottom: 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 400,
            color: Colors.grey.shade900,
            padding: EdgeInsets.only(right: padding.right),
            child: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.zero),
              child: Obx(
                () => ListView(
                  padding: AppStyle.edgeInsetsV12,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "弹幕区域: ${(AppSettingsController.instance.danmuArea.value * 100).toInt()}%",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: AppSettingsController.instance.danmuArea.value,
                      max: 1.0,
                      min: 0.1,
                      onChanged: (e) {
                        AppSettingsController.instance.setDanmuArea(e);
                        controller.updateDanmuOption(
                          controller.danmakuController?.option
                              .copyWith(area: e),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "不透明度: ${(AppSettingsController.instance.danmuOpacity.value * 100).toInt()}%",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: AppSettingsController.instance.danmuOpacity.value,
                      max: 1.0,
                      min: 0.1,
                      onChanged: (e) {
                        AppSettingsController.instance.setDanmuOpacity(e);
                        controller.updateDanmuOption(
                          controller.danmakuController?.option
                              .copyWith(opacity: e),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "弹幕大小: ${(AppSettingsController.instance.danmuSize.value).toInt()}",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: AppSettingsController.instance.danmuSize.value,
                      min: 8,
                      max: 36,
                      onChanged: (e) {
                        AppSettingsController.instance.setDanmuSize(e);
                        controller.updateDanmuOption(
                          controller.danmakuController?.option
                              .copyWith(fontSize: e),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "弹幕速度: ${(AppSettingsController.instance.danmuSpeed.value).toInt()} (越小越快)",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: AppSettingsController.instance.danmuSpeed.value,
                      min: 4,
                      max: 20,
                      onChanged: (e) {
                        AppSettingsController.instance.setDanmuSpeed(e);
                        controller.updateDanmuOption(
                          controller.danmakuController?.option
                              .copyWith(duration: e),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "弹幕描边: ${(AppSettingsController.instance.danmuStrokeWidth.value).toInt()}",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Slider(
                      value:
                          AppSettingsController.instance.danmuStrokeWidth.value,
                      min: 0,
                      max: 10,
                      onChanged: (e) {
                        AppSettingsController.instance.setDanmuStrokeWidth(e);
                        controller.updateDanmuOption(
                          controller.danmakuController?.option
                              .copyWith(strokeWidth: e),
                        );
                      },
                    ),
                  ],
                ),
              ),
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

Widget buildControls(
  bool isPortrait,
  VideoState videoState,
  LiveRoomNewController controller,
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
                    controller.showBottomDanmuSettings();
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

Widget buildDanmuView(LiveRoomNewController controller) {
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
