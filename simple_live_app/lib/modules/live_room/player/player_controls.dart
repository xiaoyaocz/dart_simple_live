import 'dart:async';
import 'dart:io';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';
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

EdgeInsets _fullScreenControlPadding(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  if (Platform.isIOS && mediaQuery.orientation == Orientation.landscape) {
    final padding = mediaQuery.viewPadding;
    return EdgeInsets.only(left: padding.left, right: padding.right);
  }
  return mediaQuery.padding;
}

Widget buildFullControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  final padding = _fullScreenControlPadding(videoState.context);
  final volumeButtonKey = GlobalKey();
  final controls = _buildPlayerMouseRegion(
    videoState: videoState,
    controller: controller,
    child: Stack(
      children: [
        const SizedBox.expand(),
        buildDanmuView(videoState, controller),
        _buildPlayerSuperChatOverlay(controller),
        _buildBufferingIndicator(videoState),
        _buildGestureLayer(
          controller,
          enableQuickAccessLongPress: true,
        ),
        _buildLiveSubtitleOverlay(videoState.context, controller),
        _buildFullTopBar(
          controller,
          padding: padding,
        ),
        _buildFullBottomBar(
          controller,
          padding: padding,
          volumeButtonKey: volumeButtonKey,
        ),
        _buildSideLockButton(
          controller,
          padding: padding,
          alignLeft: false,
        ),
        _buildSideLockButton(
          controller,
          padding: padding,
          alignLeft: true,
        ),
        _buildGestureTip(controller),
      ],
    ),
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return DragToMoveArea(child: controls);
  }
  return controls;
}

Widget buildLockButton(LiveRoomController controller) {
  return Obx(
    () => Center(
      child: InkWell(
        onTap: controller.setLockState,
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
    ),
  );
}

Widget buildControls(
  bool isPortrait,
  VideoState videoState,
  LiveRoomController controller,
) {
  final volumeButtonKey = GlobalKey();
  return _buildPlayerMouseRegion(
    videoState: videoState,
    controller: controller,
    child: Stack(
      children: [
        const SizedBox.expand(),
        buildDanmuView(videoState, controller),
        _buildPlayerSuperChatOverlay(controller),
        _buildBufferingIndicator(videoState),
        _buildGestureLayer(controller),
        _buildLiveSubtitleOverlay(videoState.context, controller),
        _buildNormalBottomBar(
          controller,
          isPortrait: isPortrait,
          volumeButtonKey: volumeButtonKey,
        ),
        _buildGestureTip(controller),
      ],
    ),
  );
}

Widget _buildPlayerMouseRegion({
  required VideoState videoState,
  required LiveRoomController controller,
  required Widget child,
}) {
  return Obx(
    () => MouseRegion(
      cursor: controller.hideMouseCursorState.value
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      onEnter: controller.onEnter,
      onExit: controller.onExit,
      onHover: (event) {
        controller.resetHideMouseCursorTimer();
        controller.showMouseCursor();
        controller.onHover(event, videoState.context);
      },
      child: child,
    ),
  );
}

Widget _buildPlayerSuperChatOverlay(LiveRoomController controller) {
  return Obx(() {
    if (!AppSettingsController.instance.playershowSuperChat.value) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 24,
      bottom: 24,
      child: PlayerSuperChatOverlay(controller: controller),
    );
  });
}

Widget _buildLiveSubtitleOverlay(
  BuildContext _,
  LiveRoomController controller,
) =>
    _LiveSubtitleOverlay(controller: controller);

class _LiveSubtitleOverlay extends StatefulWidget {
  final LiveRoomController controller;

  const _LiveSubtitleOverlay({
    required this.controller,
  });

  @override
  State<_LiveSubtitleOverlay> createState() => _LiveSubtitleOverlayState();
}

class _LiveSubtitleOverlayState extends State<_LiveSubtitleOverlay> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!LiveSubtitleService.instance.uiEnabled) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final controller = widget.controller;
      final settings = AppSettingsController.instance;
      if (!settings.liveSubtitleEnable.value ||
          settings.liveSubtitleModelPath.value.trim().isEmpty ||
          LiveSubtitleService.instance.subtitleText.value.trim().isEmpty) {
        return const SizedBox.shrink();
      }

      final mediaQuery = MediaQuery.of(context);
      final padding = controller.fullScreenState.value
          ? _fullScreenControlPadding(context)
          : mediaQuery.padding;
      final alignment = Alignment(
        settings.liveSubtitleOffsetX.value * 2 - 1,
        settings.liveSubtitleOffsetY.value * 2 - 1,
      );
      final positionedPadding = EdgeInsets.only(
        left: padding.left + 24,
        right: padding.right + 24,
        top: padding.top + 24,
        bottom: padding.bottom + 24,
      );
      final subtitleColor = Color(settings.liveSubtitleColor.value);
      final locked = settings.liveSubtitlePositionLocked.value;
      final showUnlockButton = locked && _hovering;

      return Positioned.fill(
        child: Padding(
          padding: positionedPadding,
          child: Align(
            alignment: alignment,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onLongPress: locked
                    ? () {
                        settings.setLiveSubtitlePositionLocked(false);
                        SmartDialog.showToast("字幕位置已解锁");
                      }
                    : null,
                onPanUpdate: locked
                    ? null
                    : (details) {
                        final size = mediaQuery.size;
                        if (size.width <= 0 || size.height <= 0) {
                          return;
                        }
                        settings.setLiveSubtitleOffset(
                          x: settings.liveSubtitleOffsetX.value +
                              details.delta.dx / size.width,
                          y: settings.liveSubtitleOffsetY.value +
                              details.delta.dy / size.height,
                        );
                      },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: settings.liveSubtitleBackgroundEnable.value
                              ? Colors.black.withAlpha(140)
                              : Colors.transparent,
                          borderRadius: AppStyle.radius8,
                        ),
                        child: Padding(
                          padding: AppStyle.edgeInsetsA8,
                          child: Text(
                            LiveSubtitleService.instance.subtitleText.value,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: settings.liveSubtitleFontSize.value,
                              fontWeight:
                                  settings.liveSubtitleResolvedFontWeight,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showUnlockButton)
                      Positioned(
                        right: -12,
                        top: -12,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              settings.setLiveSubtitlePositionLocked(false);
                              SmartDialog.showToast("字幕位置已解锁");
                            },
                            child: const SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.lock_open_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

Widget _buildBufferingIndicator(VideoState videoState) {
  return Center(
    child: StreamBuilder<bool>(
      stream: videoState.widget.controller.player.stream.buffering,
      initialData: videoState.widget.controller.player.state.buffering,
      builder: (_, snapshot) {
        if (!(snapshot.data ?? false)) {
          return const SizedBox.shrink();
        }
        return const CircularProgressIndicator();
      },
    ),
  );
}

Widget _buildGestureLayer(
  LiveRoomController controller, {
  bool enableQuickAccessLongPress = false,
}) {
  return Positioned.fill(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : Get.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : Get.height,
        );
        return Obx(() {
          final gestureEnabled =
              AppSettingsController.instance.playerGestureControlEnable.value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.onTap,
            onDoubleTap: controller.onDoubleTap,
            onLongPress: !enableQuickAccessLongPress
                ? null
                : () {
                    if (controller.lockControlsState.value) {
                      return;
                    }
                    showQuickAccess(controller);
                  },
            onVerticalDragStart: gestureEnabled
                ? (details) => controller.onVerticalDragStart(
                      details,
                      viewportSize: viewportSize,
                    )
                : null,
            onVerticalDragUpdate:
                gestureEnabled ? controller.onVerticalDragUpdate : null,
            onVerticalDragEnd:
                gestureEnabled ? controller.onVerticalDragEnd : null,
            onVerticalDragCancel:
                gestureEnabled ? controller.onVerticalDragCancel : null,
            child: const SizedBox.expand(),
          );
        });
      },
    ),
  );
}

Widget _buildFullTopBar(
  LiveRoomController controller, {
  required EdgeInsets padding,
}) {
  return Obx(() {
    final visible = controller.showControlsState.value &&
        !controller.lockControlsState.value;
    final detail = controller.detail.value;
    final title = detail?.title ?? "直播间";
    final userName = detail?.userName ?? "";
    final displayTitle = userName.isEmpty ? title : "$title - $userName";

    return AnimatedPositioned(
      left: 0,
      right: 0,
      top: visible ? 0 : -(48 + padding.top),
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
                displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            AppStyle.hGap12,
            IconButton(
              onPressed: controller.saveScreenshot,
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            IconButton(
              onPressed: () => showQuickAccess(controller),
              icon: const Icon(
                Remix.play_list_2_line,
                color: Colors.white,
                size: 24,
              ),
            ),
            if (Platform.isAndroid)
              IconButton(
                onPressed: controller.enablePIP,
                icon: const Icon(
                  Icons.picture_in_picture,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            IconButton(
              onPressed: () => showPlayerSettings(controller),
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  });
}

Widget _buildFullBottomBar(
  LiveRoomController controller, {
  required EdgeInsets padding,
  required GlobalKey volumeButtonKey,
}) {
  return Obx(() {
    final visible = controller.showControlsState.value &&
        !controller.lockControlsState.value;
    final showDanmaku = controller.showDanmakuState.value;

    return AnimatedPositioned(
      left: 0,
      right: 0,
      bottom: visible ? 0 : -(80 + padding.bottom),
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
              onPressed: controller.refreshRoom,
              icon: const Icon(
                Remix.refresh_line,
                color: Colors.white,
              ),
            ),
            // 播放/暂停按钮
            Obx(() => IconButton(
              onPressed: controller.togglePlayPause,
              icon: Icon(
                controller.player.state.playing
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 24,
                color: Colors.white,
              ),
            )),
            IconButton(
              onPressed: () {
                controller.setDanmakuVisible(!showDanmaku);
              },
              icon: ImageIcon(
                AssetImage(
                  showDanmaku
                      ? 'assets/icons/icon_danmaku_close.png'
                      : 'assets/icons/icon_danmaku_open.png',
                ),
                size: 24,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () => showDanmakuSettings(controller),
              icon: const ImageIcon(
                AssetImage('assets/icons/icon_danmaku_setting.png'),
                size: 24,
                color: Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                controller.liveDuration.value,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const Expanded(child: SizedBox()),
            if (!Platform.isAndroid && !Platform.isIOS)
              IconButton(
                key: volumeButtonKey,
                onPressed: () {
                  final context = volumeButtonKey.currentContext;
                  if (context == null) {
                    return;
                  }
                  controller.showVolumeSlider(
                    context,
                    keepAlive: true,
                  );
                },
                icon: Icon(
                  controller.mutedState.value
                      ? Icons.volume_off
                      : Icons.volume_down,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            IconButton(
              onPressed: controller.toggleMute,
              icon: Icon(
                controller.mutedState.value
                    ? Icons.volume_off
                    : Icons.volume_up,
                size: 24,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () => showQualitesInfo(controller),
              child: Text(
                controller.currentQualityInfo.value,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            TextButton(
              onPressed: () => showLinesInfo(controller),
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
    );
  });
}

Widget _buildNormalBottomBar(
  LiveRoomController controller, {
  required bool isPortrait,
  required GlobalKey volumeButtonKey,
}) {
  return Obx(() {
    final showDanmaku = controller.showDanmakuState.value;
    return AnimatedPositioned(
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
              onPressed: controller.refreshRoom,
              icon: const Icon(
                Remix.refresh_line,
                color: Colors.white,
              ),
            ),
            // 播放/暂停按钮
            Obx(() => IconButton(
              onPressed: controller.togglePlayPause,
              icon: Icon(
                controller.player.state.playing
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 24,
                color: Colors.white,
              ),
            )),
            IconButton(
              onPressed: () {
                controller.setDanmakuVisible(!showDanmaku);
              },
              icon: ImageIcon(
                AssetImage(
                  showDanmaku
                      ? 'assets/icons/icon_danmaku_close.png'
                      : 'assets/icons/icon_danmaku_open.png',
                ),
                size: 24,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () => showDanmakuSettings(controller),
              icon: const ImageIcon(
                AssetImage('assets/icons/icon_danmaku_setting.png'),
                size: 24,
                color: Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                controller.liveDuration.value,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const Expanded(child: SizedBox()),
            if (!Platform.isAndroid && !Platform.isIOS)
              IconButton(
                key: volumeButtonKey,
                onPressed: () {
                  final context = volumeButtonKey.currentContext;
                  if (context == null) {
                    return;
                  }
                  controller.showVolumeSlider(
                    context,
                    keepAlive: true,
                  );
                },
                icon: Icon(
                  controller.mutedState.value
                      ? Icons.volume_off
                      : Icons.volume_down,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            IconButton(
              onPressed: controller.toggleMute,
              icon: Icon(
                controller.mutedState.value
                    ? Icons.volume_off
                    : Icons.volume_up,
                size: 24,
                color: Colors.white,
              ),
            ),
            if (!isPortrait)
              TextButton(
                onPressed: () => showQualitesInfo(controller),
                child: Text(
                  controller.currentQualityInfo.value,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            if (!isPortrait)
              TextButton(
                onPressed: () => showLinesInfo(controller),
                child: Text(
                  controller.currentLineInfo.value,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            if (!Platform.isAndroid && !Platform.isIOS)
              IconButton(
                onPressed: controller.enterSmallWindow,
                icon: const Icon(
                  Icons.picture_in_picture,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            IconButton(
              onPressed: controller.enterFullScreen,
              icon: const Icon(
                Remix.fullscreen_line,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  });
}

Widget _buildSideLockButton(
  LiveRoomController controller, {
  required EdgeInsets padding,
  required bool alignLeft,
}) {
  return Obx(() {
    final visible = controller.lockControlsState.value
        ? controller.showLockEdgeState.value
        : controller.showControlsState.value;
    final offset = -(64 + (alignLeft ? padding.left : padding.right));
    return AnimatedPositioned(
      top: 0,
      bottom: 0,
      left: alignLeft ? (visible ? padding.left + 12 : offset) : null,
      right: alignLeft ? null : (visible ? padding.right + 12 : offset),
      duration: const Duration(milliseconds: 200),
      child: buildLockButton(controller),
    );
  });
}

Widget _buildGestureTip(LiveRoomController controller) {
  return Obx(() {
    final text = controller.gestureTipText.value.trim();
    if (!controller.showGestureTip.value || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  });
}

Widget buildDanmuView(VideoState videoState, LiveRoomController controller) {
  var padding = controller.fullScreenState.value
      ? _fullScreenControlPadding(videoState.context)
      : MediaQuery.of(videoState.context).padding;
  return Positioned.fill(
    top: padding.top,
    bottom: padding.bottom,
    child: Obx(
      () {
        controller.danmakuViewVersion.value;

        // 检测是否为小窗模式
        final isSmallWindow = controller.smallWindowState.value;
        final settings = AppSettingsController.instance;

        return Offstage(
          offstage: !controller.showDanmakuState.value,
          child: Padding(
            padding: controller.fullScreenState.value
                ? EdgeInsets.only(
                    top: AppSettingsController.instance.danmuTopMargin.value,
                    bottom:
                        AppSettingsController.instance.danmuBottomMargin.value,
                  )
                : EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportHeight = constraints.maxHeight > 0
                    ? constraints.maxHeight
                    : MediaQuery.sizeOf(context).height;
                controller.updateDanmakuViewportHeight(viewportHeight);

                // 小窗模式下的弹幕参数调整
                final fontSize = isSmallWindow
                    ? settings.danmuSize.value * settings.smallWindowDanmuScale.value
                    : settings.danmuSize.value;

                final opacity = isSmallWindow && settings.smallWindowDanmuAutoTransparent.value
                    ? settings.danmuOpacity.value * 0.7  // 更透明
                    : settings.danmuOpacity.value;

                // 小窗模式限制行数
                var lineCount = settings.danmuLineCount.value;
                if (isSmallWindow && lineCount > settings.smallWindowDanmuMaxLines.value) {
                  lineCount = settings.smallWindowDanmuMaxLines.value;
                }

                final resolvedLineCount = settings.resolveDanmuTargetLineCount(
                  viewportHeight: viewportHeight,
                  area: settings.danmuArea.value,
                  fontSize: fontSize,
                  lineCount: lineCount,
                );
                final hideDanmu = resolvedLineCount <= 0;
                return DanmakuScreen(
                  key: controller.globalDanmuKey,
                  createdController: controller.initDanmakuController,
                  option: DanmakuOption(
                    fontSize: fontSize,
                    fontFamily: Platform.isWindows ? "Microsoft YaHei" : (Platform.isAndroid ? "Roboto" : null),
                    area: settings.resolveDanmuEffectiveArea(
                      viewportHeight: viewportHeight,
                      area: settings.danmuArea.value,
                      fontSize: fontSize,
                      lineCount: lineCount,
                    ),
                    lineHeight: settings.resolveDanmuLineHeight(
                      viewportHeight: viewportHeight,
                      area: settings.danmuArea.value,
                      fontSize: fontSize,
                      lineCount: lineCount,
                    ),
                    duration: settings.danmuSpeed.value.toInt(),
                    opacity: opacity,
                    fontWeight: settings.danmuFontWeight.value,
                    hideTop: hideDanmu,
                    hideBottom: hideDanmu,
                    hideScroll: hideDanmu,
                    hideSpecial: hideDanmu,
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

void showLinesInfo(LiveRoomController controller) {
  if (controller.useBottomSheetPlayerMenus) {
    controller.showPlayUrlsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "线路选择",
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
  if (controller.useBottomSheetPlayerMenus) {
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
  if (controller.useBottomSheetPlayerMenus) {
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
          siteId: controller.site.id,
          previewViewportHeight: controller.danmakuViewportHeight.value,
        ),
      ],
    ),
  );
}

void showPlayerSettings(LiveRoomController controller) {
  if (controller.useBottomSheetPlayerMenus) {
    controller.showPlayerSettingsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "设置",
    width: 320,
    useSystem: true,
    child: Obx(
      () => RadioGroup(
        groupValue: AppSettingsController.instance.scaleMode.value,
        onChanged: (e) {
          AppSettingsController.instance.setScaleMode(e ?? 0);
          controller.updateScaleMode();
        },
        child: ListView(
          padding: AppStyle.edgeInsetsV12,
          children: [
            Padding(
              padding: AppStyle.edgeInsetsH16,
              child: Text(
                "画面尺寸",
                style: Get.textTheme.titleMedium,
              ),
            ),
            const RadioListTile(
              value: 0,
              contentPadding: AppStyle.edgeInsetsH4,
              title: Text("适应"),
              visualDensity: VisualDensity.compact,
            ),
            const RadioListTile(
              value: 1,
              contentPadding: AppStyle.edgeInsetsH4,
              title: Text("拉伸"),
              visualDensity: VisualDensity.compact,
            ),
            const RadioListTile(
              value: 2,
              contentPadding: AppStyle.edgeInsetsH4,
              title: Text("铺满"),
              visualDensity: VisualDensity.compact,
            ),
            const RadioListTile(
              value: 3,
              contentPadding: AppStyle.edgeInsetsH4,
              title: Text("16:9"),
              visualDensity: VisualDensity.compact,
            ),
            const RadioListTile(
              value: 4,
              contentPadding: AppStyle.edgeInsetsH4,
              title: Text("4:3"),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    ),
  );
}

void showQuickAccess(LiveRoomController controller) {
  final keys = controller.enabledQuickAccessKeys;
  if (keys.isEmpty) {
    SmartDialog.showToast("没有东西可展示");
    return;
  }
  if (keys.length == 1) {
    _openQuickAccessItem(controller, keys.single);
    return;
  }
  if (controller.useBottomSheetPlayerMenus) {
    controller.showQuickAccessSheet();
    return;
  }

  Utils.showRightDialog(
    title: "快捷入口",
    width: 320,
    useSystem: true,
    child: ListView(
      padding: AppStyle.edgeInsetsV12,
      children:
          keys.map((key) => _buildQuickAccessTile(controller, key)).toList(),
    ),
  );
}

Widget _buildQuickAccessTile(LiveRoomController controller, String key) {
  final item = Constant.allLiveRoomQuickAccess[key]!;
  final enabled =
      key != "recommendation" || controller.hasCategoryRecommendation;
  return ListTile(
    leading: Icon(item.iconData),
    title: Text(controller.quickAccessTitle(key)),
    subtitle: Text(controller.quickAccessSubtitle(key)),
    enabled: enabled,
    onTap: !enabled
        ? null
        : () async {
            await Utils.switchRightDialog(() async {
              _openQuickAccessItem(controller, key);
            });
          },
  );
}

void _openQuickAccessItem(LiveRoomController controller, String key) {
  switch (key) {
    case "follow":
      showFollowUser(controller);
      break;
    case "history":
      controller.openHistoryPage();
      break;
    case "recommendation":
      controller.openCategoryRecommendation();
      break;
    case "contribution_rank":
      controller.showContributionRankSheet();
      break;
  }
}

void showFollowUser(LiveRoomController controller) {
  if (controller.useBottomSheetPlayerMenus) {
    controller.showFollowUserSheet();
    return;
  }

  Utils.showRightDialog(
    title: "关注列表",
    width: 400,
    useSystem: true,
    child: controller.buildFollowUserSelection(
      onClose: Utils.hideRightDialog,
      scrollController: controller.liveRoomFollowDialogScrollController,
    ),
  );
}

class PlayerSuperChatCard extends StatefulWidget {
  final LiveSuperChatMessage message;
  final VoidCallback onExpire;
  final int duration;
  final VoidCallback? onUserTap;
  final VoidCallback? onUserLongPress;
  const PlayerSuperChatCard(
      {required this.message,
      required this.onExpire,
      required this.duration,
      this.onUserTap,
      this.onUserLongPress,
      Key? key})
      : super(key: key);
  @override
  State<PlayerSuperChatCard> createState() => _PlayerSuperChatCardState();
}

class _PlayerSuperChatCardState extends State<PlayerSuperChatCard> {
  Timer? timer;
  late int countdown;
  @override
  void initState() {
    super.initState();
    _restartCountdown();
  }

  void _restartCountdown() {
    timer?.cancel();
    countdown = widget.duration;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown <= 1) {
        widget.onExpire();
        timer?.cancel();
        return;
      }
      setState(() {
        countdown = (countdown - 1).clamp(0, 1 << 30).toInt();
      });
    });
  }

  @override
  void didUpdateWidget(covariant PlayerSuperChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.duration != widget.duration) {
      _restartCountdown();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.65,
      child: SuperChatCard(
        widget.message,
        onExpire: () {},
        customCountdown: countdown,
        onUserTap: widget.onUserTap,
        onUserLongPress: widget.onUserLongPress,
      ),
    );
  }
}

class LocalDisplaySC {
  LiveSuperChatMessage sc;
  final DateTime expireAt;
  final int duration;
  LocalDisplaySC(this.sc, this.expireAt, this.duration);

  String get fingerprint {
    final id = sc.id?.trim();
    if (id != null && id.isNotEmpty) {
      return "id:$id";
    }
    return "${sc.userName}|${sc.message}|${sc.price}|${sc.startTime.millisecondsSinceEpoch}";
  }
}

class PlayerSuperChatOverlay extends StatefulWidget {
  final LiveRoomController controller;
  const PlayerSuperChatOverlay({required this.controller, Key? key})
      : super(key: key);
  @override
  State<PlayerSuperChatOverlay> createState() => _PlayerSuperChatOverlayState();
}

class _PlayerSuperChatOverlayState extends State<PlayerSuperChatOverlay> {
  final List<LocalDisplaySC> _displayed = [];
  final Map<LocalDisplaySC, Timer> _timers = {};
  late Worker _worker;

  String _fingerprintOf(LiveSuperChatMessage sc) {
    final id = sc.id?.trim();
    if (id != null && id.isNotEmpty) {
      return "id:$id";
    }
    return "${sc.userName}|${sc.message}|${sc.price}|${sc.startTime.millisecondsSinceEpoch}";
  }

  void _removeLocalSC(LocalDisplaySC localSC) {
    _displayed.remove(localSC);
    _timers.remove(localSC)?.cancel();
  }

  void _addSC(LiveSuperChatMessage sc, {int? customSeconds}) {
    final fingerprint = _fingerprintOf(sc);
    int showSeconds = (customSeconds ?? 15).clamp(1, 1 << 30).toInt();
    final currentIndex = _displayed.indexWhere(
      (e) => e.fingerprint == fingerprint,
    );
    if (currentIndex >= 0) {
      final current = _displayed[currentIndex];
      current.sc = sc;
      setState(() {});
      return;
    }
    final expireAt = DateTime.now().add(Duration(seconds: showSeconds));
    final localSC = LocalDisplaySC(sc, expireAt, showSeconds);
    _displayed.add(localSC);
    _timers[localSC] = Timer(Duration(seconds: showSeconds), () {
      setState(() {
        _removeLocalSC(localSC);
      });
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // 初始化时先把仍在有效期内的头条恢复到播放器悬浮层里。
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var sc in widget.controller.superChats) {
      int remain = (sc.endTime.millisecondsSinceEpoch - now) ~/ 1000;
      if (remain > 0) {
        _addSC(sc, customSeconds: remain < 15 ? remain : 15);
      }
    }
    // 监听头条列表变化，同步更新悬浮展示队列。
    _worker =
        ever<List<LiveSuperChatMessage>>(widget.controller.superChats, (list) {
      for (var sc in list) {
        final remain = sc.endTime.difference(DateTime.now()).inSeconds;
        _addSC(sc, customSeconds: remain > 0 && remain < 15 ? remain : 15);
      }
      final latestFingerprints = list.map(_fingerprintOf).toSet();
      for (final localSC in _displayed.toList()) {
        if (!latestFingerprints.contains(localSC.fingerprint)) {
          _removeLocalSC(localSC);
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _worker.dispose();
    for (var t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _displayed.toList()
      ..sort((a, b) => a.sc.endTime.compareTo(b.sc.endTime));
    if (AppSettingsController.instance.superChatSortDesc.value) {
      sorted.replaceRange(0, sorted.length, sorted.reversed);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var localSC in sorted)
          Padding(
            key: ValueKey(localSC.fingerprint),
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 240,
              child: PlayerSuperChatCard(
                key: ValueKey(localSC.fingerprint),
                message: localSC.sc,
                onExpire: () {
                  setState(() {
                    _removeLocalSC(localSC);
                  });
                },
                duration: localSC.duration,
                onUserTap: () => widget.controller.showUserActions(
                  localSC.sc.userName,
                  messageContent: localSC.sc.message,
                ),
                onUserLongPress: () =>
                    widget.controller.copyUserName(localSC.sc.userName),
              ),
            ),
          ),
      ],
    );
  }
}
