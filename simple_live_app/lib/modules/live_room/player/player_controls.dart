import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/fullscreen_follow_panel.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'dart:async';
import 'package:simple_live_core/simple_live_core.dart';

/// 播放缓冲提示。
///
/// 打开直播间时不显示任何加载符号：白色转圈会直接盖在画面上，
/// 而首帧通常在几百毫秒内到达，弹出来只是闪一下。
/// 只有持续缓冲才淡入一行浅色文字，恢复后立即消失。
class PlayerBufferingHint extends StatefulWidget {
  const PlayerBufferingHint({
    super.key,
    required this.buffering,
    required this.visible,
    this.delay = const Duration(milliseconds: 2000),
  });

  /// 播放器是否处于缓冲状态
  final bool buffering;

  /// 外部可见条件，例如房间已下播时不再提示
  final bool visible;

  /// 持续缓冲多久后才提示
  final Duration delay;

  @override
  State<PlayerBufferingHint> createState() => _PlayerBufferingHintState();
}

class _PlayerBufferingHintState extends State<PlayerBufferingHint> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PlayerBufferingHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buffering != widget.buffering ||
        oldWidget.visible != widget.visible) {
      // 这里的赋值不能 setState：didUpdateWidget 处在构建流程内，随后必然重建。
      _sync();
    }
  }

  void _sync() {
    final active = widget.visible && widget.buffering;
    if (!active) {
      _timer?.cancel();
      _timer = null;
      _show = false;
      return;
    }
    if (_show || _timer != null) return;
    _timer = Timer(widget.delay, () {
      _timer = null;
      if (!mounted) return;
      if (!widget.visible || !widget.buffering) return;
      setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(90),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            "缓冲中",
            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.2),
          ),
        ),
      ),
    );
  }
}

Widget playerControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  return Obx(() {
    final controls = controller.fullScreenState.value
        ? buildFullControls(videoState, controller)
        : buildControls(
            MediaQuery.orientationOf(videoState.context) ==
                Orientation.portrait,
            videoState,
            controller,
          );
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => controller.officialEditorFocused.value
          ? KeyEventResult.ignored : handlePlayerShortcut(
        event,
        onFollowKey: controller.followByDoubleQ,
        onComposeDanmaku: controller.openDanmakuComposer,
        onResetFollowKey: controller.resetFollowShortcut,
        onToggleDanmaku: () => controller.showDanmakuState.toggle(),
        onToggleFullscreen: () {
          if (controller.fullScreenState.value) {
            controller.exitFull();
          } else {
            controller.enterFullScreen();
          }
        },
      ),
      child: !Platform.isAndroid && !Platform.isIOS
          ? Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (event) =>
                  _onVolumePointerSignal(event, controller, null),
              child: controls,
            )
          : controls,
    );
  });
}

/// Enter belongs to the visible room, even after a click moves focus outside
/// the player's Focus subtree. Run before child controls consume it as Activate.
class DesktopDanmakuShortcut extends StatefulWidget {
  const DesktopDanmakuShortcut({super.key, required this.onCompose, required this.child, this.isEditing});
  final VoidCallback onCompose;
  final Widget child;
  final bool Function()? isEditing;

  @override
  State<DesktopDanmakuShortcut> createState() => _DesktopDanmakuShortcutState();
}

class _DesktopDanmakuShortcutState extends State<DesktopDanmakuShortcut> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (!mounted || widget.isEditing?.call() == true || ModalRoute.of(context)?.isCurrent != true ||
        event is! KeyDownEvent || _editingTextOrModifiedShortcut() ||
        HardwareKeyboard.instance.isShiftPressed ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
      return KeyEventResult.ignored;
    }
    widget.onCompose();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool _editingTextOrModifiedShortcut() {
  final keyboard = HardwareKeyboard.instance;
  final focusContext = FocusManager.instance.primaryFocus?.context;
  final editable = focusContext?.widget is EditableText
      ? focusContext!.widget as EditableText
      : focusContext?.findAncestorWidgetOfExactType<EditableText>();
  return keyboard.isControlPressed ||
      keyboard.isAltPressed ||
      keyboard.isMetaPressed ||
      (editable != null && !editable.readOnly);
}

KeyEventResult handlePlayerShortcut(
  KeyEvent event, {
  required VoidCallback onToggleDanmaku,
  required VoidCallback onToggleFullscreen,
  VoidCallback? onRefresh,
  VoidCallback? onFollowKey,
  VoidCallback? onResetFollowKey,
  VoidCallback? onComposeDanmaku,
}) {
  if (_editingTextOrModifiedShortcut()) {
    onResetFollowKey?.call();
    return KeyEventResult.ignored;
  }
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (event.logicalKey == LogicalKeyboardKey.keyQ && onFollowKey != null) {
    onFollowKey();
    // 第一击也消费，避免同一个事件冒泡到页面后被当作第二击。
    return KeyEventResult.handled;
  }
  onResetFollowKey?.call();
  if ((event.logicalKey == LogicalKeyboardKey.enter ||
      event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
      !HardwareKeyboard.instance.isShiftPressed && onComposeDanmaku != null) {
    onComposeDanmaku();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.keyD) {
    onToggleDanmaku();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.keyF) {
    onToggleFullscreen();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.keyR && onRefresh != null) {
    onRefresh();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

double volumeAfterScroll(double currentVolume, double scrollDeltaY) {
  if (scrollDeltaY == 0) return currentVolume;
  return (currentVolume + (scrollDeltaY < 0 ? 5 : -5)).clamp(0, 100).toDouble();
}

/// Outside Video's controls/overlays so wheel input also reaches the actual
/// video surface and letterbox margins when its controls are hidden.
Widget playerVolumeScrollArea({
  required Widget child,
  required LiveRoomController controller,
}) {
  if (Platform.isAndroid || Platform.isIOS) return child;
  return Listener(
    behavior: HitTestBehavior.opaque,
    onPointerSignal: (event) => _onVolumePointerSignal(event, controller, null),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        // Independent of the hidden control bar; only the volume card opens.
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(
            child: SizedBox(key: controller.volumeScrollAnchorKey, width: 240, height: 1),
          ),
        ),
      ],
    ),
  );
}

void _onVolumePointerSignal(
  PointerSignalEvent event,
  LiveRoomController controller,
  BuildContext? targetContext,
) {
  if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
    // The volume icon also receives this event. Resolve at the deepest listener
    // so a single wheel tick cannot adjust both icon and video-area volume.
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      adjustVolumeOnScroll(signal, controller);
      final anchor = targetContext ?? controller.volumeScrollAnchorKey.currentContext;
      if (anchor != null) controller.showVolumeSlider(anchor);
    });
  }
}

void adjustVolumeOnScroll(
  PointerSignalEvent event,
  LiveRoomController controller,
) {
  if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
  final settings = AppSettingsController.instance;
  final volume = volumeAfterScroll(
    settings.playerVolume.value,
    event.scrollDelta.dy,
  );
  settings.setPlayerVolume(volume);
  controller.player.setVolume(volume);
}

Widget playerWindowDragArea({
  required Widget child,
  required bool isSmallWindow,
}) {
  return isSmallWindow ? DragToMoveArea(child: child) : child;
}

Widget buildFullControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  var padding = MediaQuery.paddingOf(videoState.context);
  GlobalKey volumeButtonkey = GlobalKey();
  return playerWindowDragArea(
    child: Stack(
      children: [
        Container(),
        buildDanmuView(videoState, controller),

        // 左下角SC显示
        Obx(
          () => Visibility(
            visible: AppSettingsController.instance.playershowSuperChat.value &&
                ((!Platform.isAndroid && !Platform.isIOS) ||
                    controller.fullScreenState.value),
            child: Positioned(
              left: 24,
              bottom: 24,
              child: PlayerSuperChatOverlay(controller: controller),
            ),
          ),
        ),

        Center(
          child: // 中间
              StreamBuilder<bool>(
            stream: videoState.widget.controller.player.stream.buffering,
            initialData: videoState.widget.controller.player.state.buffering,
            builder: (_, s) => Obx(
              () => PlayerBufferingHint(
                buffering: s.data ?? false,
                visible: controller.hasPlayed.value && !controller.roomOffline.value,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: controller.onTap,
            onDoubleTap: controller.onDoubleTap,
            onLongPress: () {
              if (controller.lockControlsState.value) {
                return;
              }
              showFollowUser(controller);
            },
            // Mobile brightness/volume drags otherwise steal mouse double taps
            // as soon as the cursor moves a few pixels while pressed.
            onVerticalDragStart: Platform.isAndroid || Platform.isIOS
                ? controller.onVerticalDragStart
                : null,
            onVerticalDragUpdate: Platform.isAndroid || Platform.isIOS
                ? controller.onVerticalDragUpdate
                : null,
            onVerticalDragEnd: Platform.isAndroid || Platform.isIOS
                ? controller.onVerticalDragEnd
                : null,
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
                    tooltip: controller.audioOnlyMode.value ? "退出纯音频" : "纯音频听播",
                    onPressed: () {
                      controller.toggleAudioOnlyMode();
                    },
                    icon: Icon(
                      controller.audioOnlyMode.value
                          ? Icons.videocam_outlined
                          : Icons.headphones_outlined,
                      color: controller.audioOnlyMode.value
                          ? Colors.lightBlueAccent
                          : Colors.white,
                      size: 24,
                    ),
                  ),
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
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        controller.liveDuration.value,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  const Expanded(child: Center()),
                  Visibility(
                    visible: !Platform.isAndroid && !Platform.isIOS,
                    child: Listener(
                      onPointerSignal: (event) => _onVolumePointerSignal(
                          event, controller, volumeButtonkey.currentContext),
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
    isSmallWindow: controller.smallWindowState.value,
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

      // 左下角SC显示
      Obx(
        () => Visibility(
          visible: AppSettingsController.instance.playershowSuperChat.value &&
              ((!Platform.isAndroid && !Platform.isIOS) ||
                  controller.fullScreenState.value),
          child: Positioned(
            left: 24,
            bottom: 24,
            child: PlayerSuperChatOverlay(controller: controller),
          ),
        ),
      ),

      // 中间
      Center(
        child: StreamBuilder<bool>(
          stream: videoState.widget.controller.player.stream.buffering,
          initialData: videoState.widget.controller.player.state.buffering,
          builder: (_, s) => Obx(
            () => PlayerBufferingHint(
              buffering: s.data ?? false,
              visible: controller.hasPlayed.value && !controller.roomOffline.value,
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          onTap: controller.onTap,
          onDoubleTap: controller.onDoubleTap,
          onVerticalDragStart: Platform.isAndroid || Platform.isIOS
              ? controller.onVerticalDragStart
              : null,
          onVerticalDragUpdate: Platform.isAndroid || Platform.isIOS
              ? controller.onVerticalDragUpdate
              : null,
          onVerticalDragEnd: Platform.isAndroid || Platform.isIOS
              ? controller.onVerticalDragEnd
              : null,
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
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      controller.liveDuration.value,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
                const Expanded(child: Center()),
                Visibility(
                  visible: !Platform.isAndroid && !Platform.isIOS,
                  child: Listener(
                    onPointerSignal: (event) => _onVolumePointerSignal(
                        event, controller, volumeButtonkey.currentContext),
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
                IconButton(
                  tooltip: controller.audioOnlyMode.value ? "退出纯音频" : "纯音频听播",
                  onPressed: () {
                    controller.toggleAudioOnlyMode();
                  },
                  icon: Icon(
                    controller.audioOnlyMode.value
                        ? Icons.videocam_outlined
                        : Icons.headphones_outlined,
                    color: controller.audioOnlyMode.value
                        ? Colors.lightBlueAccent
                        : Colors.white,
                    size: 22,
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
  var padding = MediaQuery.paddingOf(videoState.context);
  controller.danmakuView ??= DanmakuScreen(
    key: controller.globalDanmuKey,
    createdController: controller.initDanmakuController,
    option: DanmakuOption(
      fontSize: AppSettingsController.instance.danmuSize.value,
      area: AppSettingsController.instance.danmuArea.value,
      duration: AppSettingsController.instance.danmuSpeed.value,
      opacity: AppSettingsController.instance.danmuOpacity.value,
      //strokeWidth: AppSettingsController.instance.danmuStrokeWidth.value,
      fontWeight: AppSettingsController.instance.danmuFontWeight.value,
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
            controller.selectManualQuality(i);
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

void showFollowUser(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showFollowUserSheet();
    return;
  }

  final isMobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  Utils.showSideDialog(
    fromLeft: !isMobile,
    useSystem: true,
    showHeader: false,
    borderRadius: 12,
    surfaceAlpha: 244,
    maskColor: Colors.black.withAlpha(48),
    widthBuilder: (context) => computeFullscreenFollowLayout(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
      isMobile: isMobile,
    ).panelWidth,
    child: FullscreenFollowPanel(
      controller: controller,
      fromLeft: !isMobile,
      isMobile: isMobile,
      onClose: Utils.hideRightDialog,
      onSelectRoom: (site, roomId) {
        Utils.hideRightDialog();
        controller.resetRoom(site, roomId);
      },
    ),
  );
}

class PlayerSuperChatCard extends StatefulWidget {
  final LiveSuperChatMessage message;
  final VoidCallback onExpire;
  final int duration;
  const PlayerSuperChatCard(
      {required this.message,
      required this.onExpire,
      required this.duration,
      Key? key})
      : super(key: key);
  @override
  State<PlayerSuperChatCard> createState() => _PlayerSuperChatCardState();
}

class _PlayerSuperChatCardState extends State<PlayerSuperChatCard> {
  late Timer timer;
  late int countdown;
  @override
  void initState() {
    super.initState();
    countdown = widget.duration;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown <= 1) {
        widget.onExpire();
        timer.cancel();
        return;
      }
      setState(() {
        countdown -= 1;
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
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
      ),
    );
  }
}

class LocalDisplaySC {
  final LiveSuperChatMessage sc;
  final DateTime expireAt;
  final int duration;
  LocalDisplaySC(this.sc, this.expireAt, this.duration);
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

  void _addSC(LiveSuperChatMessage sc, {int? customSeconds}) {
    if (_displayed.any((e) => e.sc == sc)) return;
    int showSeconds = customSeconds ?? 15;
    final expireAt = DateTime.now().add(Duration(seconds: showSeconds));
    final localSC = LocalDisplaySC(sc, expireAt, showSeconds);
    _displayed.add(localSC);
    _timers[localSC] = Timer(Duration(seconds: showSeconds), () {
      setState(() {
        _displayed.remove(localSC);
        _timers.remove(localSC)?.cancel();
      });
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // 首次进房时同步已有SC
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var sc in widget.controller.superChats) {
      int remain = (sc.endTime.millisecondsSinceEpoch - now) ~/ 1000;
      if (remain > 0) {
        _addSC(sc, customSeconds: remain < 15 ? remain : 15);
      }
    }
    // 监听SC列表变化
    _worker =
        ever<List<LiveSuperChatMessage>>(widget.controller.superChats, (list) {
      // 新增
      for (var sc in list) {
        if (!_displayed.any((e) => e.sc == sc)) {
          _addSC(sc);
        }
      }
      // 移除
      _displayed.removeWhere((e) => !list.contains(e.sc));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var localSC in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 240,
              child: PlayerSuperChatCard(
                message: localSC.sc,
                onExpire: () {},
                duration: localSC.duration,
              ),
            ),
          ),
      ],
    );
  }
}
