import 'dart:async';
import 'dart:io';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/custom_throttle.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/player/mobile_video_quality.dart';
import 'package:simple_live_app/modules/live_room/player/windows_video_quality.dart';
import 'package:simple_live_app/services/system_proxy_service.dart';
import 'package:simple_live_app/services/native_refresh_controller.dart';
import 'package:simple_live_app/services/playback_diagnostics.dart';
import 'package:simple_live_app/services/windows_shader_assets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

mixin PlayerMixin {
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();
  Future<void>? _playerInitialization;
  bool get hasInitializedPlayer => _playerInitialization != null;
  bool get isPlayerClosing => false;
  @visibleForTesting
  bool get isWindowsPlayback => Platform.isWindows;
  @visibleForTesting
  bool get isAndroidPlayback => Platform.isAndroid;
  @visibleForTesting
  bool get isIosPlayback => Platform.isIOS;
  bool get isMobilePlayback => isAndroidPlayback || isIosPlayback;
  double get windowsDisplayHz => 0;
  bool _windowsInterpolationWasEnabled = false;
  bool _mobileInterpolationWasEnabled = false;
  Size? _windowsViewportSize;
  double _windowsViewportDpr = 1.0;
  ({int width, int height})? _appliedWindowsOutputSize;
  Timer? _windowsOutputResizeTimer;
  PlaybackDiagnostics? playbackDiagnostics;
  final startupTiming = ''.obs;
  void playbackSample(PlaybackSnapshot sample) {}

  /// 播放器实例
  late final player = Player(
    configuration: PlayerConfiguration(
      title: "Simple Live Player",
      bufferSize: AppSettingsController.instance.playerBufferSize.value
              .clamp(16, 256) *
          1024 *
          1024,
      logLevel: AppSettingsController.instance.logEnable.value
          ? MPVLogLevel.warn
          : MPVLogLevel.error,
    ),
  );

  /// 同一播放器只配置一次；失败时允许下次打开直播流重新尝试。
  Future<void> initializePlayer() async {
    final pending = _playerInitialization;
    if (pending != null) {
      await pending;
      return;
    }
    final initialization = _configurePlayer();
    _playerInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_playerInitialization, initialization)) {
        _playerInitialization = null;
      }
      rethrow;
    }
  }

  String playbackBufferWait({bool adaptive = false}) =>
      switch (AppSettingsController.instance.playerBufferMode.value) {
        1 => '2.5',
        2 => isWindowsPlayback ? '0.3' : '0.5',
        _ when adaptive => isWindowsPlayback ? '1.5' : '2',
        _ => isWindowsPlayback ? '0.5' : '0.8',
      };

  Future<void> _applyWindowsSuperResolution(NativePlayer pp) async {
    if (!isWindowsPlayback || isPlayerClosing) return;
    final enabled = AppSettingsController.instance.windowsSuperResolution.value;
    if (!enabled) {
      await pp.setProperty('glsl-shaders', '');
      return;
    }
    final shaderPath = await WindowsShaderAssets.resolveFsrcnnxPath();
    if (shaderPath != null && shaderPath.isNotEmpty) {
      await pp.setProperty('glsl-shaders', shaderPath);
    }
  }

  Future<bool> _setInterpolationProperties(
    NativePlayer pp, {
    required bool enabled,
    required bool wasEnabled,
  }) async {
    if (enabled) {
      await pp.setProperty('video-sync', 'display-resample');
      await pp.setProperty('interpolation', 'yes');
      await pp.setProperty('tscale', 'oversample');
      final hz = windowsDisplayHz;
      if (hz > 0) {
        await pp.setProperty('override-display-fps', hz.toStringAsFixed(3));
      }
      return true;
    }
    await pp.setProperty('interpolation', 'no');
    await pp.setProperty('video-sync', 'audio');
    if (wasEnabled) {
      await pp.setProperty('override-display-fps', '0');
    }
    return false;
  }

  Future<void> _applyWindowsInterpolation(NativePlayer pp) async {
    if (!isWindowsPlayback || isPlayerClosing) return;
    _windowsInterpolationWasEnabled = await _setInterpolationProperties(
      pp,
      enabled: AppSettingsController.instance.windowsInterpolation.value,
      wasEnabled: _windowsInterpolationWasEnabled,
    );
  }

  Future<void> _applyMobileDeband(NativePlayer pp) async {
    if (!isMobilePlayback || isPlayerClosing) return;
    await MobileVideoQuality.applyDeband(
      pp,
      enabled: AppSettingsController.instance.mobileDeband.value,
    );
  }

  Future<void> _applyMobileInterpolation(NativePlayer pp) async {
    if (!isMobilePlayback || isPlayerClosing) return;
    _mobileInterpolationWasEnabled = await _setInterpolationProperties(
      pp,
      enabled: AppSettingsController.instance.mobileInterpolation.value,
      wasEnabled: _mobileInterpolationWasEnabled,
    );
  }

  void updateWindowsVideoViewport(Size size, double devicePixelRatio) {
    if (!Platform.isWindows || isPlayerClosing) return;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        !devicePixelRatio.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        devicePixelRatio <= 0) {
      return;
    }
    if (_windowsViewportSize == size &&
        _windowsViewportDpr == devicePixelRatio &&
        _appliedWindowsOutputSize != null) {
      return;
    }
    _windowsViewportSize = size;
    _windowsViewportDpr = devicePixelRatio;
    final srcW = player.state.width;
    final srcH = player.state.height;
    if (srcW == null || srcH == null || srcW <= 0 || srcH <= 0) {
      return;
    }
    scheduleWindowsVideoOutputSync();
  }

  void scheduleWindowsVideoOutputSync({
    bool reset = false,
    Duration delay = const Duration(milliseconds: 250),
  }) {
    if (!Platform.isWindows || isPlayerClosing) return;
    if (reset) {
      _appliedWindowsOutputSize = null;
    }
    _windowsOutputResizeTimer?.cancel();
    _windowsOutputResizeTimer = Timer(delay, _syncWindowsVideoOutputSize);
  }

  void cancelWindowsVideoOutputSync() {
    _windowsOutputResizeTimer?.cancel();
    _windowsOutputResizeTimer = null;
  }

  void _syncWindowsVideoOutputSize() {
    _windowsOutputResizeTimer = null;
    if (!Platform.isWindows || isPlayerClosing) return;
    final viewport = _windowsViewportSize;
    if (viewport == null) return;
    final srcW = player.state.width;
    final srcH = player.state.height;
    if (srcW == null || srcH == null || srcW <= 0 || srcH <= 0) return;
    final target = WindowsVideoQuality.computeOutputSize(
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      devicePixelRatio: _windowsViewportDpr,
      sourceWidth: srcW,
      sourceHeight: srcH,
      scaleMode: AppSettingsController.instance.scaleMode.value,
    );
    if (target == null || target == _appliedWindowsOutputSize) return;
    _appliedWindowsOutputSize = target;
    unawaited(
      videoController
          .setSize(width: target.width, height: target.height)
          .catchError((Object _) {}),
    );
  }

  Future<void> _configurePlayer() async {
    var pp = player.platform as NativePlayer;
    final settings = AppSettingsController.instance;
    if (isWindowsPlayback) {
      await pp.setProperty('http-proxy', '');
      await WindowsVideoQuality.applyBaseProperties(pp);
      await _applyWindowsSuperResolution(pp);
      await _applyWindowsInterpolation(pp);
      // 保留音频变速防变调，配合稳态画质参数。
      await pp.setProperty('audio-pitch-correction', 'yes');
    } else if (isMobilePlayback) {
      await MobileVideoQuality.applyBaseProperties(
        pp,
        isAndroid: isAndroidPlayback,
      );
      await _applyMobileDeband(pp);
      await _applyMobileInterpolation(pp);
      await pp.setProperty('audio-pitch-correction', 'yes');
    } else {
      // Keep source timestamps/frame count; physical display Hz is managed separately.
      await pp.setProperty('interpolation', 'no');
      await pp.setProperty('video-sync', 'audio');
      await pp.setProperty('audio-pitch-correction', 'yes');
      await pp.setProperty('audio-resample-cutoff', '0.96');
    }
    // 直播使用有上限的内存缓存。cache-secs 是预读上限，不是起播等待时间。
    final bufferMode = settings.playerBufferMode.value;
    final cacheSecs = switch (bufferMode) {
      1 => '30',
      2 => '10',
      _ => isWindowsPlayback ? '30' : '20',
    };
    await pp.setProperty('cache-on-disk', 'no');
    await pp.setProperty('cache-secs', cacheSecs);
    await pp.setProperty(
        'demuxer-max-back-bytes', isWindowsPlayback ? '16777216' : '8388608');
    await pp.setProperty('cache-pause', 'yes');
    // Desktop live-edge streams may deliver in real time: requiring two seconds
    // here can delay startup while leaving the first decoded image frozen.
    // Keep initial buffering enabled, but use a bounded half-second desktop gate.
    await pp.setProperty('cache-pause-wait', playbackBufferWait());
    // 起播先积累少量数据，避免刚出画面就因缓存耗尽而停顿。
    await pp.setProperty('cache-pause-initial', 'yes');
    await pp.setProperty('network-timeout', '10');
    // 底层 FFmpeg 网络抖动自动无感续传，减少瞬断直接触发黑屏重开流。
    await pp.setProperty(
      'stream-lavf-o',
      'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=2',
    );
    playbackDiagnostics ??= PlaybackDiagnostics(
      read: (key) => pp.getProperty(key, waitForInitialization: false),
      onSample: playbackSample,
    );
    // 设置音频输出驱动
    if (isWindowsPlayback && settings.windowsAudioExclusive.value) {
      await pp.setProperty('ao', 'wasapi');
      await pp.setProperty('audio-exclusive', 'yes');
    } else if (settings.customPlayerOutput.value) {
      if (player.platform is NativePlayer) {
        await (player.platform as dynamic).setProperty(
          'ao',
          settings.outputPolicy
              .audioOutput(settings.audioOutputDriver.value),
        );
      }
    }
    // media_kit 仓库更新导致的问题，临时解决办法
    if (isAndroidPlayback) {
      await pp.setProperty('force-seekable', 'yes');
    }
  }

  Future<void> configurePlaybackProxy(String url) async {
    if (!Platform.isAndroid) return;
    final proxy = SystemProxyService.instance.playbackProxy(url) ?? '';
    // Native mpv is outside dart:io and must receive the same per-host routing.
    await (player.platform as NativePlayer).setProperty('http-proxy', proxy);
  }

  Future<void> setVideoTrackEnabled(bool enabled) async {
    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('vid', enabled ? 'auto' : 'no');
      }
    } catch (e) {
      Log.d('切换视频轨道状态失败：$e');
    }
  }

  /// 视频控制器
  late final videoController = VideoController(
    player,
    configuration: AppSettingsController.instance.outputPolicy.videoConfiguration(
      custom: AppSettingsController.instance.customPlayerOutput.value,
      compatibility: AppSettingsController.instance.playerCompatMode.value,
      hardwareDecode: AppSettingsController.instance.hardwareDecode.value,
      videoOutput: AppSettingsController.instance.videoOutputDriver.value,
      hardwareDecoder: AppSettingsController.instance.videoHardwareDecoder.value,
    ),
  );
}

mixin PlayerStateMixin on PlayerMixin {
  ///音量控制条计时器
  Timer? hidevolumeTimer;

  /// 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  /// 是否处于纯音频听播模式
  RxBool audioOnlyMode = false.obs;

  /// 是否显示弹幕
  RxBool showDanmakuState = false.obs;

  /// 是否显示控制器
  RxBool showControlsState = false.obs;

  /// 是否显示设置窗口
  RxBool showSettingState = false.obs;

  /// 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  /// 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;

  /// 是否处于全屏状态
  RxBool fullScreenState = false.obs;

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

  /// 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  /// 是否为竖屏直播间
  var isVertical = false.obs;

  /// 当前这条流是否已有播放进度（不是 playing 请求标志，也不代表视频首帧）。
  /// 起播阶段的缓冲属于正常等待，不该提示“缓冲中”。
  var hasPlayed = false.obs;

  Widget? danmakuView;

  var showQualites = false.obs;
  var showLines = false.obs;

  /// 隐藏控制器
  void hideControls() {
    showControlsState.value = false;
    hideControlsTimer?.cancel();
  }

  void setLockState() {
    lockControlsState.value = !lockControlsState.value;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  /// 显示控制器
  void showControls() {
    showControlsState.value = true;
    resetHideControlsTimer();
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
    if (Platform.isWindows) {
      scheduleWindowsVideoOutputSync(reset: true, delay: Duration.zero);
    }
  }
}
mixin PlayerDanmakuMixin on PlayerStateMixin {
  /// 弹幕控制器
  DanmakuController? danmakuController;

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
  }

  Future<void> setAudioOnlyMode(bool enabled) async {
    if (audioOnlyMode.value == enabled) return;
    audioOnlyMode.value = enabled;
    if (enabled) {
      danmakuController?.clear();
    }
    await setVideoTrackEnabled(!enabled);
  }

  Future<void> toggleAudioOnlyMode() => setAudioOnlyMode(!audioOnlyMode.value);

  void addDanmaku(List<DanmakuContentItem> items) {
    if (!showDanmakuState.value) {
      return;
    }
    for (var item in items) {
      danmakuController?.addDanmaku(item);
    }
  }
}
mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  bool _changingFullScreen = false;
  bool _restoringWindowSize = false;
  bool _playerClosing = false;

  @override
  bool get isPlayerClosing => _playerClosing;

  final pip = Floating();
  StreamSubscription<bool>? _pipSubscription;
  bool _enteringPip = false;
  bool _insidePip = false;
  bool get isInsidePip => _insidePip;

  //final VolumeController volumeController = VolumeController();

  /// 初始化一些系统状态
  void initSystem() async {
    if (Platform.isAndroid || Platform.isIOS) {
      VolumeController.instance.showSystemUI = false;
    }

    // 屏幕常亮
    //WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();

    // 进入全屏模式
    if (AppSettingsController.instance.autoFullScreen.value) {
      enterFullScreen();
    }
  }

  /// 释放一些系统状态
  Future resetSystem() async {
    await _pipSubscription?.cancel();
    _pipSubscription = null;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    await setPortraitOrientation();
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
    if (_restoringWindowSize) return;
    if (Platform.isWindows) {
      await _setWindowsFullScreen(true);
      return;
    }
    if (_playerClosing || _changingFullScreen || fullScreenState.value) return;
    _changingFullScreen = true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        //全屏
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: []);
        if (!isVertical.value) {
          //横屏
          await setLandscapeOrientation();
        }
      } else {
        if (_playerClosing) return;
        await windowManager.setFullScreen(true);
      }
      if (_playerClosing) {
        if (Platform.isAndroid || Platform.isIOS) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
              overlays: SystemUiOverlay.values);
          await setPortraitOrientation();
        } else {
          await windowManager.setFullScreen(false);
          await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        }
        return;
      }
      fullScreenState.value = true;
    } finally {
      _changingFullScreen = false;
    }
    //danmakuController?.clear();
  }

  /// 退出全屏
  Future<void> exitFull() async {
    if (smallWindowState.value) {
      await exitSmallWindow();
      return;
    }
    if (Platform.isWindows) {
      await _setWindowsFullScreen(false);
      return;
    }
    if (_changingFullScreen || !fullScreenState.value) return;
    _changingFullScreen = true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
            overlays: SystemUiOverlay.values);
        await setPortraitOrientation();
      } else {
        await windowManager.setFullScreen(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
      fullScreenState.value = false;
    } finally {
      _changingFullScreen = false;
    }

    //danmakuController?.clear();
  }

  /// Windows 查询、切换和状态同步共用一个锁，避免连续双击交叉执行。
  Future<void> _setWindowsFullScreen(bool? requested) async {
    if ((_playerClosing && requested != false) ||
        _changingFullScreen ||
        smallWindowState.value) {
      return;
    }
    _changingFullScreen = true;
    try {
      final current = await windowManager.isFullScreen();
      if (_playerClosing && requested != false) return;
      final target = requested ?? !current;
      // 在 resize 前准备布局；即使内部状态过期，也按实际窗口决定方向。
      fullScreenState.value = target;
      if (current != target) await windowManager.setFullScreen(target);
      if (_playerClosing && target) await windowManager.setFullScreen(false);
    } finally {
      try {
        fullScreenState.value = await windowManager.isFullScreen();
      } finally {
        _changingFullScreen = false;
      }
    }
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;

  Future<void> restoreDefaultWindowSize() async {
    if (Platform.isAndroid ||
        Platform.isIOS ||
        _playerClosing ||
        _changingFullScreen ||
        _restoringWindowSize) {
      return;
    }
    _restoringWindowSize = true;
    try {
      // Restore native state before resizing: setSize alone cannot resize a
      // maximized/fullscreen window. Leave the user's window position intact.
      if (smallWindowState.value) await exitSmallWindow();
      await exitFull();
      if (_playerClosing) return;
      if (await windowManager.isMaximized()) await windowManager.unmaximize();
      if (_playerClosing) return;
      await windowManager.setSize(Constant.kDefaultWindowSize);
    } finally {
      _restoringWindowSize = false;
    }
  }

  ///小窗模式()
  Future<void> enterSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS) &&
        !_changingFullScreen &&
        !fullScreenState.value) {
      _changingFullScreen = true;
      try {
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
        smallWindowState.value = true;
        fullScreenState.value = true;
      } finally {
        _changingFullScreen = false;
      }
    }
  }

  ///退出小窗模式()
  Future<void> exitSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS) &&
        smallWindowState.value &&
        !_changingFullScreen) {
      _changingFullScreen = true;
      try {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        if (_lastWindowSize != null) {
          await windowManager.setSize(_lastWindowSize!);
        }
        if (_lastWindowPosition != null) {
          await windowManager.setPosition(_lastWindowPosition!);
        }
        await windowManager.setAlwaysOnTop(false);
        smallWindowState.value = false;
        fullScreenState.value = false;
      } finally {
        _changingFullScreen = false;
      }
      //windowManager.setAlignment(Alignment.center);
    }
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      await AutoOrientation.landscapeAutoMode();
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

  Future<void> enablePIP() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _playerClosing ||
        _enteringPip ||
        _insidePip) {
      return;
    }
    _enteringPip = true;
    try {
      if (!await pip.isPipAvailable) {
        if (!_playerClosing) SmartDialog.showToast("设备不支持小窗播放");
        return;
      }
      if (_playerClosing) return;
      final beforeDanmaku = showDanmakuState.value;
      final beforeControls = showControlsState.value;
      final width = player.state.width ?? 0;
      final height = player.state.height ?? 0;
      final ratio = height > width || (width == 0 && isVertical.value)
          ? const Rational.vertical()
          : const Rational.landscape();
      final status = await pip.enable(ImmediatePiP(aspectRatio: ratio));
      if (_playerClosing) return;
      if (status != PiPStatus.enabled) {
        SmartDialog.showToast("无法进入小窗播放");
        return;
      }
      _insidePip = true;
      if (AppSettingsController.instance.pipHideDanmu.value) {
        showDanmakuState.value = false;
      }
      danmakuController?.clear();
      showControlsState.value = false;

      void restore() {
        _insidePip = false;
        final subscription = _pipSubscription;
        _pipSubscription = null;
        unawaited(subscription?.cancel());
        if (_playerClosing) return;
        danmakuController?.clear();
        showDanmakuState.value = beforeDanmaku;
        showControlsState.value = beforeControls;
      }

      _pipSubscription = const EventChannel('simple_live/pip')
          .receiveBroadcastStream()
          .cast<bool>()
          .listen((inPip) {
        if (!inPip) restore();
      }, onError: (Object error) {
        Log.logPrint(error);
        restore();
      }, onDone: restore);
    } catch (e) {
      Log.logPrint(e);
      if (!_playerClosing) SmartDialog.showToast("无法进入小窗播放");
    } finally {
      _enteringPip = false;
    }
  }
}
mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  /// 单击显示/隐藏控制器
  void onTap() {
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  //桌面端操控
  void onEnter(PointerEnterEvent event) {
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    if (showControlsState.value) {
      hideControls();
    }
  }

  void onHover(PointerHoverEvent event, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final targetPosition = screenHeight * 0.25; // 计算屏幕顶部25%的位置
    if (event.position.dy <= targetPosition ||
        event.position.dy >= targetPosition * 3) {
      if (!showControlsState.value) {
        showControls();
      }
    }
  }

  /// 双击全屏/退出全屏
  Future<void> onDoubleTap() async {
    if (lockControlsState.value || _restoringWindowSize) {
      return;
    }
    if (Platform.isWindows && !smallWindowState.value) {
      await _setWindowsFullScreen(null);
      return;
    }
    if (fullScreenState.value) {
      await exitFull();
    } else {
      await enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;

  DelayedThrottle? throttle;

  /// 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dy = details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < Get.height * 0.25 || dy > Get.height * 0.75) {
      return;
    }

    verStartPosition = dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    verticalDragging = true;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      showGestureTip.value = true;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _currentVolume = await VolumeController.instance.getVolume();
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _currentBrightness = await ScreenBrightness.instance.application;
    }
  }

  /// 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (verticalDragging == false) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    //String text = "";
    //double value = 0.0;

    Log.logPrint("$verStartPosition/${e.globalPosition.dy}");

    if (leftVerticalDrag) {
      setGestureBrightness(e.globalPosition.dy);
    } else {
      setGestureVolume(e.globalPosition.dy);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
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
    gestureTipText.value = "音量 $volume%";
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future _realSetVolume(int volume) async {
    Log.logPrint(volume);
    VolumeController.instance.setVolume(volume / 100);
  }

  void setGestureBrightness(double dy) {
    double value = 0.0;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      var seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
      ScreenBrightness.instance.setApplicationScreenBrightness(seek);

      gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
      Log.logPrint(value);
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      var seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }

      ScreenBrightness.instance.setApplicationScreenBrightness(seek);
      gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
      Log.logPrint(value);
    }
  }

  /// 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    showGestureTip.value = false;
  }
}

class PlayerController extends BaseController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {
  @override
  void onInit() {
    initSystem();
    initStream();
    initNativeRefresh();
    //设置音量
    player.setVolume(AppSettingsController.instance.playerVolume.value);
    super.onInit();
  }

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  bool _streamsInitialized = false;
  NativeRefreshController? _nativeRefresh;
  StreamSubscription<Tracks>? _sourceTracks;
  Worker? _superResWorker;
  Worker? _interpolationWorker;
  Worker? _mobileDebandWorker;
  Worker? _mobileInterpolationWorker;
  Worker? _displayHzWorker;

  double get nativeDisplayHz => _nativeRefresh?.displayHz.value ?? 0;

  @override
  double get windowsDisplayHz => nativeDisplayHz;

  void initNativeRefresh() {
    if (_nativeRefresh != null || _playerClosing) return;
    final refresh = _nativeRefresh = NativeRefreshController();
    refresh.start();
    if (isWindowsPlayback || isMobilePlayback) {
      _displayHzWorker = ever<double>(refresh.displayHz, (_) {
        if (_playerClosing ||
            !hasInitializedPlayer ||
            player.platform is! NativePlayer) {
          return;
        }
        final pp = player.platform as NativePlayer;
        if (isWindowsPlayback &&
            AppSettingsController.instance.windowsInterpolation.value) {
          unawaited(_applyWindowsInterpolation(pp).catchError((Object _) {}));
        } else if (isMobilePlayback &&
            AppSettingsController.instance.mobileInterpolation.value) {
          unawaited(_applyMobileInterpolation(pp).catchError((Object _) {}));
        }
      });
    }
    _sourceTracks = player.stream.tracks.listen((tracks) {
      final selected = player.state.track.video.id;
      final videos = tracks.video.where((v) => v.fps != null && v.fps! > 0).toList();
      if (videos.isEmpty) return;
      final track = videos.firstWhere((v) => v.id == selected, orElse: () => videos.first);
      unawaited(refresh.updateSource(track.fps!));
    });
  }

  void initStream() {
    if (_playerClosing || _streamsInitialized) return;
    _streamsInitialized = true;
    if (Get.isRegistered<AppSettingsController>()) {
      final settings = AppSettingsController.instance;
      if (isWindowsPlayback) {
        _superResWorker = ever<bool>(settings.windowsSuperResolution, (_) {
          if (!_playerClosing &&
              hasInitializedPlayer &&
              player.platform is NativePlayer) {
            unawaited((() async {
              try {
                await _applyWindowsSuperResolution(
                    player.platform as NativePlayer);
              } catch (_) {}
            })());
          }
        });
        _interpolationWorker = ever<bool>(settings.windowsInterpolation, (_) {
          if (!_playerClosing &&
              hasInitializedPlayer &&
              player.platform is NativePlayer) {
            unawaited((() async {
              try {
                await _applyWindowsInterpolation(
                    player.platform as NativePlayer);
              } catch (_) {}
            })());
          }
        });
      } else if (isMobilePlayback) {
        _mobileDebandWorker = ever<bool>(settings.mobileDeband, (_) {
          if (!_playerClosing &&
              hasInitializedPlayer &&
              player.platform is NativePlayer) {
            unawaited((() async {
              try {
                await _applyMobileDeband(player.platform as NativePlayer);
              } catch (_) {}
            })());
          }
        });
        _mobileInterpolationWorker =
            ever<bool>(settings.mobileInterpolation, (_) {
          if (!_playerClosing &&
              hasInitializedPlayer &&
              player.platform is NativePlayer) {
            unawaited((() async {
              try {
                await _applyMobileInterpolation(
                    player.platform as NativePlayer);
              } catch (_) {}
            })());
          }
        });
      }
    }
    _bufferingSubscription = player.stream.buffering.listen(mediaBuffering);
    _errorSubscription = player.stream.error.listen((event) {
      Log.d("播放器错误：$event");
      // 跳过无音频输出的错误
      // Could not open/initialize audio device -> no sound.
      if (event.contains('no sound.')) {
        return;
      }
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _playingSubscription = player.stream.playing.listen((event) {
      playbackDiagnostics?.setPlaying(event);
      if (event) {
        WakelockPlus.enable();
        Log.d("Playing");
      }
    });

    _positionSubscription = player.stream.position.listen((position) {
      mediaPosition(position);
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      if (!kReleaseMode || AppSettingsController.instance.logEnable.value) {
        Log.d("播放器日志：$event");
      }
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
      if (Platform.isWindows) {
        scheduleWindowsVideoOutputSync(
          reset: true,
          delay: const Duration(milliseconds: 180),
        );
      }
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
      if (Platform.isWindows) {
        scheduleWindowsVideoOutputSync(
          reset: true,
          delay: const Duration(milliseconds: 180),
        );
      }
    });
  }

  void disposeStream() {
    playbackDiagnostics?.dispose();
    _sourceTracks?.cancel();
    _superResWorker?.dispose();
    _superResWorker = null;
    _interpolationWorker?.dispose();
    _interpolationWorker = null;
    _mobileDebandWorker?.dispose();
    _mobileDebandWorker = null;
    _mobileInterpolationWorker?.dispose();
    _mobileInterpolationWorker = null;
    _displayHzWorker?.dispose();
    _displayHzWorker = null;
    cancelWindowsVideoOutputSync();
    final refresh = _nativeRefresh;
    _nativeRefresh = null;
    if (refresh != null) unawaited(refresh.dispose());
    _streamsInitialized = false;
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
    _pipSubscription?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
  }

  void mediaEnd() {
    WakelockPlus.disable();
  }

  void mediaError(String error) {
    WakelockPlus.disable();
  }

  void mediaBuffering(bool buffering) {}

  void mediaPosition(Duration position) {
    if (position > Duration.zero) hasPlayed.value = true;
  }

  void showDebugInfo() {
    final refresh = _nativeRefresh;
    Utils.showBottomSheet(
      title: "播放信息",
      child: ListView(
        children: [
          Obx(() => ListTile(
            title: const Text('开播阶段耗时'),
            subtitle: Text(startupTiming.value.isEmpty
                ? '等待播放进度，非首帧渲染计时' : startupTiming.value),
          )),
          if (refresh != null) Obx(() {
            final settings = AppSettingsController.instance;
            final interpOn =
                (isWindowsPlayback && settings.windowsInterpolation.value) ||
                    (isMobilePlayback && settings.mobileInterpolation.value);
            return ListTile(
              title: const Text('原生帧率 / 屏幕刷新率'),
              subtitle: Text('直播源 ${refresh.sourceFps.value > 0 ? '${refresh.sourceFps.value.toStringAsFixed(2)} fps' : '读取中'} · '
                  '屏幕 ${refresh.displayHz.value > 0 ? '${refresh.displayHz.value.toStringAsFixed(2)} Hz' : '系统管理'} · '
                  '${interpOn ? '插帧开启（时间域平滑）' : '插帧关闭'}'),
            );
          }),
          if (playbackDiagnostics != null) Obx(() {
            final sample = playbackDiagnostics!.snapshot.value;
            String fps(double? v) => v == null ? '未提供' : '${v.toStringAsFixed(2)} fps';
            return ListTile(
              title: const Text('实时播放统计（每秒更新）'),
              subtitle: Text('源帧率（解复用器）：${fps(sample.sourceFps)}\n'
                '解码/滤镜输出估计：${fps(sample.outputFps)}\n'
                '渲染呈现帧率：当前后端未提供，不能用屏幕 Hz 代替\n'
                '输出丢帧：${sample.voDrops ?? '未提供'} · 解码丢帧：${sample.decoderDrops ?? '未提供'}\n'
                '当前硬解码：${sample.hardwareDecoder.isEmpty ? '未提供' : sample.hardwareDecoder}\n'
                '预读缓存：${sample.cacheSeconds?.toStringAsFixed(2) ?? '未提供'} 秒'),
            );
          }),
          ListTile(
            title: const Text("Resolution"),
            subtitle: Text('${player.state.width}x${player.state.height}'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      "Resolution\n${player.state.width}x${player.state.height}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoParams"),
            subtitle: Text(player.state.videoParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoParams\n${player.state.videoParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioParams"),
            subtitle: Text(player.state.audioParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioParams\n${player.state.audioParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Media"),
            subtitle: Text(player.state.playlist.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Media\n${player.state.playlist}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioTrack"),
            subtitle: Text(player.state.track.audio.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoTrack"),
            subtitle: Text(player.state.track.video.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioBitrate"),
            subtitle: Text(player.state.audioBitrate.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioBitrate\n${player.state.audioBitrate}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Volume"),
            subtitle: Text(player.state.volume.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Volume\n${player.state.volume}",
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void onClose() async {
    Log.w("播放器关闭");
    _playerClosing = true;
    hideControlsTimer?.cancel();
    hidevolumeTimer?.cancel();
    hideSeekTipTimer?.cancel();
    // 先解绑事件，避免等待窗口/系统恢复时迟到的错误触发恢复或唤醒锁。
    disposeStream();
    try {
      if (smallWindowState.value) {
        await exitSmallWindow();
      }
      if (fullScreenState.value) {
        await exitFull();
      }
      disposeDanmakuController();
      await resetSystem();
    } finally {
      // 窗口或系统插件恢复失败，也必须释放原生解码和输出资源。
      try {
        await player.dispose();
      } finally {
        super.onClose();
      }
    }
  }
}
