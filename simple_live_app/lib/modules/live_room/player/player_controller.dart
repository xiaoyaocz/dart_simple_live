import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/custom_throttle.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/background_playback_service.dart';
import 'package:simple_live_app/services/ios_video_output_size.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

const _windowsChromeChannel = MethodChannel('simple_live/windows_chrome');
const _androidWindowChannel = MethodChannel('simple_live/app_window');
const liveRoomVolumeSliderDialogTag = 'live_room_volume_slider';
int _androidWindowHandlerGeneration = 0;

/// Android OEMs do not use one consistent windowing mode for their system
/// floating windows: some report freeform, while others only report
/// multi-window. Both keep the app outside the normal fullscreen task.
bool isAndroidExternalPlayerWindow({
  required bool inPip,
  required bool inMultiWindow,
  required bool isFreeform,
}) {
  return !inPip && (inMultiWindow || isFreeform);
}

/// Android 16 ignores orientation requests on large displays. Use the full
/// display, rather than a letterboxed or freeform Flutter view, so tablets do
/// not inherit a phone-only orientation policy.
bool shouldUseAndroidPhoneOrientationPolicy({
  required double displayWidth,
  required double displayHeight,
  required double devicePixelRatio,
}) {
  if (!displayWidth.isFinite ||
      !displayHeight.isFinite ||
      !devicePixelRatio.isFinite ||
      displayWidth <= 0 ||
      displayHeight <= 0 ||
      devicePixelRatio <= 0) {
    return false;
  }
  return math.min(displayWidth, displayHeight) / devicePixelRatio < 600;
}

bool shouldRequestLandscapeForAndroidExternalWindow({
  required bool inPip,
  required bool inMultiWindow,
  required bool isFreeform,
  required bool playerFullscreen,
  required bool isVerticalVideo,
  required bool canLockOrientation,
}) {
  return isAndroidExternalPlayerWindow(
        inPip: inPip,
        inMultiWindow: inMultiWindow,
        isFreeform: isFreeform,
      ) &&
      playerFullscreen &&
      !isVerticalVideo &&
      canLockOrientation;
}

bool shouldRestoreAndroidFullscreenAfterExternalWindowExit({
  required bool wasInExternalWindow,
  required bool isInExternalWindow,
  required bool playerFullscreen,
  required bool hasPendingLandscapeRequest,
  required bool isVerticalVideo,
  required bool canLockOrientation,
}) {
  return wasInExternalWindow &&
      !isInExternalWindow &&
      playerFullscreen &&
      hasPendingLandscapeRequest &&
      !isVerticalVideo &&
      canLockOrientation;
}

class _DanmakuReplayEntry {
  final String message;
  final Color color;
  final List<String>? imageUrls;
  final List<DanmakuContentPart>? parts;
  final DateTime visibleFrom;
  final DateTime visibleUntil;

  const _DanmakuReplayEntry({
    required this.message,
    required this.color,
    this.imageUrls,
    this.parts,
    required this.visibleFrom,
    required this.visibleUntil,
  });

  bool isVisibleAt(DateTime now) {
    return !now.isBefore(visibleFrom) && now.isBefore(visibleUntil);
  }
}

const int _kDanmakuReplayLimit = 300;

mixin PlayerMixin {
  bool _playerInitialized = false;
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  /// 播放器实例
  late final player = Player(
    configuration: PlayerConfiguration(
      title: "Simple Live Player",
      logLevel: AppSettingsController.instance.logEnable.value
          ? MPVLogLevel.info
          : MPVLogLevel.error,
    ),
  );

  /// 初始化播放器并设置静态 mpv 参数。
  Future<void> initializePlayer() async {
    if (_playerInitialized) {
      return;
    }
    _playerInitialized = true;
    await MpvOptionsService.applyToPlayer(player);
    final nativePlayer = player.platform as NativePlayer;
    // 设置音频输出驱动
    if (AppSettingsController.instance.customPlayerOutput.value) {
      if (player.platform is NativePlayer) {
        await (player.platform as dynamic).setProperty(
          'ao',
          AppSettingsController.instance.audioOutputDriver.value,
        );
      }
    }
    // media_kit 仓库更新导致的问题，临时解决办法
    if (Platform.isAndroid) {
      await nativePlayer.setProperty('force-seekable', 'yes');
    }
  }

  /// 视频控制器
  late final videoController = VideoController(
    player,
    configuration: MpvOptionsService.videoControllerConfiguration(),
  );
}

mixin PlayerStateMixin on PlayerMixin {
  bool _playerClosing = false;

  ///音量控制条计时器
  Timer? hidevolumeTimer;

  /// 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  /// 是否显示弹幕
  RxBool showDanmakuState = false.obs;

  RxBool mutedState = false.obs;
  double _volumeBeforeMute = 100.0;

  void onPlayerWindowModeExited() {}

  /// 是否显示控制器
  RxBool showControlsState = false.obs;

  RxBool hideMouseCursorState = false.obs;

  /// 是否显示设置窗口
  RxBool showSettingState = false.obs;

  /// 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  /// 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;
  RxBool showLockEdgeState = false.obs;

  /// 是否处于全屏状态
  RxBool fullScreenState = false.obs;

  /// Android 系统窗口状态。系统分屏/自由窗和应用自己的小窗是两套状态，
  /// 不能用 [smallWindowState] 互相代替。
  RxBool androidInPipState = false.obs;
  RxBool androidInMultiWindowState = false.obs;
  RxBool androidFreeformState = false.obs;

  /// 显示手势Tip
  RxBool showGestureTip = false.obs;

  /// 手势Tip文本
  RxString gestureTipText = "".obs;

  /// 显示提示底部Tip
  RxBool showBottomTip = false.obs;

  /// 提示底部Tip文本
  RxString bottomTipText = "".obs;

  /// 自动隐藏控制器计时器
  Timer? hideControlsTimer;

  /// 音量滑条浮层正在显示，播放器底层鼠标离开时不能隐藏控制器。
  bool volumeSliderVisible = false;

  /// 自动隐藏鼠标光标计时器
  Timer? hideMouseCursorTimer;

  Timer? _mobileLockRevealTimer;

  /// 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  /// 是否为竖屏直播间
  var isVertical = false.obs;

  RxInt danmakuViewVersion = 0.obs;

  var showQualites = false.obs;
  var showLines = false.obs;

  bool get useBottomSheetPlayerMenus =>
      (Platform.isAndroid || Platform.isIOS) && !fullScreenState.value;

  bool get isPlayerClosing => _playerClosing;

  Timer? _gestureTipTimer;

  void showGestureTipText(String text) {
    final value = text.trim();
    if (value.isEmpty || _playerClosing) {
      return;
    }
    gestureTipText.value = value;
    showGestureTip.value = true;
    _gestureTipTimer?.cancel();
    _gestureTipTimer = Timer(const Duration(seconds: 2), clearGestureTip);
  }

  void clearGestureTip() {
    _gestureTipTimer?.cancel();
    _gestureTipTimer = null;
    showGestureTip.value = false;
    gestureTipText.value = "";
  }

  void clearTransientPlayerOverlays() {
    clearGestureTip();
    cancelVerticalDrag();
    _mobileLockRevealTimer?.cancel();
    _mobileLockRevealTimer = null;
    showLockEdgeState.value = false;
    hidevolumeTimer?.cancel();
    hidevolumeTimer = null;
    volumeSliderVisible = false;
    SmartDialog.dismiss(tag: liveRoomVolumeSliderDialogTag);
  }

  void cancelVerticalDrag() {}

  /// 隐藏控制器
  void hideControls() {
    clearTransientPlayerOverlays();
    showControlsState.value = false;
    hideControlsTimer?.cancel();
    hideMouseCursor();
  }

  void setLockState() {
    clearGestureTip();
    _mobileLockRevealTimer?.cancel();
    _mobileLockRevealTimer = null;
    lockControlsState.value = !lockControlsState.value;
    showLockEdgeState.value = false;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  void revealMobileLockControls() {
    // The lock overlay is used by every full-screen target. On desktop the
    // previous edge-hover-only path made the unlock button unreachable when a
    // trackpad/mouse click was the first interaction after locking.
    if (!lockControlsState.value) {
      return;
    }
    showLockEdgeState.value = true;
    _mobileLockRevealTimer?.cancel();
    _mobileLockRevealTimer = Timer(const Duration(seconds: 3), () {
      if (lockControlsState.value) {
        showLockEdgeState.value = false;
      }
    });
  }

  /// 显示控制器
  void showControls() {
    showControlsState.value = true;
    showMouseCursor();
    resetHideControlsTimer();
    resetHideMouseCursorTimer();
  }

  /// 显示鼠标光标
  void showMouseCursor() {
    if (!Platform.isWindows) {
      return;
    }
    hideMouseCursorTimer?.cancel();
    hideMouseCursorState.value = false;
  }

  /// 隐藏鼠标光标
  void hideMouseCursor() {
    if (!Platform.isWindows) {
      return;
    }
    hideMouseCursorTimer?.cancel();
    hideMouseCursorState.value = true;
  }

  /// 开始隐藏控制器计时
  /// - 当点击控制器上时功能时需要重新计时
  void resetHideControlsTimer() {
    hideControlsTimer?.cancel();

    hideControlsTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideControls,
    );
  }

  /// 开始隐藏鼠标光标计时
  void resetHideMouseCursorTimer() {
    if (!Platform.isWindows) {
      return;
    }

    hideMouseCursorTimer?.cancel();
    hideMouseCursorTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideMouseCursor,
    );
  }

  void updateScaleMode() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (player.state.width != null && player.state.height != null) {
      aspectRatio = player.state.width! / player.state.height!;
    }

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
    globalPlayerKey.currentState?.update(
      aspectRatio: aspectRatio,
      fit: boxFit,
    );
  }
}
mixin PlayerDanmakuMixin on PlayerStateMixin {
  /// 弹幕控制器
  DanmakuController? danmakuController;
  final List<_DanmakuReplayEntry> _danmakuReplayHistory = [];
  bool _danmakuReplayScheduled = false;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
    // danmakuController?.updateOption(
    //   DanmakuOption(
    //     fontSize: AppSettingsController.instance.danmuSize.value,
    //     area: AppSettingsController.instance.danmuArea.value,
    //     duration: AppSettingsController.instance.danmuSpeed.value,
    //     opacity: AppSettingsController.instance.danmuOpacity.value,
    //     strokeWidth: AppSettingsController.instance.danmuStrokeWidth.value,
    //     fontWeight: FontWeight
    //         .values[AppSettingsController.instance.danmuFontWeight.value],
    //   ),
    // );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }

  void disposeDanmakuController() {
    danmakuController?.clear();
    danmakuController = null;
  }

  void setDanmakuVisible(bool visible) {
    if (showDanmakuState.value == visible) {
      return;
    }
    showDanmakuState.value = visible;
    if (visible) {
      danmakuController?.resume();
    } else {
      danmakuController?.pause();
    }
  }

  void clearDanmakuReplayHistory() {
    _danmakuReplayHistory.clear();
  }

  void rememberDanmakuReplay(
    String message,
    Color color, {
    Duration delay = Duration.zero,
    List<String>? imageUrls,
    List<DanmakuContentPart>? parts,
  }) {
    var durationSeconds =
        AppSettingsController.instance.danmuSpeed.value.toInt();
    if (durationSeconds < 1) {
      durationSeconds = 1;
    }

    final visibleFrom = DateTime.now().add(delay);
    _danmakuReplayHistory.add(
      _DanmakuReplayEntry(
        message: message,
        color: color,
        imageUrls: imageUrls,
        parts: parts,
        visibleFrom: visibleFrom,
        visibleUntil: visibleFrom.add(Duration(seconds: durationSeconds)),
      ),
    );
    _pruneDanmakuReplayHistory();
  }

  void _pruneDanmakuReplayHistory([DateTime? now]) {
    final current = now ?? DateTime.now();
    _danmakuReplayHistory.removeWhere(
      (item) => !item.visibleUntil.isAfter(current),
    );
    if (_danmakuReplayHistory.length > _kDanmakuReplayLimit) {
      _danmakuReplayHistory.removeRange(
        0,
        _danmakuReplayHistory.length - _kDanmakuReplayLimit,
      );
    }
  }

  void _scheduleDanmakuReplay() {
    if (_danmakuReplayScheduled) {
      return;
    }
    _danmakuReplayScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _danmakuReplayScheduled = false;
      _replayDanmakuOverlay();
    });
  }

  void _replayDanmakuOverlay() {
    if (!showDanmakuState.value ||
        AppSettingsController.instance.danmuLineCount.value <= 0 ||
        danmakuController == null) {
      return;
    }
    final now = DateTime.now();
    _pruneDanmakuReplayHistory(now);
    for (final item in _danmakuReplayHistory) {
      if (!item.isVisibleAt(now)) {
        continue;
      }
      danmakuController?.addDanmaku(
        DanmakuContentItem(
          item.message,
          color: item.color,
          imageUrls: item.imageUrls,
          parts: item.parts,
        ),
      );
    }
  }

  void rebuildDanmakuView({bool clearCurrent = true}) {
    if (clearCurrent) {
      danmakuController?.clear();
    }
    globalDanmuKey = GlobalKey();
    danmakuViewVersion.value += 1;
    _scheduleDanmakuReplay();
  }

  void addDanmaku(List<DanmakuContentItem> items) {
    if (!showDanmakuState.value ||
        AppSettingsController.instance.danmuLineCount.value <= 0) {
      return;
    }
    for (var item in items) {
      danmakuController?.addDanmaku(item);
    }
  }
}
mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  final pip = Floating();
  StreamSubscription<PiPStatus>? _pipSubscription;
  bool _androidWindowChannelActive = false;
  int? _androidWindowHandlerToken;
  bool _mobileSystemUiApplied = false;
  int _systemLifecycleGeneration = 0;
  bool _androidLandscapePendingAfterExternalWindow = false;
  int _androidExternalWindowExitGeneration = 0;

  //final VolumeController volumeController = VolumeController();

  /// 初始化一些系统状态
  Future<void> initSystem() async {
    final generation = ++_systemLifecycleGeneration;
    if (Platform.isAndroid) {
      await _initializeAndroidWindowState();
    }
    if (_playerClosing || generation != _systemLifecycleGeneration) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      VolumeController.instance.showSystemUI = false;
    }

    // 屏幕常亮
    //WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();

    // 进入全屏模式
    if (AppSettingsController.instance.autoFullScreen.value) {
      await enterFullScreen();
    }
  }

  /// 释放一些系统状态
  Future resetSystem() async {
    _systemLifecycleGeneration += 1;
    final hadAndroidExternalLandscape =
        Platform.isAndroid && _androidLandscapePendingAfterExternalWindow;
    _androidLandscapePendingAfterExternalWindow = false;
    _androidExternalWindowExitGeneration += 1;
    _pipSubscription?.cancel();
    if (Platform.isAndroid && _androidWindowChannelActive) {
      final token = _androidWindowHandlerToken;
      _androidWindowChannelActive = false;
      _androidWindowHandlerToken = null;
      if (token != null && token == _androidWindowHandlerGeneration) {
        _androidWindowChannel.setMethodCallHandler(null);
      }
    }
    //pip.dispose();
    if (_mobileSystemUiApplied) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      await resetPreferredOrientation();
      _mobileSystemUiApplied = false;
    } else if (hadAndroidExternalLandscape) {
      await resetPreferredOrientation();
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 亮度重置,桌面平台可能会报错,暂时不处理桌面平台的亮度
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (e) {
        Log.logPrint(e);
      }
    }

    await WakelockPlus.disable();
  }

  /// 进入全屏
  Future<void> enterFullScreen() async {
    clearTransientPlayerOverlays();
    if (smallWindowState.value) {
      await exitSmallWindow();
      return;
    }
    fullScreenState.value = true;
    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid) {
        await _refreshAndroidWindowState();
        final canLockAndroidOrientation =
            _shouldUseAndroidPhoneOrientationPolicy();
        final isExternalWindow = isAndroidExternalPlayerWindow(
          inPip: androidInPipState.value,
          inMultiWindow: androidInMultiWindowState.value,
          isFreeform: androidFreeformState.value,
        );
        if (isExternalWindow) {
          // A system freeform/split window owns its bounds. Only switch the
          // Flutter page to the player and leave its system bars alone. Some
          // OEM freeform windows are only reported as multi-window, but both
          // modes can honour an orientation request. Do not leave a landscape
          // stream trapped in the portrait floating window.
          _androidLandscapePendingAfterExternalWindow =
              canLockAndroidOrientation && !isVertical.value;
          if (shouldRequestLandscapeForAndroidExternalWindow(
            inPip: androidInPipState.value,
            inMultiWindow: androidInMultiWindowState.value,
            isFreeform: androidFreeformState.value,
            playerFullscreen: fullScreenState.value,
            isVerticalVideo: isVertical.value,
            canLockOrientation: canLockAndroidOrientation,
          )) {
            await setLandscapeOrientation();
          }
          return;
        }
        _androidLandscapePendingAfterExternalWindow = false;
      }
      //全屏
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      _mobileSystemUiApplied = true;
      if (!isVertical.value &&
          (!Platform.isAndroid || _shouldUseAndroidPhoneOrientationPolicy())) {
        //横屏
        await setLandscapeOrientation();
      }
    } else {
      _windowMaximizedBeforeFullScreen = await windowManager.isMaximized();
      await _applyWindowsFullScreenChrome();
      await windowManager.setFullScreen(true);
      await _waitForWindowsFullScreenState(true);
      await _applyWindowsFullScreenChrome();
      unawaited(
        Future.delayed(const Duration(milliseconds: 900), () async {
          if (!fullScreenState.value || smallWindowState.value) {
            return;
          }
          await _applyWindowsFullScreenChrome();
        }),
      );
      await Future.delayed(const Duration(milliseconds: 32));
    }
    //danmakuController?.clear();
  }

  Future<void> toggleFullScreen() async {
    if (fullScreenState.value || smallWindowState.value) {
      await exitPlayerWindowMode();
    } else {
      await enterFullScreen();
    }
  }

  /// 退出全屏
  Future<void> exitFull() async {
    clearTransientPlayerOverlays();
    final hadAndroidExternalLandscape =
        Platform.isAndroid && _androidLandscapePendingAfterExternalWindow;
    _androidLandscapePendingAfterExternalWindow = false;
    _androidExternalWindowExitGeneration += 1;
    if (smallWindowState.value) {
      await exitSmallWindow();
      return;
    }
    if (Platform.isAndroid) {
      // Clear this before asking Android for updated window state. OEM freeform
      // callbacks can arrive while fullscreen is being dismissed; retaining the
      // old value lets the callback re-apply landscape after it was restored.
      fullScreenState.value = false;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid) {
        await _refreshAndroidWindowState();
      }
      if (_mobileSystemUiApplied) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
        await resetPreferredOrientation();
        _mobileSystemUiApplied = false;
        await Future.delayed(const Duration(milliseconds: 32));
      } else if (Platform.isAndroid && hadAndroidExternalLandscape) {
        // The system window owned its bars, but the landscape preference was
        // still applied to the activity. Return to the regular policy.
        await resetPreferredOrientation();
      }
    } else {
      await windowManager.setFullScreen(false);
      await _waitForWindowsFullScreenState(false);
      await _restoreWindowsWindowChrome();
      await _refreshWindowsWindowBounds();
      if (_windowMaximizedBeforeFullScreen) {
        await windowManager.maximize();
        await _waitForWindowMaximizedState(true);
      }
      _windowMaximizedBeforeFullScreen = false;
    }
    if (!Platform.isAndroid) {
      fullScreenState.value = false;
    }
    onPlayerWindowModeExited();

    //danmakuController?.clear();
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;
  bool _windowMaximizedBeforeFullScreen = false;
  bool _windowMaximizedBeforeSmallWindow = false;

  Future<void> _waitForWindowMaximizedState(bool value) async {
    if (!Platform.isWindows) {
      return;
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 600));
    while (DateTime.now().isBefore(deadline)) {
      if (await windowManager.isMaximized() == value) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _waitForWindowsFullScreenState(bool value) async {
    if (!Platform.isWindows) {
      await Future.delayed(const Duration(milliseconds: 16));
      return;
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 800));
    while (DateTime.now().isBefore(deadline)) {
      if (await windowManager.isFullScreen() == value) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _waitForWindowBoundsToChange(Rect previousBounds) async {
    if (!Platform.isWindows) {
      return;
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 800));
    while (DateTime.now().isBefore(deadline)) {
      final currentBounds = await windowManager.getBounds();
      final moved = (currentBounds.left - previousBounds.left).abs() > 0.5 ||
          (currentBounds.top - previousBounds.top).abs() > 0.5 ||
          (currentBounds.width - previousBounds.width).abs() > 0.5 ||
          (currentBounds.height - previousBounds.height).abs() > 0.5;
      if (moved) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _refreshWindowsWindowBounds() async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      final size = await windowManager.getSize();
      if (size.width <= 1 || size.height <= 1) {
        return;
      }
      final nudgedSize = Size(size.width + 1, size.height + 1);
      await windowManager.setSize(nudgedSize);
      await windowManager.setSize(size);
    } catch (e) {
      Log.logPrint(e);
    }
  }

  Future<void> _applyWindowsFullScreenChrome() async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await _windowsChromeChannel.invokeMethod<void>('apply');
    } catch (e) {
      Log.logPrint(e);
    }
  }

  ///小窗模式()
  Future<void> _restoreWindowsWindowChrome() async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await _windowsChromeChannel.invokeMethod<void>('restore');
    } catch (e) {
      Log.logPrint(e);
    }
  }

  Future<void> enterSmallWindow() async {
    clearTransientPlayerOverlays();
    if (Platform.isAndroid || Platform.isIOS || smallWindowState.value) {
      return;
    }

    _windowMaximizedBeforeSmallWindow = await windowManager.isMaximized();
    if (_windowMaximizedBeforeSmallWindow) {
      final maximizedBounds = await windowManager.getBounds();
      await windowManager.restore();
      await _waitForWindowMaximizedState(false);
      await _waitForWindowBoundsToChange(maximizedBounds);
      await _refreshWindowsWindowBounds();
      await Future.delayed(const Duration(milliseconds: 120));
    }
    fullScreenState.value = true;
    smallWindowState.value = true;

    // 读取窗口大小
    _lastWindowSize = await windowManager.getSize();
    _lastWindowPosition = await windowManager.getPosition();

    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    // 获取视频窗口大小
    var width = player.state.width ?? 16;
    var height = player.state.height ?? 9;

    // 横屏还是竖屏
    if (height > width) {
      var aspectRatio = width / height;
      await windowManager.setSize(Size(400, 400 / aspectRatio));
    } else {
      var aspectRatio = height / width;
      await windowManager.setSize(Size(280 / aspectRatio, 280));
    }

    await windowManager.setAlwaysOnTop(true);
    danmakuController?.resume();
  }

  ///退出小窗模式()
  Future<void> exitSmallWindow() async {
    clearTransientPlayerOverlays();
    if (Platform.isAndroid || Platform.isIOS || !smallWindowState.value) {
      return;
    }

    fullScreenState.value = false;
    smallWindowState.value = false;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    if (_lastWindowPosition != null) {
      await windowManager.setPosition(_lastWindowPosition!);
    }
    if (_lastWindowSize != null) {
      await windowManager.setSize(_lastWindowSize!);
    }
    if (_windowMaximizedBeforeSmallWindow) {
      await windowManager.maximize();
      await _waitForWindowMaximizedState(true);
    } else {
      await _refreshWindowsWindowBounds();
    }
    _windowMaximizedBeforeSmallWindow = false;
    danmakuController?.resume();
    onPlayerWindowModeExited();
    //windowManager.setAlignment(Alignment.center);
  }

  Future<void> exitPlayerWindowMode() async {
    if (smallWindowState.value) {
      await exitSmallWindow();
      return;
    }
    if (fullScreenState.value) {
      await exitFull();
    }
  }

  void toggleDanmakuByShortcut() {
    setDanmakuVisible(!showDanmakuState.value);
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (player.state.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  /// 手动刷新播放（需要子类实现 mediaError）
  void refreshPlayback() {
    // 这个方法会被 LiveRoomController 覆盖
    // 这里提供一个基础实现，尝试重新播放
    player.play();
  }

  Future<void> toggleMute() async {
    if (mutedState.value) {
      final restoreVolume =
          _volumeBeforeMute <= 0 ? 100.0 : _volumeBeforeMute.clamp(0.0, 100.0);
      await setSessionPlayerVolume(restoreVolume);
      return;
    }
    _volumeBeforeMute = player.state.volume <= 0
        ? AppSettingsController.instance.playerVolume.value
        : player.state.volume;
    mutedState.value = true;
    await player.setVolume(0);
  }

  Future<void> setSessionPlayerVolume(
    double volume, {
    bool persist = false,
  }) async {
    final requestedValue = volume.clamp(0.0, 100.0).toDouble();
    final mobile = Platform.isAndroid || Platform.isIOS;
    final value = requestedValue <= 0 ? 0.0 : (mobile ? 100.0 : requestedValue);
    if (value <= 0) {
      mutedState.value = true;
      await player.setVolume(0);
    } else {
      mutedState.value = false;
      _volumeBeforeMute = value;
      await player.setVolume(value);
    }
    if (persist && !mobile) {
      AppSettingsController.instance.setPlayerVolume(requestedValue);
    }
  }

  Future<void> adjustDesktopPlayerVolume(int delta) async {
    if (delta == 0 || Platform.isAndroid || Platform.isIOS) {
      return;
    }
    final current = player.state.volume.clamp(0.0, 100.0).toDouble();
    final target = (current + delta).clamp(0.0, 100.0).toDouble();
    await setSessionPlayerVolume(target, persist: true);
    showGestureTipText("音量 ${target.round()}%");
  }

  bool _shouldUseAndroidPhoneOrientationPolicy() {
    if (!Platform.isAndroid) {
      return false;
    }
    final context = Get.context;
    final display = context == null ? null : View.maybeOf(context)?.display;
    final fallbackViews = WidgetsBinding.instance.platformDispatcher.views;
    final resolvedDisplay =
        display ?? (fallbackViews.isEmpty ? null : fallbackViews.first.display);
    if (resolvedDisplay == null) {
      // If the full display cannot be read, keep the system policy instead of
      // risking a tablet letterbox through a forced orientation.
      return false;
    }
    return shouldUseAndroidPhoneOrientationPolicy(
      displayWidth: resolvedDisplay.size.width,
      displayHeight: resolvedDisplay.size.height,
      devicePixelRatio: resolvedDisplay.devicePixelRatio,
    );
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  /// Restore the orientation policy after leaving mobile fullscreen.
  /// Compact phones always return to portrait, including OEM-managed floating
  /// windows. Releasing the orientation instead can leave those tasks stuck in
  /// the landscape request used by fullscreen playback. Tablets keep the OS
  /// orientation policy so their layouts are not forced through portrait.
  Future resetPreferredOrientation() async {
    if (Platform.isIOS) {
      await setPortraitOrientation();
      return;
    }
    if (Platform.isAndroid) {
      if (_shouldUseAndroidPhoneOrientationPolicy()) {
        await setPortraitOrientation();
      } else {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
      return;
    }
    if (await beforeIOS16()) {
      AutoOrientation.fullAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  Future saveScreenshot() async {
    try {
      SmartDialog.showLoading(msg: "正在保存截图");
      //检查相册权限,仅iOS需要
      var permission = await Utils.checkPhotoPermission();
      if (!permission) {
        SmartDialog.showToast("没有相册权限");
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      var imageData = await player.screenshot();
      if (imageData == null) {
        SmartDialog.showToast("截图失败,数据为空");
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      if (Platform.isIOS || Platform.isAndroid) {
        await ImageGallerySaverPlus.saveImage(
          imageData,
        );
        SmartDialog.showToast("已保存截图至相册");
      } else {
        //选择保存文件夹
        var path = await FilePicker.platform.saveFile(
          allowedExtensions: ["jpg"],
          type: FileType.image,
          fileName: "${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
        if (path == null) {
          SmartDialog.showToast("取消保存");
          SmartDialog.dismiss(status: SmartStatus.loading);
          return;
        }
        var file = File(path);
        await file.writeAsBytes(imageData);
        SmartDialog.showToast("已保存截图至${file.path}");
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("截图失败");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  /// 开启小窗播放前弹幕状态
  bool danmakuStateBeforePIP = false;
  bool _pipStateApplied = false;
  bool _autoPipOnLeaveConfigured = false;
  bool _autoPipReconfigureInFlight = false;
  bool _autoPipReconfigurePending = false;
  int? _autoPipConfiguredVideoWidth;
  int? _autoPipConfiguredVideoHeight;

  Rational _resolvePipAspectRatio() {
    final width = player.state.width ?? 0;
    final height = player.state.height ?? 0;
    if (width > 0 && height > 0) {
      final divisor = _greatestCommonDivisor(width, height);
      final numerator = width ~/ divisor;
      final denominator = height ~/ divisor;
      final ratio = numerator / denominator;
      if (ratio >= (1 / 2.39) && ratio <= 2.39) {
        return Rational(numerator, denominator);
      }
    }
    return height > width
        ? const Rational.vertical()
        : const Rational.landscape();
  }

  int _greatestCommonDivisor(int a, int b) {
    var left = a.abs();
    var right = b.abs();
    while (right != 0) {
      final remainder = left % right;
      left = right;
      right = remainder;
    }
    return left == 0 ? 1 : left;
  }

  math.Rectangle<int>? _buildPipSourceRectHint() {
    final context = globalPlayerKey.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return null;
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    var sourceWidth = renderObject.size.width;
    var sourceHeight = renderObject.size.height;
    final videoWidth = player.state.width ?? 0;
    final videoHeight = player.state.height ?? 0;
    if (videoWidth > 0 && videoHeight > 0) {
      final videoRatio = videoWidth / videoHeight;
      final viewRatio = renderObject.size.width / renderObject.size.height;
      if (viewRatio > videoRatio) {
        sourceWidth = renderObject.size.height * videoRatio;
        sourceHeight = renderObject.size.height;
      } else {
        sourceWidth = renderObject.size.width;
        sourceHeight = renderObject.size.width / videoRatio;
      }
    }
    final sourceOffset = Offset(
      offset.dx + (renderObject.size.width - sourceWidth) / 2,
      offset.dy + (renderObject.size.height - sourceHeight) / 2,
    );
    final pixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    return math.Rectangle<int>(
      (sourceOffset.dx * pixelRatio).round(),
      (sourceOffset.dy * pixelRatio).round(),
      math.max(1, (sourceWidth * pixelRatio).round()),
      math.max(1, (sourceHeight * pixelRatio).round()),
    );
  }

  Future<void> _initializeAndroidWindowState() async {
    if (!Platform.isAndroid || _androidWindowChannelActive) {
      return;
    }
    _androidWindowChannelActive = true;
    final token = ++_androidWindowHandlerGeneration;
    _androidWindowHandlerToken = token;
    _androidWindowChannel.setMethodCallHandler((call) async {
      if (!_androidWindowChannelActive ||
          _androidWindowHandlerToken != token ||
          call.method != 'windowStateChanged') {
        return null;
      }
      _applyAndroidWindowState(call.arguments);
      return null;
    });
    await _refreshAndroidWindowState();
  }

  Future<void> _refreshAndroidWindowState() async {
    if (!Platform.isAndroid || !_androidWindowChannelActive) {
      return;
    }
    final token = _androidWindowHandlerToken;
    try {
      final state = await _androidWindowChannel.invokeMethod<dynamic>(
        'getWindowState',
      );
      if (!_androidWindowChannelActive || _androidWindowHandlerToken != token) {
        return;
      }
      _applyAndroidWindowState(state);
    } catch (e) {
      Log.d("读取 Android 窗口状态失败：$e");
    }
  }

  void _applyAndroidWindowState(dynamic arguments) {
    if (arguments is! Map) {
      return;
    }
    final inPip = arguments['inPip'] == true;
    final inMultiWindow = arguments['inMultiWindow'] == true;
    final isFreeform = arguments['isFreeform'] == true;
    final wasInPip = androidInPipState.value;
    final wasInExternalWindow = isAndroidExternalPlayerWindow(
      inPip: wasInPip,
      inMultiWindow: androidInMultiWindowState.value,
      isFreeform: androidFreeformState.value,
    );
    final isInExternalWindow = isAndroidExternalPlayerWindow(
      inPip: inPip,
      inMultiWindow: inMultiWindow,
      isFreeform: isFreeform,
    );
    androidInPipState.value = inPip;
    androidInMultiWindowState.value = inMultiWindow;
    androidFreeformState.value = isFreeform;
    unawaited(_syncAndroidExternalWindowLandscapeOrientation());
    if (shouldRestoreAndroidFullscreenAfterExternalWindowExit(
      wasInExternalWindow: wasInExternalWindow,
      isInExternalWindow: isInExternalWindow,
      playerFullscreen: fullScreenState.value,
      hasPendingLandscapeRequest: _androidLandscapePendingAfterExternalWindow,
      isVerticalVideo: isVertical.value,
      canLockOrientation: _shouldUseAndroidPhoneOrientationPolicy(),
    )) {
      unawaited(_restoreAndroidFullscreenAfterExternalWindowExit());
    }
    if (inPip && !wasInPip) {
      _applyPipEnteredState();
    } else if (!inPip && wasInPip) {
      _restorePipExitedState();
    }
  }

  /// System floating windows are often created using the app's default
  /// portrait task orientation. Re-apply the active landscape player
  /// orientation as soon as Android reports the external-window transition.
  Future<void> _syncAndroidExternalWindowLandscapeOrientation() async {
    if (!Platform.isAndroid ||
        !shouldRequestLandscapeForAndroidExternalWindow(
          inPip: androidInPipState.value,
          inMultiWindow: androidInMultiWindowState.value,
          isFreeform: androidFreeformState.value,
          playerFullscreen: fullScreenState.value,
          isVerticalVideo: isVertical.value,
          canLockOrientation: _shouldUseAndroidPhoneOrientationPolicy(),
        )) {
      return;
    }
    try {
      await setLandscapeOrientation();
    } catch (e) {
      Log.d("系统自由窗请求横屏失败: $e");
    }
  }

  /// System-owned windows may ignore immersive mode while floating. Once the
  /// user expands that window, apply the fullscreen request again after the
  /// new task bounds have reached Flutter.
  Future<void> _restoreAndroidFullscreenAfterExternalWindowExit() async {
    final token = ++_androidExternalWindowExitGeneration;
    await Future.delayed(const Duration(milliseconds: 160));
    if (!Platform.isAndroid ||
        token != _androidExternalWindowExitGeneration ||
        !fullScreenState.value ||
        isVertical.value ||
        !_shouldUseAndroidPhoneOrientationPolicy() ||
        !_androidLandscapePendingAfterExternalWindow ||
        isAndroidExternalPlayerWindow(
          inPip: androidInPipState.value,
          inMultiWindow: androidInMultiWindowState.value,
          isFreeform: androidFreeformState.value,
        )) {
      return;
    }
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      _mobileSystemUiApplied = true;
      await setLandscapeOrientation();
      _androidLandscapePendingAfterExternalWindow = false;
    } catch (e) {
      Log.d("系统小窗展开后恢复横屏失败: $e");
    }
  }

  void _ensurePipStatusListener() {
    _pipSubscription ??= pip.pipStatusStream.listen((event) {
      if (event == PiPStatus.enabled) {
        _applyPipEnteredState();
      } else if (event == PiPStatus.disabled) {
        _restorePipExitedState();
      }
      Log.w(event.toString());
    });
  }

  void _applyPipEnteredState() {
    androidInPipState.value = true;
    if (_pipStateApplied) {
      return;
    }
    _pipStateApplied = true;
    danmakuStateBeforePIP = showDanmakuState.value;
    if (AppSettingsController.instance.pipHideDanmu.value &&
        danmakuStateBeforePIP) {
      setDanmakuVisible(false);
    }
    showControlsState.value = false;
  }

  void _restorePipExitedState() {
    androidInPipState.value = false;
    if (!_pipStateApplied && !_autoPipOnLeaveConfigured) {
      return;
    }
    _pipStateApplied = false;
    _autoPipOnLeaveConfigured = false;
    _autoPipConfiguredVideoWidth = null;
    _autoPipConfiguredVideoHeight = null;
    setDanmakuVisible(danmakuStateBeforePIP);
  }

  Future<void> cancelAutoPipOnLeave() async {
    if (!Platform.isAndroid) {
      return;
    }
    _autoPipOnLeaveConfigured = false;
    _autoPipReconfigurePending = false;
    try {
      await pip.cancelOnLeavePiP();
    } catch (e) {
      Log.d("取消自动小窗失败: $e");
    }
  }

  Future<bool> prepareAutoPipOnLeave() async {
    if (!Platform.isAndroid) {
      return _autoPipOnLeaveConfigured;
    }
    final videoWidth = player.state.width ?? 0;
    final videoHeight = player.state.height ?? 0;
    if (_autoPipOnLeaveConfigured &&
        videoWidth > 0 &&
        videoHeight > 0 &&
        _autoPipConfiguredVideoWidth == videoWidth &&
        _autoPipConfiguredVideoHeight == videoHeight) {
      return true;
    }
    if (await pip.isPipAvailable == false) {
      return false;
    }
    _ensurePipStatusListener();
    try {
      final status = await pip.enable(
        OnLeavePiP(
          aspectRatio: _resolvePipAspectRatio(),
          sourceRectHint: _buildPipSourceRectHint(),
        ),
      );
      if (status != PiPStatus.automatic && status != PiPStatus.enabled) {
        _autoPipOnLeaveConfigured = false;
        return false;
      }
      _autoPipOnLeaveConfigured = true;
      _autoPipConfiguredVideoWidth = videoWidth > 0 ? videoWidth : null;
      _autoPipConfiguredVideoHeight = videoHeight > 0 ? videoHeight : null;
      showControlsState.value = false;
      return true;
    } catch (e) {
      Log.d("配置退后台自动小窗失败: $e");
      return false;
    }
  }

  Future<void> refreshAutoPipOnVideoSize() async {
    if (!Platform.isAndroid || !_autoPipOnLeaveConfigured) {
      return;
    }
    if (_autoPipReconfigureInFlight) {
      _autoPipReconfigurePending = true;
      return;
    }
    _autoPipReconfigureInFlight = true;
    try {
      do {
        _autoPipReconfigurePending = false;
        if (!_autoPipOnLeaveConfigured) {
          break;
        }
        await prepareAutoPipOnLeave();
      } while (_autoPipReconfigurePending && _autoPipOnLeaveConfigured);
    } finally {
      _autoPipReconfigureInFlight = false;
      if (_autoPipReconfigurePending && _autoPipOnLeaveConfigured) {
        _autoPipReconfigurePending = false;
        unawaited(refreshAutoPipOnVideoSize());
      }
    }
  }

  Future enablePIP() async {
    if (!Platform.isAndroid) {
      SmartDialog.showToast("当前平台暂不支持小窗播放");
      return;
    }
    if (await pip.isPipAvailable == false) {
      SmartDialog.showToast("设备不支持小窗播放");
      return;
    }
    await cancelAutoPipOnLeave();
    _ensurePipStatusListener();
    final status = await pip.enable(
      ImmediatePiP(
        aspectRatio: _resolvePipAspectRatio(),
        sourceRectHint: _buildPipSourceRectHint(),
      ),
    );
    if (status != PiPStatus.enabled) {
      SmartDialog.showToast("进入小窗失败");
    }
  }
}
mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  /// 单击显示/隐藏控制器
  void onTap() {
    if (volumeSliderVisible) {
      return;
    }
    if (lockControlsState.value) {
      revealMobileLockControls();
      return;
    }
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  // 桌面端鼠标操控
  void onEnter(PointerEnterEvent event) {
    showMouseCursor();
    resetHideMouseCursorTimer();
    if (lockControlsState.value) {
      return;
    }
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    hideMouseCursorTimer?.cancel();
    hideControlsTimer?.cancel();
    showLockEdgeState.value = false;
    if (volumeSliderVisible) {
      return;
    }
    if (lockControlsState.value) {
      return;
    }
    if (!showControlsState.value) {
      return;
    }
    hideControlsTimer = Timer(
      const Duration(milliseconds: 180),
      () {
        if (showControlsState.value) {
          hideControls();
        }
      },
    );
  }

  void onHover(PointerHoverEvent event, BuildContext context) {
    showMouseCursor();
    resetHideMouseCursorTimer();
    if (volumeSliderVisible) {
      return;
    }
    if (lockControlsState.value) {
      final width = context.size?.width ?? 0;
      showLockEdgeState.value = fullScreenState.value &&
          width > 0 &&
          (event.localPosition.dx <= 48 ||
              event.localPosition.dx >= width - 48);
      return;
    }
    resetHideControlsTimer();
    if (!showControlsState.value) {
      showControls();
    }
  }

  /// 双击全屏/退出全屏
  void onDoubleTap() {
    if (lockControlsState.value) {
      return;
    }
    clearTransientPlayerOverlays();
    if (smallWindowState.value) {
      exitSmallWindow();
    } else if (fullScreenState.value) {
      exitFull();
    } else {
      enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;
  var _verticalDragExtent = 1.0;
  var _useLocalDragPosition = false;
  var _verticalDragGeneration = 0;
  var _verticalDragReady = false;

  DelayedThrottle? throttle;

  @override
  void cancelVerticalDrag() {
    _verticalDragGeneration += 1;
    throttle?.cancel();
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    _useLocalDragPosition = false;
    _verticalDragReady = false;
  }

  /// 竖向手势开始
  Future<void> onVerticalDragStart(
    DragStartDetails details, {
    Size? viewportSize,
  }) async {
    clearGestureTip();
    // A new drag invalidates any pending system-volume/brightness read from
    // the previous drag before checking whether this gesture is usable.
    cancelVerticalDrag();
    showMouseCursor();
    resetHideMouseCursorTimer();
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (!AppSettingsController.instance.playerGestureControlEnable.value) {
      return;
    }

    final width = viewportSize?.width ?? Get.width;
    final height = viewportSize?.height ?? Get.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    final localX = details.localPosition.dx;
    final localY = details.localPosition.dy;
    if (Platform.isWindows || Platform.isLinux) {
      final sideGestureWidth = width * 0.28;
      if (localX > sideGestureWidth && localX < width - sideGestureWidth) {
        return;
      }
    }

    _useLocalDragPosition = viewportSize != null;
    final dy = _useLocalDragPosition ? localY : details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < height * 0.25 || dy > height * 0.75) {
      return;
    }

    verStartPosition = dy;
    _verticalDragExtent = math.max(height * 0.5, 1.0);
    leftVerticalDrag = localX < width / 2;

    throttle?.cancel();
    throttle = DelayedThrottle(
      200,
      onError: (error, stackTrace) {
        Log.e("调整系统音量失败: $error", stackTrace);
      },
    );
    lastVolume = -1;

    verticalDragging = true;
    _verticalDragReady = false;
    final dragGeneration = ++_verticalDragGeneration;
    double? initialVolume;
    var initialBrightness = 1.0;
    var volumeReadSucceeded = true;
    if (Platform.isWindows || Platform.isLinux) {
      final currentPlayerVolume = player.state.volume;
      if (currentPlayerVolume > 0) {
        initialVolume = currentPlayerVolume.clamp(0.0, 100.0) / 100;
      } else {
        initialVolume = AppSettingsController.instance.playerVolume.value
                .clamp(0.0, 100.0) /
            100;
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        initialVolume = await VolumeController.instance.getVolume();
      } catch (e, stackTrace) {
        volumeReadSucceeded = false;
        Log.e("读取系统音量失败: $e", stackTrace);
      }
    }
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux) {
      try {
        initialBrightness = await ScreenBrightness.instance.application;
      } catch (e, stackTrace) {
        Log.e("读取应用亮度失败: $e", stackTrace);
      }
    }
    if (dragGeneration != _verticalDragGeneration || !verticalDragging) {
      return;
    }
    if (!leftVerticalDrag && !volumeReadSucceeded) {
      // Do not calculate a new value from the previous gesture when the
      // system-volume read failed; the next gesture can retry the read.
      verticalDragging = false;
      return;
    }
    _currentVolume = initialVolume ?? _currentVolume;
    _currentBrightness = initialBrightness;
    _verticalDragReady = true;
  }

  /// 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (!AppSettingsController.instance.playerGestureControlEnable.value) {
      return;
    }
    if (verticalDragging == false || !_verticalDragReady) return;
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isWindows &&
        !Platform.isLinux) {
      return;
    }
    //String text = "";
    //double value = 0.0;

    final dragPosition =
        _useLocalDragPosition ? e.localPosition.dy : e.globalPosition.dy;
    Log.logPrint("$verStartPosition/$dragPosition");

    if (leftVerticalDrag) {
      setGestureBrightness(dragPosition);
    } else {
      setGestureVolume(dragPosition);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / _verticalDragExtent);

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / _verticalDragExtent);
      seek = value.abs() + _currentVolume;
      if (seek > 1) {
        seek = 1;
      }
    }
    int volume = _convertVolume((seek * 100).round());
    if (volume == lastVolume) {
      return;
    }
    lastVolume = volume;
    // update UI outside throttle to make it more fluent
    showGestureTipText("音量 $volume%");
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future<void> _realSetVolume(int volume) async {
    Log.logPrint(volume);
    if (Platform.isWindows || Platform.isLinux) {
      await setSessionPlayerVolume(volume.toDouble(), persist: true);
      return;
    }
    // 手势只调系统音量，播放器内部音量由独立设置控制。
    await VolumeController.instance.setVolume(volume / 100);
  }

  void setGestureBrightness(double dy) {
    double value = 0.0;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / _verticalDragExtent);

      var seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
      ScreenBrightness.instance.setApplicationScreenBrightness(seek);

      showGestureTipText("亮度 ${(seek * 100).toInt()}%");
      Log.logPrint(value);
    } else {
      value = ((dy - verStartPosition) / _verticalDragExtent);
      var seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }

      ScreenBrightness.instance.setApplicationScreenBrightness(seek);
      showGestureTipText("亮度 ${(seek * 100).toInt()}%");
      Log.logPrint(value);
    }
  }

  /// 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    cancelVerticalDrag();
    clearGestureTip();
  }

  void onVerticalDragCancel() {
    cancelVerticalDrag();
    clearGestureTip();
  }
}

class PlayerController extends BaseController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {
  /// 播放恢复操作所属的加载代次。
  ///
  /// 普通播放器没有房间切换概念，使用固定代次；直播间控制器会覆盖此值，
  /// 让延迟重试在切换房间后自动失效。
  int get playbackLoadGeneration => 0;

  /// Changes whenever the current media is deliberately reopened.
  int get playbackMediaGeneration => 0;

  bool isPlaybackLoadGenerationCurrent(int generation) {
    return !_playerClosing && generation == playbackLoadGeneration;
  }

  Future<void>? _playbackOpenFuture;

  bool _isPlaybackOwnerCurrent(
    int loadGeneration,
    int mediaGeneration,
    bool Function()? isStillOwner,
  ) {
    return isPlaybackLoadGenerationCurrent(loadGeneration) &&
        mediaGeneration == playbackMediaGeneration &&
        (isStillOwner?.call() ?? true);
  }

  /// Serializes every media open so a stale recovery cannot finish after a
  /// newer room open and replace its media.
  Future<bool> openPlaybackMedia(
    Media media, {
    required int loadGeneration,
    required int mediaGeneration,
    bool Function()? isStillOwner,
  }) async {
    while (true) {
      if (!_isPlaybackOwnerCurrent(
        loadGeneration,
        mediaGeneration,
        isStillOwner,
      )) {
        return false;
      }
      final activeOpen = _playbackOpenFuture;
      if (activeOpen == null) {
        break;
      }
      try {
        await activeOpen;
      } catch (e, stackTrace) {
        Log.e("等待旧媒体打开失败: $e", stackTrace);
      }
    }

    if (!_isPlaybackOwnerCurrent(
      loadGeneration,
      mediaGeneration,
      isStillOwner,
    )) {
      return false;
    }
    _surfaceRecoveryGraceUntil =
        DateTime.now().add(_surfaceRecoveryGraceDuration);
    final opening = Future<void>.microtask(() => player.open(media));
    _playbackOpenFuture = opening;
    try {
      await opening;
      return _isPlaybackOwnerCurrent(
        loadGeneration,
        mediaGeneration,
        isStillOwner,
      );
    } finally {
      if (identical(_playbackOpenFuture, opening)) {
        _playbackOpenFuture = null;
      }
    }
  }

  Future<void> waitForPlaybackOpen() async {
    final activeOpen = _playbackOpenFuture;
    if (activeOpen == null) {
      return;
    }
    try {
      await activeOpen;
    } catch (e, stackTrace) {
      Log.e("等待媒体打开结束失败: $e", stackTrace);
    }
  }

  @override
  void onInit() {
    unawaited(initSystem());
    initStream();
    //设置音量
    player.setVolume(_resolvedPlayerVolume());
    super.onInit();
  }

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _playingSubscription;
  Timer? _iosVideoOutputSyncTimer;
  Worker? _iosOriginalQualityPowerSavingWorker;
  IosVideoOutputSize? _iosVideoOutputSize;
  int? _iosVideoSourceWidth;
  int? _iosVideoSourceHeight;
  bool _iosVideoOutputForceApply = false;

  String get videoOutputResolution {
    final output = _iosVideoOutputSize;
    if (output != null) {
      return output.toString();
    }
    return '${player.state.width ?? 0}x${player.state.height ?? 0}';
  }

  void _handleVideoParamsForIosOutput(VideoParams params) {
    var width = params.dw ?? params.w ?? player.state.width;
    var height = params.dh ?? params.h ?? player.state.height;
    final rotate = params.rotate ?? 0;
    if (rotate % 180 != 0) {
      final originalWidth = width;
      width = height;
      height = originalWidth;
    }
    _scheduleIosVideoOutputSync(
      sourceWidth: width,
      sourceHeight: height,
      force: true,
    );
  }

  void refreshIosVideoOutputLimit({bool force = true}) {
    _scheduleIosVideoOutputSync(
      sourceWidth: _iosVideoSourceWidth ?? player.state.width,
      sourceHeight: _iosVideoSourceHeight ?? player.state.height,
      force: force,
    );
  }

  void _scheduleIosVideoOutputSync({
    int? sourceWidth,
    int? sourceHeight,
    bool force = false,
  }) {
    if (!Platform.isIOS || _playerClosing) {
      return;
    }
    if (sourceWidth != null && sourceWidth > 0) {
      _iosVideoSourceWidth = sourceWidth;
    }
    if (sourceHeight != null && sourceHeight > 0) {
      _iosVideoSourceHeight = sourceHeight;
    }
    _iosVideoOutputForceApply = _iosVideoOutputForceApply || force;
    _iosVideoOutputSyncTimer?.cancel();
    _iosVideoOutputSyncTimer = Timer(
      const Duration(milliseconds: 120),
      () {
        final shouldForce = _iosVideoOutputForceApply;
        _iosVideoOutputForceApply = false;
        unawaited(_applyIosVideoOutputLimit(force: shouldForce));
      },
    );
  }

  Future<void> _applyIosVideoOutputLimit({required bool force}) async {
    if (!Platform.isIOS || _playerClosing) {
      return;
    }
    final settings = AppSettingsController.instance;
    if (!settings.iosOriginalQualityPowerSaving.value) {
      if (force || _iosVideoOutputSize != null) {
        try {
          await videoController.setSize();
          _iosVideoOutputSize = null;
          Log.d("iOS 原画省电优化已关闭，恢复源分辨率纹理");
        } catch (e) {
          Log.w("恢复 iOS 源分辨率纹理失败: $e");
        }
      }
      return;
    }

    final sourceWidth = _iosVideoSourceWidth;
    final sourceHeight = _iosVideoSourceHeight;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (sourceWidth == null ||
        sourceHeight == null ||
        sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        views.isEmpty) {
      return;
    }
    final physicalSize = views.first.physicalSize;
    final target = calculateIosVideoOutputSize(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      screenPhysicalWidth: physicalSize.width,
      screenPhysicalHeight: physicalSize.height,
    );
    if (target == null || (!force && target == _iosVideoOutputSize)) {
      return;
    }

    try {
      if (force && _iosVideoOutputSize != null) {
        // media_kit may restore the source-sized surface for a new VideoParams
        // event without updating its Dart-side fixed-size state.
        await videoController.setSize();
      }
      await videoController.setSize(
        width: target.width,
        height: target.height,
      );
      _iosVideoOutputSize = target;
      Log.i(
        "iOS 视频纹理限幅：source=${sourceWidth}x$sourceHeight "
        "screen=${physicalSize.width.toInt()}x${physicalSize.height.toInt()} "
        "output=$target",
      );
    } catch (e, stackTrace) {
      Log.e("应用 iOS 视频纹理限幅失败: $e", stackTrace);
    }
  }

  // Fix Issue #57: 流错误重试计数器
  int _streamErrorRetryCount = 0;
  DateTime? _lastStreamErrorTime;
  DateTime? _lastAudioDiagnosticTime;
  bool _streamErrorRetrying = false;
  int? _streamErrorRetryGeneration;
  int? _streamErrorGeneration;
  Timer? _streamErrorStablePlaybackTimer;
  Timer? _surfaceHealthCheckTimer;
  Timer? _playbackStallWatchdogTimer;
  Timer? _playbackStallStableTimer;
  bool _surfaceRecoveryInFlight = false;
  int _surfaceRecoveryAttempts = 0;
  int? _surfaceRecoveryLoadGeneration;
  int? _surfaceRecoveryMediaGeneration;
  int _surfaceRecoveryToken = 0;
  DateTime? _lastSurfaceRecoveryAt;
  DateTime? _surfaceRecoveryGraceUntil;
  Duration? _stallLastPosition;
  DateTime? _stallLastProgressAt;
  DateTime? _lastPlaybackStallRecoveryAt;
  int? _stallLoadGeneration;
  String? _stallMediaUri;
  int _playbackStallRecoveryAttempts = 0;
  bool _playbackStallRecoveryInFlight = false;

  static const _stablePlaybackDuration = Duration(seconds: 30);
  static const _surfaceRecoveryCooldown = Duration(seconds: 3);
  static const _surfaceRecoveryGraceDuration = Duration(seconds: 8);
  static const _surfaceRecoveryValidationDelay = Duration(milliseconds: 600);
  static const _maxSurfaceRecoveryAttempts = 3;
  static const _playbackStallSampleInterval = Duration(seconds: 3);
  static const _playbackStallTimeout = Duration(seconds: 10);  // 从 15 秒缩短到 10 秒
  static const _playbackBufferingStallTimeout = Duration(seconds: 30);
  static const _playbackStallCooldown = Duration(seconds: 5);

  void _syncStreamErrorGeneration(int generation) {
    if (_streamErrorGeneration == generation) {
      return;
    }
    _streamErrorGeneration = generation;
    _streamErrorRetryCount = 0;
    _lastStreamErrorTime = null;
    _streamErrorStablePlaybackTimer?.cancel();
    _streamErrorStablePlaybackTimer = null;
  }

  void _cancelStablePlaybackTimer() {
    _streamErrorStablePlaybackTimer?.cancel();
    _streamErrorStablePlaybackTimer = null;
  }

  void _scheduleStablePlaybackReset(int generation) {
    _cancelStablePlaybackTimer();
    _streamErrorStablePlaybackTimer = Timer(_stablePlaybackDuration, () {
      _streamErrorStablePlaybackTimer = null;
      if (!isPlaybackLoadGenerationCurrent(generation) ||
          !player.state.playing ||
          _streamErrorRetrying) {
        return;
      }
      if (_streamErrorGeneration == generation) {
        _streamErrorRetryCount = 0;
        _lastStreamErrorTime = null;
        if (_surfaceRecoveryLoadGeneration == generation) {
          _surfaceRecoveryAttempts = 0;
          _lastSurfaceRecoveryAt = null;
        }
        Log.d("播放器已稳定播放，重置流错误重试计数");
      }
    });
  }

  void initStream() {
    if (Platform.isIOS) {
      _iosOriginalQualityPowerSavingWorker = ever<bool>(
        AppSettingsController.instance.iosOriginalQualityPowerSaving,
        (_) => refreshIosVideoOutputLimit(),
      );
    }
    _errorSubscription = player.stream.error.listen((event) {
      if (PlayerErrorClassifier.isRecoverableAudioDiagnostic(event)) {
        final now = DateTime.now();
        if (_lastAudioDiagnosticTime == null ||
            now.difference(_lastAudioDiagnosticTime!) >=
                const Duration(seconds: 15)) {
          _lastAudioDiagnosticTime = now;
          Log.d("播放器音频诊断（已忽略）：$event");
        }
        return;
      }
      Log.d("播放器错误：$event");

      // Fix Issue #57: 检测流错误并自动重试
      if (_isStreamError(event)) {
        _cancelStablePlaybackTimer();
        unawaited(_handleStreamError(event));
        return;
      }

      //SmartDialog.showToast(event);
      _cancelStablePlaybackTimer();
      mediaError(event);
    });

    _playingSubscription = player.stream.playing.listen((event) {
      final generation = playbackLoadGeneration;
      _syncStreamErrorGeneration(generation);
      if (event) {
        _surfaceRecoveryGraceUntil =
            DateTime.now().add(_surfaceRecoveryGraceDuration);
        unawaited(_applyResolvedPlayerVolume());
        WakelockPlus.enable();
        unawaited(_syncBackgroundPlaybackService(true));
        Log.d("Playing");
        refreshIosVideoOutputLimit(force: true);
        // 只有持续播放一段时间才清零，避免坏流在每次重开后立刻绕过上限。
        _scheduleStablePlaybackReset(generation);
      } else {
        _cancelStablePlaybackTimer();
      }
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        _cancelStablePlaybackTimer();
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("播放器日志：$event");
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');

      // Fix Issue #57: 检测异常的视频尺寸
      if (event == null || event <= 0) {
        if (player.state.playing) {
          Log.w("播放器宽度异常: $event (播放中)，可能是Surface失效");
          unawaited(_handleInvalidVideoSize());
        }
        return;
      }

      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
      unawaited(refreshAutoPipOnVideoSize());
      unawaited(_syncAndroidExternalWindowLandscapeOrientation());
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');

      // Fix Issue #57: 检测异常的视频尺寸
      if (event == null || event <= 0) {
        if (player.state.playing) {
          Log.w("播放器高度异常: $event (播放中)，可能是Surface失效");
          unawaited(_handleInvalidVideoSize());
        }
        return;
      }

      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
      unawaited(refreshAutoPipOnVideoSize());
      unawaited(_syncAndroidExternalWindowLandscapeOrientation());
    });
    _videoParamsSubscription = player.stream.videoParams.listen(
      _handleVideoParamsForIosOutput,
    );

    // Fix Issue #57: 启动Surface健康检查
    _startSurfaceHealthCheck();
    _startPlaybackStallWatchdog();
  }

  void disposeStream() {
    _cancelStablePlaybackTimer();
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    _logSubscription?.cancel();
    _pipSubscription?.cancel();
    _playingSubscription?.cancel();
    _surfaceHealthCheckTimer?.cancel();
    _playbackStallWatchdogTimer?.cancel();
    _playbackStallStableTimer?.cancel();
    _iosVideoOutputSyncTimer?.cancel();
    _iosOriginalQualityPowerSavingWorker?.dispose();
    _iosOriginalQualityPowerSavingWorker = null;
    _iosVideoOutputSyncTimer = null;
    _surfaceHealthCheckTimer = null;
    _surfaceRecoveryToken += 1;
    _surfaceRecoveryInFlight = false;
    _surfaceRecoveryAttempts = 0;
    _surfaceRecoveryLoadGeneration = null;
    _surfaceRecoveryMediaGeneration = null;
    _lastSurfaceRecoveryAt = null;
    _surfaceRecoveryGraceUntil = null;
    _stallLastPosition = null;
    _stallLastProgressAt = null;
    _lastPlaybackStallRecoveryAt = null;
    _stallLoadGeneration = null;
    _stallMediaUri = null;
    _playbackStallRecoveryAttempts = 0;
    _playbackStallRecoveryInFlight = false;
  }

  // Fix Issue #57: 判断是否为流错误（网络/解码错误）
  bool _isStreamError(String error) {
    return error.contains('mbedtls_ssl_read') ||
        error.contains('Packet corrupt') ||
        error.contains('Packet corupt') ||
        error.contains('tls:') ||
        error.contains('Invalid NAL unit') ||
        error.contains('missing picture');
  }

  // Fix Issue #57: 处理流错误，自动重试
  Future<void> _handleStreamError(String error) async {
    final generation = playbackLoadGeneration;
    final mediaGeneration = playbackMediaGeneration;
    if (!isPlaybackLoadGenerationCurrent(generation)) {
      return;
    }
    _syncStreamErrorGeneration(generation);
    if (_streamErrorRetrying && _streamErrorRetryGeneration == generation) {
      return;
    }
    _streamErrorRetrying = true;
    _streamErrorRetryGeneration = generation;
    final mediaAtError = player.state.playlist.medias.isNotEmpty
        ? player.state.playlist.medias[player.state.playlist.index]
        : null;
    final mediaUriAtError = mediaAtError?.uri;
    final now = DateTime.now();

    // 防止短时间内重复触发
    if (_lastStreamErrorTime != null &&
        now.difference(_lastStreamErrorTime!) < const Duration(seconds: 2)) {
      _streamErrorRetrying = false;
      _streamErrorRetryGeneration = null;
      if (player.state.playing) {
        _scheduleStablePlaybackReset(generation);
      }
      return;
    }
    _lastStreamErrorTime = now;

    if (_streamErrorRetryCount >= 3) {
      Log.e("流错误重试次数已达上限(3次)，停止重试: $error", StackTrace.current);
      mediaError(error);
      _streamErrorRetrying = false;
      _streamErrorRetryGeneration = null;
      return;
    }

    _streamErrorRetryCount++;
    Log.w(
      "检测到流错误，自动重试解码器 ($_streamErrorRetryCount/3): $error",
      false,
    );

    // 等待1秒后重新打开当前流
    await Future.delayed(const Duration(seconds: 1));

    try {
      if (!isPlaybackLoadGenerationCurrent(generation)) {
        return;
      }
      final currentMedia = player.state.playlist.medias.isNotEmpty
          ? player.state.playlist.medias[player.state.playlist.index]
          : null;

      if (mediaGeneration != playbackMediaGeneration ||
          mediaAtError == null ||
          mediaUriAtError == null ||
          currentMedia == null ||
          currentMedia.uri != mediaUriAtError) {
        return;
      }

      if (isPlaybackLoadGenerationCurrent(generation)) {
        Log.i("正在重启解码器...");
        await player.pause();
        if (!isPlaybackLoadGenerationCurrent(generation) ||
            mediaGeneration != playbackMediaGeneration) {
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
        if (!isPlaybackLoadGenerationCurrent(generation) ||
            mediaGeneration != playbackMediaGeneration) {
          return;
        }
        final reopened = await openPlaybackMedia(
          currentMedia,
          loadGeneration: generation,
          mediaGeneration: mediaGeneration,
          isStillOwner: () {
            final activeMedia = player.state.playlist.medias.isNotEmpty
                ? player.state.playlist.medias[player.state.playlist.index]
                : null;
            return activeMedia?.uri == mediaUriAtError;
          },
        );
        if (!reopened) {
          return;
        }
      }
    } catch (e, stackTrace) {
      Log.e("重启解码器失败: $e", stackTrace);
      if (isPlaybackLoadGenerationCurrent(generation)) {
        mediaError(error);
      }
    } finally {
      if (_streamErrorRetryGeneration == generation) {
        _streamErrorRetrying = false;
        _streamErrorRetryGeneration = null;
      }
    }
  }

  double _resolvedPlayerVolume() {
    return PlayerVolumePolicy.internalVolume(
      mobile: Platform.isAndroid || Platform.isIOS,
      muted: mutedState.value,
      persisted: AppSettingsController.instance.playerVolume.value,
    );
  }

  Future<void> _applyResolvedPlayerVolume() async {
    if (_playerClosing) {
      return;
    }
    await player.setVolume(_resolvedPlayerVolume());
  }

  // Fix Issue #57 & #97: 处理异常的视频尺寸（Surface失效）。
  // Recovery is bounded and serialized so startup events cannot storm the decoder.
  Future<void> _handleInvalidVideoSize() async {
    final generation = playbackLoadGeneration;
    final mediaGeneration = playbackMediaGeneration;
    if (!isPlaybackLoadGenerationCurrent(generation) ||
        !player.state.playing ||
        _playerClosing) {
      return;
    }
    if (_streamErrorRetrying && _streamErrorRetryGeneration == generation) {
      return;
    }

    final now = DateTime.now();
    if (_surfaceRecoveryGraceUntil != null &&
        now.isBefore(_surfaceRecoveryGraceUntil!)) {
      return;
    }
    if (_surfaceRecoveryInFlight) {
      return;
    }
    if (_surfaceRecoveryLoadGeneration != generation ||
        _surfaceRecoveryMediaGeneration != mediaGeneration) {
      _surfaceRecoveryLoadGeneration = generation;
      _surfaceRecoveryMediaGeneration = mediaGeneration;
      _surfaceRecoveryAttempts = 0;
      _lastSurfaceRecoveryAt = null;
    }
    if (_surfaceRecoveryAttempts >= _maxSurfaceRecoveryAttempts) {
      Log.w("Surface恢复次数已达上限（$_maxSurfaceRecoveryAttempts次），暂不重复重启");
      return;
    }
    if (_lastSurfaceRecoveryAt != null &&
        now.difference(_lastSurfaceRecoveryAt!) < _surfaceRecoveryCooldown) {
      return;
    }

    final media = player.state.playlist.medias.isNotEmpty
        ? player.state.playlist.medias[player.state.playlist.index]
        : null;
    final mediaUri = media?.uri;
    if (media == null || mediaUri == null || mediaUri.isEmpty) {
      return;
    }

    _surfaceRecoveryInFlight = true;
    _surfaceRecoveryAttempts += 1;
    _lastSurfaceRecoveryAt = now;
    final recoveryToken = ++_surfaceRecoveryToken;
    Log.w(
      "检测到视频尺寸异常，尝试恢复Surface "
      "($_surfaceRecoveryAttempts/$_maxSurfaceRecoveryAttempts)",
    );

    try {
      await player.pause();
      await Future.delayed(const Duration(milliseconds: 300));
      if (recoveryToken != _surfaceRecoveryToken ||
          !isPlaybackLoadGenerationCurrent(generation) ||
          mediaGeneration != playbackMediaGeneration ||
          _playerClosing) {
        return;
      }
      await player.play();
      await Future.delayed(_surfaceRecoveryValidationDelay);
      if (recoveryToken != _surfaceRecoveryToken ||
          !isPlaybackLoadGenerationCurrent(generation) ||
          mediaGeneration != playbackMediaGeneration ||
          _playerClosing) {
        return;
      }
      if (!_hasInvalidVideoSize() || !player.state.playing) {
        return;
      }

      final currentMedia = player.state.playlist.medias.isNotEmpty
          ? player.state.playlist.medias[player.state.playlist.index]
          : null;
      if (currentMedia?.uri != mediaUri) {
        return;
      }
      Log.w("Surface恢复失败，重开当前媒体");
      final reopened = await openPlaybackMedia(
        currentMedia!,
        loadGeneration: generation,
        mediaGeneration: mediaGeneration,
        isStillOwner: () {
          final activeMedia = player.state.playlist.medias.isNotEmpty
              ? player.state.playlist.medias[player.state.playlist.index]
              : null;
          return activeMedia?.uri == mediaUri;
        },
      );
      if (reopened) {
        _surfaceRecoveryGraceUntil =
            DateTime.now().add(_surfaceRecoveryGraceDuration);
      }
    } catch (e, stackTrace) {
      Log.e("恢复Surface失败: $e", stackTrace);
    } finally {
      if (recoveryToken == _surfaceRecoveryToken) {
        _surfaceRecoveryInFlight = false;
      }
    }
  }

  bool _hasInvalidVideoSize() {
    final width = player.state.width;
    final height = player.state.height;
    return width == null || width <= 0 || height == null || height <= 0;
  }

  // Fix Issue #57: Surface健康检查（每3秒检查一次）
  void _startSurfaceHealthCheck() {
    if (!Platform.isAndroid) {
      return; // 仅Android需要
    }

    _surfaceHealthCheckTimer?.cancel();
    _surfaceHealthCheckTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        if (_playerClosing) {
          timer.cancel();
          return;
        }

        // 检测：播放中但尺寸为null = Surface异常
        if (player.state.playing && _hasInvalidVideoSize()) {
          Log.w(
            "Surface健康检查失败: playing=${player.state.playing} "
            "width=${player.state.width} height=${player.state.height}",
          );
          unawaited(_handleInvalidVideoSize());
        }
      },
    );
  }

  /// A network outage can leave mpv in `playing == true` without emitting an
  /// error or end event. Watch the media position and route a confirmed stall
  /// through the existing bounded `mediaError` recovery path.
  void _startPlaybackStallWatchdog() {
    _playbackStallWatchdogTimer?.cancel();
    _playbackStallWatchdogTimer = Timer.periodic(
      _playbackStallSampleInterval,
      (_) => _checkPlaybackStall(),
    );
  }

  void _checkPlaybackStall() {
    if (_playerClosing ||
        !isPlaybackLoadGenerationCurrent(playbackLoadGeneration)) {
      return;
    }
    final state = player.state;
    if (!state.playing || state.completed) {
      _resetPlaybackStallSample();
      return;
    }
    final media = state.playlist.medias.isNotEmpty
        ? state.playlist.medias[state.playlist.index]
        : null;
    final mediaUri = media?.uri.trim();
    if (mediaUri == null || mediaUri.isEmpty) {
      return;
    }
    final generation = playbackLoadGeneration;
    if (_stallLoadGeneration != generation || _stallMediaUri != mediaUri) {
      _stallLoadGeneration = generation;
      _stallMediaUri = mediaUri;
      _stallLastPosition = state.position;
      _stallLastProgressAt = DateTime.now();
      _playbackStallRecoveryAttempts = 0;
      _playbackStallStableTimer?.cancel();
      _playbackStallStableTimer = null;
      return;
    }

    final now = DateTime.now();
    final position = state.position;
    if (_stallLastPosition == null || position != _stallLastPosition) {
      _stallLastPosition = position;
      _stallLastProgressAt = now;
      if (_playbackStallRecoveryAttempts > 0 &&
          _playbackStallStableTimer == null) {
        _playbackStallStableTimer = Timer(_stablePlaybackDuration, () {
          _playbackStallStableTimer = null;
          if (isPlaybackLoadGenerationCurrent(generation) &&
              player.state.playing) {
            _playbackStallRecoveryAttempts = 0;
          }
        });
      }
      return;
    }
    final lastProgressAt = _stallLastProgressAt;
    if (lastProgressAt == null ||
        now.difference(lastProgressAt) <
            (state.buffering
                ? _playbackBufferingStallTimeout
                : _playbackStallTimeout)) {
      return;
    }
    if (_surfaceRecoveryGraceUntil != null &&
        now.isBefore(_surfaceRecoveryGraceUntil!)) {
      return;
    }
    if (_playbackStallRecoveryInFlight ||
        _playbackStallRecoveryAttempts >= _maxSurfaceRecoveryAttempts ||
        (_lastPlaybackStallRecoveryAt != null &&
            now.difference(_lastPlaybackStallRecoveryAt!) <
                _playbackStallCooldown)) {
      return;
    }
    unawaited(_recoverPlaybackStall(generation, mediaUri));
  }

  Future<void> _recoverPlaybackStall(int generation, String mediaUri) async {
    if (_playbackStallRecoveryInFlight ||
        !isPlaybackLoadGenerationCurrent(generation) ||
        _stallMediaUri != mediaUri) {
      return;
    }
    _playbackStallRecoveryInFlight = true;
    _playbackStallRecoveryAttempts += 1;
    _lastPlaybackStallRecoveryAt = DateTime.now();
    _stallLastProgressAt = DateTime.now();
    Log.w(
      "检测到直播流长时间无进度，自动刷新播放 "
      "($_playbackStallRecoveryAttempts/$_maxSurfaceRecoveryAttempts)",
    );
    try {
      // LiveRoomController overrides mediaError and refreshes the current
      // line/URL with its existing generation and retry guards.
      mediaError("直播流停滞，自动刷新");
    } finally {
      _playbackStallRecoveryInFlight = false;
    }
  }

  void _resetPlaybackStallSample() {
    _stallLastPosition = null;
    _stallLastProgressAt = null;
    _playbackStallStableTimer?.cancel();
    _playbackStallStableTimer = null;
  }

  void mediaEnd() {
    WakelockPlus.disable();
    unawaited(stopBackgroundPlaybackService());
  }

  void mediaError(String error) {
    WakelockPlus.disable();
    unawaited(stopBackgroundPlaybackService());
  }

  Future<void> _syncBackgroundPlaybackService(bool playing) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (playing &&
        AppSettingsController.instance.allowBackgroundPlayback.value) {
      await BackgroundPlaybackService.instance.start();
    } else if (!playing ||
        !AppSettingsController.instance.allowBackgroundPlayback.value) {
      await BackgroundPlaybackService.instance.stop();
    }
  }

  Future<void> stopBackgroundPlaybackService() {
    return BackgroundPlaybackService.instance.stop();
  }

  Future<Map<String, String>> _readMpvDiagnosticProperties() async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return const {};
    }

    final result = <String, String>{};
    for (final name in const [
      'hwdec-current',
      'video-codec',
      'estimated-vf-fps',
      'container-fps',
      'video-bitrate',
    ]) {
      try {
        final value = (await platform.getProperty(name)).trim();
        if (value.isNotEmpty) {
          result[name] = value;
        }
      } catch (e) {
        Log.d("读取 mpv 播放属性 $name 失败: $e", false);
      }
    }
    return result;
  }

  Future<void> showDebugInfo() async {
    final mpvProperties = await _readMpvDiagnosticProperties();
    final videoTrack = player.state.track.video;
    final sourceResolution =
        '${player.state.width ?? 0}x${player.state.height ?? 0}';
    final outputResolution = videoOutputResolution;
    final hwdec = mpvProperties['hwdec-current'] ?? '无（软件解码或尚未开始）';
    final codec = mpvProperties['video-codec'] ?? videoTrack.codec ?? '未知';
    final fps = mpvProperties['estimated-vf-fps'] ??
        mpvProperties['container-fps'] ??
        videoTrack.fps?.toString() ??
        '未知';
    final videoBitrate = mpvProperties['video-bitrate'] ??
        videoTrack.bitrate?.toString() ??
        '未知';

    Widget diagnosticTile(String title, Object? value) {
      final text = value?.toString() ?? '未知';
      return ListTile(
        title: Text(title),
        subtitle: Text(text),
        onTap: () {
          Clipboard.setData(ClipboardData(text: '$title\n$text'));
        },
      );
    }

    Log.i(
      '播放诊断：hwdec=$hwdec codec=$codec fps=$fps bitrate=$videoBitrate '
      'source=$sourceResolution output=$outputResolution',
    );
    Utils.showBottomSheet(
      title: "播放信息",
      child: ListView(
        children: [
          diagnosticTile('实际硬件解码', hwdec),
          diagnosticTile('视频编码', codec),
          diagnosticTile('视频 FPS', fps),
          diagnosticTile('视频码率（bit/s）', videoBitrate),
          diagnosticTile('源分辨率', sourceResolution),
          diagnosticTile('输出纹理分辨率', outputResolution),
          diagnosticTile('VideoParams', player.state.videoParams),
          diagnosticTile('AudioParams', player.state.audioParams),
          diagnosticTile('Media', player.state.playlist),
          diagnosticTile('AudioTrack', player.state.track.audio),
          diagnosticTile('VideoTrack', videoTrack),
          diagnosticTile('AudioBitrate', player.state.audioBitrate),
          diagnosticTile('Volume', player.state.volume),
        ],
      ),
    );
  }

  Future<void> closePlayerResources() async {
    if (_playerClosing) {
      return;
    }
    _playerClosing = true;
    _cancelStablePlaybackTimer();
    clearTransientPlayerOverlays();
    await stopBackgroundPlaybackService();
    await waitForPlaybackOpen();
    await player.stop();
    if (smallWindowState.value) {
      await exitSmallWindow();
    }
    disposeStream();
    disposeDanmakuController();
    await resetSystem();
    await player.dispose();
  }

  @override
  void onClose() async {
    Log.w("播放器关闭");
    await closePlayerResources();
    super.onClose();
  }
}
