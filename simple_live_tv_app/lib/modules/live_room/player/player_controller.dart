import 'dart:async';
import 'dart:io';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

mixin PlayerMixin {
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  /// 播放器实例
  late final player = Player(
    configuration: const PlayerConfiguration(
      title: "Simple Live Player",
      // bufferSize:
      //     // media-kit #549
      //     AppSettingsController.instance.playerBufferSize.value * 1024 * 1024,
    ),
  );

  /// 视频控制器
  late final videoController = VideoController(
    player,
    configuration: MpvOptionsService.videoControllerConfiguration(),
  );

  Future<void> initializePlayer() async {
    await MpvOptionsService.applyToPlayer(player);
  }
}
mixin PlayerStateMixin on PlayerMixin {
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
  }
}
mixin PlayerDanmakuMixin on PlayerStateMixin {
  /// 弹幕控制器
  DanmakuController? danmakuController;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
    // danmakuController?.updateOption(
    //   DanmakuOption(
    //     fontSize: AppSettingsController.instance.danmuSize.value.w,
    //     area: AppSettingsController.instance.danmuArea.value,
    //     duration: AppSettingsController.instance.danmuSpeed.value,
    //     opacity: AppSettingsController.instance.danmuOpacity.value,
    //     strokeWidth: AppSettingsController.instance.danmuStrokeWidth.value.w,
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

  /// 初始化一些系统状态
  void initSystem() async {
    // 屏幕常亮
    WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();
  }

  /// 释放一些系统状态
  Future resetSystem() async {
    await WakelockPlus.disable();
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
}

class PlayerController extends BaseController
    with PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin, PlayerSystemMixin {
  @override
  void onInit() {
    initSystem();
    initStream();
    super.onInit();
  }

  var width = 0.obs;
  var height = 0.obs;

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;
  DateTime? _lastAudioDiagnosticTime;

  void initStream() {
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
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("播放器日志：$event");
      _trackVideoDecodeError(event);
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.w(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      width.value = event ?? 0;
      // isVertical.value =
      //     (player.state.height ?? 9) > (player.state.width ?? 16);
      _checkInvalidVideoSize(event);
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.w(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      height.value = event ?? 0;
      // isVertical.value =
      //     (player.state.height ?? 9) > (player.state.width ?? 16);
      _checkInvalidVideoSize(event);
    });
  }

  int _invalidVideoSizeSamples = 0;

  /// 播放中视频尺寸连续异常（null/0）：Surface/解码输出失效的信号
  /// （对齐移动端 Issue#57），连续 2 次后交给 onInvalidVideoSize 恢复
  void _checkInvalidVideoSize(int? event) {
    if (event != null && event > 0) {
      _invalidVideoSizeSamples = 0;
      return;
    }
    if (!player.state.playing) {
      return;
    }
    _invalidVideoSizeSamples += 1;
    if (_invalidVideoSizeSamples >= 2) {
      _invalidVideoSizeSamples = 0;
      onInvalidVideoSize();
    }
  }

  /// 视频输出失效回调，由 LiveRoomController 实现恢复（重开当前流）
  void onInvalidVideoSize() {}

  Future<int?> readVideoOutputDropCount() async {
    if (!Platform.isAndroid || player.platform is! NativePlayer) {
      return null;
    }
    try {
      final value = await (player.platform as NativePlayer)
          .getProperty('frame-drop-count');
      return int.tryParse(value.trim());
    } catch (e) {
      Log.d("读取 mpv 输出丢帧数失败: $e");
      return null;
    }
  }

  /// 黑屏判据（音频时钟在走但视频不渲染，位置看门狗看不见）：
  /// mpv 的 vd（视频解码器）持续报 error 说明解码管线已挂，
  /// 按窗口计数超阈值即交由 onVideoDecodeStall 走停滞恢复链。
  /// 阈值取 15 次/30 秒：正常流偶尔的解码毛刺到不了这个量级，
  /// 而 25fps 的死视频轨约 1 秒就能报够。
  final List<DateTime> _videoDecodeErrorTimes = [];
  DateTime? _lastVideoDecodeStallAt;
  static const int _videoDecodeErrorThreshold = 15;
  static const Duration _videoDecodeErrorWindow = Duration(seconds: 30);
  static const Duration _videoDecodeStallCooldown = Duration(seconds: 30);

  void _trackVideoDecodeError(PlayerLog event) {
    if (event.prefix != "vd" || event.level != "error") {
      return;
    }
    if (!player.state.playing || player.state.completed) {
      return;
    }
    final now = DateTime.now();
    _videoDecodeErrorTimes.add(now);
    _videoDecodeErrorTimes.removeWhere(
      (t) => t.isBefore(now.subtract(_videoDecodeErrorWindow)),
    );
    if (_videoDecodeErrorTimes.length < _videoDecodeErrorThreshold) {
      return;
    }
    if (_lastVideoDecodeStallAt != null &&
        now.difference(_lastVideoDecodeStallAt!) < _videoDecodeStallCooldown) {
      return;
    }
    _lastVideoDecodeStallAt = now;
    _videoDecodeErrorTimes.clear();
    Log.w(
      "${_videoDecodeErrorWindow.inSeconds}秒内视频解码错误达"
      "$_videoDecodeErrorThreshold 次，判定画面停滞",
    );
    onVideoDecodeStall();
  }

  /// 画面停滞回调（声音正常但视频解码持续失败），由 LiveRoomController
  /// 接入停滞恢复链（重刷→风暴记账→自动换台）
  void onVideoDecodeStall() {}

  void disposeStream() {
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
  }

  void mediaEnd() {}

  void mediaError(String error) {}

  @override
  void onClose() async {
    Log.w("播放器关闭");
    disposeStream();
    disposeDanmakuController();
    await resetSystem();
    await player.dispose();
    super.onClose();
  }
}
