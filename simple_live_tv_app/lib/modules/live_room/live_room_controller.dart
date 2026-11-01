import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/desktop_startup_args.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/auto_switch_item.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_tv_app/services/auto_switch_list_service.dart';
import 'package:simple_live_tv_app/services/current_room_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

class LiveRoomController extends PlayerController with WidgetsBindingObserver {
  static const _appWindowChannel = MethodChannel('simple_live_tv/app_window');
  final Site pSite;
  final String pRoomId;
  late LiveDanmaku liveDanmaku;
  LiveRoomController({
    required this.pSite,
    required this.pRoomId,
  }) {
    rxSite = pSite.obs;
    rxRoomId = pRoomId.obs;
    liveDanmaku = site.liveSite.getDanmaku();
  }
  final FocusNode focusNode = FocusNode();
  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var totalViewers = 0.obs;
  var followed = false.obs;
  var specialFollowed = false.obs;
  var liveStatus = false.obs;
  var playbackLoadError = "".obs;
  var muted = false.obs;
  bool _autoSwitchingRoom = false;

  /// 连续“未开播”自动换台保护：防止状态接口异常时无限换台
  int _autoSwitchOfflineHops = 0;
  DateTime? _firstOfflineHopAt;
  static const int _maxAutoSwitchOfflineHops = 3;

  /// 离线换台首次检索失败后是否已补试过（每次进房/刷新重置）
  bool _offlineSwitchRetried = false;

  /// 视频输出失效（播放中尺寸持续为空）恢复次数，每房间限量
  int _invalidVideoSizeRecoveries = 0;
  DateTime? _lastInvalidVideoSizeRecoveryAt;
  String _lastShortcutKey = "";
  String _lastShortcutSource = "";
  DateTime? _lastShortcutHandledAt;

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 是否处于后台
  var isBackground = false;

  /// 用户主动暂停（暂停/继续功能状态）
  final RxBool userPaused = false.obs;

  /// 播放停滞看门狗
  Timer? _playbackWatchdog;
  Duration? _lastWatchdogPosition;
  int _stallSampleCount = 0;
  int _bufferingSampleCount = 0;
  int? _lastVideoOutputDropCount;
  int _videoOutputDropSamples = 0;
  bool _outputDropSamplePending = false;
  bool _watchdogRefreshing = false;
  DateTime? _lastWatchdogRefreshAt;

  /// 断流自动恢复记账：恢复成功即重置重试计数（"连续失败"语义），
  /// 并记录恢复时刻；5 分钟内成功恢复次数过多说明流本身不可持续，
  /// 不再无限重试，走下播/换台兜底，避免死循环。
  final List<DateTime> _playbackRecoveryTimes = [];
  static const int _maxRecoveriesPerWindow = 6;
  static const Duration _recoveryWindow = Duration(minutes: 5);

  /// 看门狗刷新风暴记账：看门狗触发的重刷此前不计数，会无限原地每 8 秒
  /// 刷下去；同样按窗口限量，超限后判定播放失败并走自动换台兜底
  final List<DateTime> _watchdogRefreshTimes = [];
  static const int _maxWatchdogRefreshesPerWindow = 6;
  static const Duration _watchdogRefreshWindow = Duration(minutes: 5);

  /// 自动退出倒计时，单位秒
  var countdown = 60.obs;

  Timer? autoExitTimer;
  final AutoExitSession _autoExitSession = AutoExitSession();
  final autoExitSource = AutoExitSource.none.obs;
  bool _autoExitCompleting = false;
  bool _roomDisposed = false;

  /// 设置的自动关闭时长，单位分钟
  var autoExitMinutes = 60.obs;

  /// 是否已请求延迟自动关闭
  var delayAutoExit = false.obs;

  /// 是否启用自动关闭
  var autoExitEnable = false.obs;

  var datetime = "00:00".obs;
  Timer? _clockTimer;

  void initTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      var now = DateTime.now();
      datetime.value =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  /// 双击退出Flag
  bool doubleClickExit = false;

  /// 双击退出Timer
  Timer? doubleClickTimer;
  final Queue<String> _recentDanmuFingerprints = Queue<String>();
  final Map<String, int> _recentDanmuCounts = <String, int>{};
  int _recentDanmuEventsSincePrune = 0;
  RxList<LiveRepeatedDanmuSummary> liveEventFlows =
      <LiveRepeatedDanmuSummary>[].obs;
  LiveRepeatedDanmuAggregator _liveEventFlowAggregator =
      LiveRepeatedDanmuAggregator();
  Timer? _liveEventFlowTimer;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    CurrentRoomService.instance.setRoom(site, roomId);
    initTimer();
    _startLiveEventFlowTimer();
    initAutoExit();
    showDanmakuState.value = DesktopStartupArgs.isSecondaryDesktopInstance
        ? false
        : AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    specialFollowed.value = DBService.instance.followBox
            .get("${site.id}_$roomId")
            ?.isSpecialFollow ??
        false;

    loadData();
    unawaited(syncDesktopFullscreenState());

    super.onInit();
  }

  void initAutoExit() {
    final settings = AppSettingsController.instance;
    autoExitTimer?.cancel();
    _autoExitSession.stop();
    autoExitSource.value = AutoExitSource.none;
    _autoExitCompleting = false;
    autoExitEnable.value = settings.autoExitEnable.value;
    if (!autoExitEnable.value) {
      autoExitMinutes.value = settings.roomAutoExitDuration.value;
      countdown.value = 0;
      return;
    }
    autoExitMinutes.value = settings.autoExitDuration.value;
    _autoExitSession.startGlobal(
      now: DateTime.now(),
      minutes: autoExitMinutes.value,
    );
    autoExitSource.value = AutoExitSource.global;
    _startAutoExitTicker();
  }

  void setAutoExit() {
    if (!autoExitEnable.value) {
      stopAutoExit();
      return;
    }
    _autoExitSession.startRoomOverride(
      now: DateTime.now(),
      minutes: autoExitMinutes.value,
    );
    autoExitSource.value = AutoExitSource.roomOverride;
    _startAutoExitTicker();
  }

  void _startAutoExitTicker() {
    autoExitTimer?.cancel();
    _autoExitCompleting = false;
    _refreshAutoExitCountdown();
    autoExitTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshAutoExitCountdown(),
    );
  }

  void _refreshAutoExitCountdown() {
    if (!autoExitEnable.value || !_autoExitSession.enabled) {
      return;
    }
    final now = DateTime.now();
    final remaining = _autoExitSession.remaining(now);
    countdown.value = remaining == Duration.zero ? 0 : remaining.inSeconds + 1;
    if (_autoExitSession.isDue(now)) {
      unawaited(_completeAutoExit());
    }
  }

  Future<void> _completeAutoExit() async {
    if (_autoExitCompleting || _roomDisposed) {
      return;
    }
    _autoExitCompleting = true;
    autoExitTimer?.cancel();
    _autoExitSession.stop();
    autoExitSource.value = AutoExitSource.none;
    autoExitEnable.value = false;
    countdown.value = 0;
    Log.i(
        "定时关闭到点：platform=${Platform.operatingSystem} room=${site.id}/$roomId");
    await _runAutoExitStep("停止弹幕", liveDanmaku.stop);
    await _runAutoExitStep("停止播放器", player.stop);
    await _runAutoExitStep("释放唤醒锁", WakelockPlus.disable);
    await _finishAutoExit();
  }

  Future<void> _runAutoExitStep(
    String label,
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      await action().timeout(timeout);
    } on TimeoutException catch (e, stackTrace) {
      Log.e("定时关闭步骤超时（$label）: $e", stackTrace);
    } catch (e, stackTrace) {
      Log.e("定时关闭步骤失败（$label）: $e", stackTrace);
    }
  }

  Future<void> _finishAutoExit() async {
    if (Platform.isAndroid) {
      try {
        final finished = await _appWindowChannel
            .invokeMethod<bool>(
              'finishAndRemoveTask',
            )
            .timeout(const Duration(seconds: 2));
        if (finished == true) {
          return;
        }
      } catch (e) {
        Log.d("原生移除任务失败，回退 Flutter 退出：$e");
      }
      await _runAutoExitStep("Flutter 退出应用", SystemNavigator.pop);
      return;
    }
    try {
      if (Platform.isWindows) {
        await windowManager
            .setPreventClose(false)
            .timeout(const Duration(seconds: 1));
      }
      await windowManager.close().timeout(const Duration(seconds: 2));
    } catch (e, stackTrace) {
      Log.e("关闭桌面窗口失败，尝试销毁窗口: $e", stackTrace);
      await _runAutoExitStep("销毁桌面窗口", windowManager.destroy);
    }
  }

  void stopAutoExit() {
    autoExitEnable.value = false;
    autoExitTimer?.cancel();
    _autoExitSession.stop();
    autoExitSource.value = AutoExitSource.none;
    _autoExitCompleting = false;
    countdown.value = 0;
  }

  void refreshRoom() {
    //messages.clear();
    _resetPlaybackRecoveryBookkeeping();
    liveDanmaku.stop();
    _clearDanmuDedupeState();

    loadData();
  }

  /// 暂停/继续（遥控器媒体键触发）：继续时刷新直播流回到最新画面
  Future<void> togglePlayPause() async {
    if (userPaused.value) {
      userPaused.value = false;
      await player.play();
      SmartDialog.showToast("继续播放");
      await setPlayer(refreshUrls: true);
    } else {
      userPaused.value = true;
      await player.pause();
      SmartDialog.showToast("已暂停");
    }
  }

  /// 停滞看门狗：播放中连续 3 次采样（每 5 秒）位置几乎不变时自动刷新
  ///
  /// 判据：采样间 position 前进不足 1 秒视为停滞样本。
  /// 单纯比较"位置相等"会漏掉"音频时钟继续走但画面冻结"的解码停滞，
  /// 以及弱网下 buffering 频繁抖动导致计数被清零的场景。
  /// 画面停滞（声音正常但视频解码持续失败）：复用看门狗停滞恢复链，
  /// 自动重刷并受刷新风暴记账约束，反复失败升级为自动换台
  @override
  void onVideoDecodeStall() {
    unawaited(_refreshPlayerFromWatchdog());
  }

  void _startPlaybackWatchdog() {
    _playbackWatchdog?.cancel();
    _lastWatchdogPosition = null;
    _stallSampleCount = 0;
    _bufferingSampleCount = 0;
    _videoOutputDropSamples = 0;
    _lastVideoOutputDropCount = null;
    _playbackWatchdog = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isBackground || !liveStatus.value || userPaused.value) {
        _lastWatchdogPosition = null;
        _stallSampleCount = 0;
        _bufferingSampleCount = 0;
        _videoOutputDropSamples = 0;
        _lastVideoOutputDropCount = null;
        _outputDropSamplePending = false;
        return;
      }
      if (!player.state.playing) {
        _lastWatchdogPosition = null;
        _stallSampleCount = 0;
        _bufferingSampleCount = 0;
        _videoOutputDropSamples = 0;
        _lastVideoOutputDropCount = null;
        _outputDropSamplePending = false;
        return;
      }
      if (Platform.isAndroid && !_outputDropSamplePending) {
        _outputDropSamplePending = true;
        unawaited(_sampleAndroidVideoOutputDrops());
      }
      final position = player.state.position;
      final last = _lastWatchdogPosition;
      final advanced =
          last == null || position.inMilliseconds - last.inMilliseconds >= 250;
      final bufferLead = player.state.buffer - position;
      final bufferExhausted = bufferLead <= const Duration(milliseconds: 350);
      if (player.state.buffering || bufferExhausted) {
        _bufferingSampleCount += 1;
      } else {
        _bufferingSampleCount = 0;
      }
      if (!advanced) {
        _stallSampleCount += 1;
      } else {
        _stallSampleCount = 0;
      }
      if ((_stallSampleCount >= 2 || _bufferingSampleCount >= 3) &&
          !_watchdogRefreshing &&
          (_lastWatchdogRefreshAt == null ||
              DateTime.now().difference(_lastWatchdogRefreshAt!) >=
                  const Duration(seconds: 8))) {
        _watchdogRefreshing = true;
        _lastWatchdogRefreshAt = DateTime.now();
        _stallSampleCount = 0;
        _bufferingSampleCount = 0;
        Log.w("检测到播放停滞，自动刷新播放");
        unawaited(_refreshPlayerFromWatchdog().whenComplete(() {
          _watchdogRefreshing = false;
        }));
      }
      _lastWatchdogPosition = position;
    });
  }

  Future<void> _sampleAndroidVideoOutputDrops() async {
    try {
      final dropCount = await readVideoOutputDropCount();
      if (isBackground ||
          userPaused.value ||
          !liveStatus.value ||
          !player.state.playing ||
          dropCount == null ||
          dropCount < 0) {
        _lastVideoOutputDropCount = null;
        _videoOutputDropSamples = 0;
        return;
      }
      final previous = _lastVideoOutputDropCount;
      _lastVideoOutputDropCount = dropCount;
      if (previous == null || dropCount < previous) {
        _videoOutputDropSamples = 0;
        return;
      }
      final dropped = dropCount - previous;
      if (dropped >= 25) {
        _videoOutputDropSamples++;
        Log.d("Android 视频输出窗口丢帧 $dropped（连续 $_videoOutputDropSamples/3）");
      } else {
        _videoOutputDropSamples = 0;
      }
      if (_videoOutputDropSamples >= 3 &&
          !_watchdogRefreshing &&
          (_lastWatchdogRefreshAt == null ||
              DateTime.now().difference(_lastWatchdogRefreshAt!) >=
                  const Duration(seconds: 8))) {
        _videoOutputDropSamples = 0;
        Log.w("Android 视频输出连续丢帧，触发播放恢复");
        _watchdogRefreshing = true;
        _lastWatchdogRefreshAt = DateTime.now();
        unawaited(_refreshPlayerFromWatchdog().whenComplete(() {
          _watchdogRefreshing = false;
        }));
      }
    } catch (e, stackTrace) {
      Log.e("采样 Android 视频输出丢帧数失败: $e", stackTrace);
      _lastVideoOutputDropCount = null;
      _videoOutputDropSamples = 0;
    } finally {
      _outputDropSamplePending = false;
    }
  }

  /// 看门狗触发的恢复：重新拉流；取流/打开抛出的异常不再静默逃逸
  /// （否则异常从 unawaited 跑掉，连重开房间的降级都不会走），
  /// 失败时降级重开房间；短时间内反复刷新则判定失败走自动换台。
  Future<void> _refreshPlayerFromWatchdog() async {
    final now = DateTime.now();
    _watchdogRefreshTimes.add(now);
    _watchdogRefreshTimes.removeWhere(
      (t) => t.isBefore(now.subtract(_watchdogRefreshWindow)),
    );
    if (_watchdogRefreshTimes.length > _maxWatchdogRefreshesPerWindow) {
      // 同一房间短时间内反复停滞，原地重刷已无意义：
      // 判定播放失败并走自动换台兜底（开关开启时）
      Log.w(
        "看门狗刷新风暴：${_watchdogRefreshWindow.inMinutes}分钟内已刷新"
        "${_watchdogRefreshTimes.length}次，转自动换台",
      );
      _markPlaybackGivenUp(fromError: true, error: "播放反复停滞");
      await _tryAutoSwitchToNextLiveRoom(reason: "playback_failure");
      return;
    }
    try {
      final reloaded = await setPlayer(refreshUrls: true);
      if (!reloaded) {
        Log.w("看门狗刷新失败，尝试重开房间恢复");
        SmartDialog.showToast("播放停滞，正在重新连接...");
        refreshRoom();
      }
    } catch (e, stackTrace) {
      Log.e("看门狗刷新异常: $e", stackTrace);
      SmartDialog.showToast("播放停滞，正在重新连接...");
      refreshRoom();
    }
  }

  Future<void> syncDesktopFullscreenState() async {
    if (!Platform.isWindows) {
      fullScreenState.value = false;
      return;
    }
    try {
      fullScreenState.value = await windowManager.isFullScreen();
    } catch (e) {
      Log.logPrint(e);
    }
  }

  Future<void> toggleDesktopFullscreen() async {
    if (!Platform.isWindows) {
      return;
    }
    try {
      final nextValue = !await windowManager.isFullScreen();
      await windowManager.setFullScreen(nextValue);
      fullScreenState.value = nextValue;
      SmartDialog.showToast(nextValue ? "已进入全屏" : "已退出全屏");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("切换全屏失败");
    }
  }

  void toggleDanmaku() {
    showDanmakuState.value = !showDanmakuState.value;
    AppSettingsController.instance.setDanmuEnable(showDanmakuState.value);
    SmartDialog.showToast(showDanmakuState.value ? "弹幕已开启" : "弹幕已关闭");
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    await player.setVolume(
      muted.value ? 0 : AppSettingsController.instance.playerVolume.value,
    );
    SmartDialog.showToast(muted.value ? "已静音" : "已恢复声音");
  }

  /// 音量 OSD 状态：遥控器调节音量时短暂显示（讨论 #161）
  RxBool showVolumeOSDState = false.obs;
  RxDouble volumeOSDValue = 100.0.obs;
  Timer? _hideVolumeOSDTimer;

  /// 调节播放器音量（0-300，>100 为软件增益档），并弹出 OSD。
  Future<void> adjustVolume(double delta) async {
    final target =
        (AppSettingsController.instance.playerVolume.value + delta)
            .clamp(0.0, PlayerVolumePolicy.maxVolume)
            .toDouble();
    AppSettingsController.instance.setPlayerVolume(target);
    if (target > 0 && muted.value) {
      muted.value = false;
    }
    await player.setVolume(target);
    volumeOSDValue.value = target;
    showVolumeOSDState.value = true;
    _hideVolumeOSDTimer?.cancel();
    _hideVolumeOSDTimer = Timer(const Duration(seconds: 2), () {
      showVolumeOSDState.value = false;
    });
  }

  bool handleDesktopShortcut(
    String key, {
    required String source,
  }) {
    final now = DateTime.now();
    if (_lastShortcutKey == key &&
        _lastShortcutSource != source &&
        _lastShortcutHandledAt != null &&
        now.difference(_lastShortcutHandledAt!) <
            const Duration(milliseconds: 160)) {
      _lastShortcutHandledAt = now;
      _lastShortcutSource = source;
      return true;
    }
    _lastShortcutKey = key;
    _lastShortcutSource = source;
    _lastShortcutHandledAt = now;
    switch (key) {
      case "keyF":
        unawaited(toggleDesktopFullscreen());
        return true;
      case "keyD":
        toggleDanmaku();
        return true;
      case "keyR":
        refreshRoom();
        return true;
      case "keyM":
        unawaited(toggleMute());
        return true;
      default:
        return false;
    }
  }

  bool handleKeyboardShortcut(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyF) {
      return handleDesktopShortcut("keyF", source: "keyboard");
    }
    if (key == LogicalKeyboardKey.keyD) {
      return handleDesktopShortcut("keyD", source: "keyboard");
    }
    if (key == LogicalKeyboardKey.keyR) {
      return handleDesktopShortcut("keyR", source: "keyboard");
    }
    if (key == LogicalKeyboardKey.keyM) {
      return handleDesktopShortcut("keyM", source: "keyboard");
    }
    return false;
  }

  void showAutoExitSheet() {
    Utils.showRightDialog(
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12,
            child: Text(
              "定时关闭",
              style: AppStyle.titleStyleWhite,
            ),
          ),
          Obx(
            () => SwitchListTile(
              title: Text(
                "启用定时关闭",
                style: Get.textTheme.titleMedium,
              ),
              value: autoExitEnable.value,
              onChanged: (e) {
                autoExitEnable.value = e;
                if (e) {
                  autoExitMinutes.value =
                      AppSettingsController.instance.roomAutoExitDuration.value;
                  setAutoExit();
                } else {
                  stopAutoExit();
                }
              },
            ),
          ),
          Obx(
            () => ListTile(
              enabled: autoExitEnable.value,
              title: Text(
                autoExitSource.value == AutoExitSource.global
                    ? "全局定时关闭：${autoExitMinutes.value ~/ 60}小时${autoExitMinutes.value % 60}分钟"
                    : "本次观看：${autoExitMinutes.value ~/ 60}小时${autoExitMinutes.value % 60}分钟",
                style: Get.textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                var value = await showTimePicker(
                  context: Get.context!,
                  initialTime: TimeOfDay(
                    hour: autoExitMinutes.value ~/ 60,
                    minute: autoExitMinutes.value % 60,
                  ),
                  initialEntryMode: TimePickerEntryMode.inputOnly,
                  builder: (_, child) {
                    return MediaQuery(
                      data: Get.mediaQuery.copyWith(
                        alwaysUse24HourFormat: true,
                      ),
                      child: child!,
                    );
                  },
                );
                if (value == null || (value.hour == 0 && value.minute == 0)) {
                  return;
                }
                var duration =
                    Duration(hours: value.hour, minutes: value.minute);
                autoExitMinutes.value = duration.inMinutes;
                AppSettingsController.instance
                    .setRoomAutoExitDuration(autoExitMinutes.value);
                if (autoExitEnable.value) {
                  setAutoExit();
                } else {
                  countdown.value = 0;
                }
              },
            ),
          ),
          Obx(
            () {
              countdown.value;
              final globalRemaining = _autoExitSession.globalRemaining(
                DateTime.now(),
              );
              if (autoExitSource.value != AutoExitSource.roomOverride ||
                  globalRemaining <= Duration.zero) {
                return const SizedBox.shrink();
              }
              return ListTile(
                title: Text(
                  "全局定时关闭剩余：${_formatAutoExitDuration(globalRemaining)}",
                ),
                subtitle: const Text("当前修改只影响本次观看，不会修改全局设置"),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatAutoExitDuration(Duration duration) {
    final minutes = (duration.inSeconds + 59) ~/ 60;
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    return hours > 0 ? "$hours小时$remainMinutes分钟" : "$remainMinutes分钟";
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    liveDanmaku.onMessage = onWSMessage;
    liveDanmaku.onClose = onWSClose;
    liveDanmaku.onReady = onWSReady;
  }

  // ---- 弹幕批量合帧缓冲（#137 同源优化）----
  static const Duration _danmakuFlushInterval = Duration(milliseconds: 150);
  static const int _danmakuFlushThreshold = 40;
  final List<LiveMessage> _pendingDanmakuMessages = [];
  Timer? _danmakuFlushTimer;

  void _queueDanmakuMessage(LiveMessage msg) {
    _pendingDanmakuMessages.add(msg);
    if (_pendingDanmakuMessages.length >= _danmakuFlushThreshold) {
      _flushDanmakuMessages();
      return;
    }
    _danmakuFlushTimer ??= Timer(_danmakuFlushInterval, _flushDanmakuMessages);
  }

  void _flushDanmakuMessages() {
    _danmakuFlushTimer?.cancel();
    _danmakuFlushTimer = null;
    if (_pendingDanmakuMessages.isEmpty) {
      return;
    }
    final batch = List<LiveMessage>.from(_pendingDanmakuMessages);
    _pendingDanmakuMessages.clear();
    if (!liveStatus.value || isBackground) {
      return;
    }
    final renderEmoji = AppSettingsController.instance.danmuRenderEmoji.value;
    final items = <DanmakuContentItem>[];
    for (var msg in batch) {
      final parts = renderEmoji ? _buildDanmakuContentParts(msg.spans) : null;
      items.add(
        DanmakuContentItem(
          msg.message,
          color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b),
          imageUrls: renderEmoji && parts == null ? msg.imageUrls : null,
          parts: parts,
        ),
      );
    }
    addDanmaku(items);
  }

  void _cancelDanmakuFlushTimer() {
    _danmakuFlushTimer?.cancel();
    _danmakuFlushTimer = null;
    _pendingDanmakuMessages.clear();
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) {
    if (msg.type == LiveMessageType.chat) {
      // 关键词屏蔽检查
      for (var keyword in AppSettingsController.instance.shieldList) {
        Pattern? pattern;
        if (Utils.isRegexFormat(keyword)) {
          String removedSlash = Utils.removeRegexFormat(keyword);
          try {
            pattern = RegExp(removedSlash);
          } catch (e) {
            // should avoid this during add keyword
            Log.d("关键词：$keyword 正则格式错误");
          }
        } else {
          pattern = keyword;
        }
        if (pattern != null && msg.message.contains(pattern)) {
          Log.d("关键词：$keyword\n已屏蔽消息内容：${msg.message}");
          return;
        }
      }

      if (_isDuplicateDanmu(msg)) {
        return;
      }

      _recordLiveEventFlow(msg);

      if (!liveStatus.value || isBackground) {
        return;
      }

      // 弹幕批量合帧（#137 同源优化）：高热房间每秒几十条，
      // 150ms 一帧批量上屏，降低弱芯片 TV 设备的 UI 压力
      _queueDanmakuMessage(msg);
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
      if (msg.totalViews != null) {
        totalViewers.value = msg.totalViews!;
      }
    } else if (msg.type == LiveMessageType.superChat) {
      //superChats.add(msg.data);
    }
  }

  List<DanmakuContentPart>? _buildDanmakuContentParts(
    List<LiveMessageSpan>? spans,
  ) {
    final source = spans ?? const <LiveMessageSpan>[];
    if (source.isEmpty) {
      return null;
    }
    final parts = <DanmakuContentPart>[];
    for (final span in source) {
      if (span.isText) {
        final text = span.text ?? "";
        if (text.isNotEmpty) {
          parts.add(DanmakuContentPart.text(text));
        }
      } else if (span.isImage) {
        final imageUrl = (span.imageUrl ?? "").trim();
        if (imageUrl.isNotEmpty) {
          parts.add(DanmakuContentPart.image(imageUrl));
        }
      }
    }
    return parts.isEmpty ? null : parts;
  }

  bool _isDuplicateDanmu(LiveMessage msg) {
    final settings = AppSettingsController.instance;
    if (!settings.danmuDedupeEnable.value) {
      return false;
    }
    final strictMode = settings.danmuDedupeStrictMode;
    final fingerprint = _buildDanmuFingerprint(
      msg,
      includeUserName: !strictMode,
    );
    if (fingerprint == null) {
      return false;
    }
    final windowSize = settings.effectiveDanmuDedupeWindow;
    final duplicate = _recentDanmuCounts.containsKey(fingerprint);
    _recentDanmuFingerprints.addLast(fingerprint);
    _recentDanmuCounts[fingerprint] =
        (_recentDanmuCounts[fingerprint] ?? 0) + 1;
    if (strictMode) {
      _recentDanmuEventsSincePrune = 0;
      _pruneRecentDanmuFingerprints(windowSize);
      return duplicate;
    }

    final step = settings.danmuDedupeStep.value.clamp(1, 20).toInt();
    _recentDanmuEventsSincePrune += 1;
    final shouldPrune = _recentDanmuEventsSincePrune >= step ||
        _recentDanmuFingerprints.length > windowSize + step - 1;
    if (shouldPrune) {
      _recentDanmuEventsSincePrune = 0;
    }
    if (shouldPrune) {
      _pruneRecentDanmuFingerprints(windowSize);
    }
    return duplicate;
  }

  void _pruneRecentDanmuFingerprints(int windowSize) {
    while (_recentDanmuFingerprints.length > windowSize) {
      final removed = _recentDanmuFingerprints.removeFirst();
      final count = (_recentDanmuCounts[removed] ?? 0) - 1;
      if (count <= 0) {
        _recentDanmuCounts.remove(removed);
      } else {
        _recentDanmuCounts[removed] = count;
      }
    }
  }

  String? _buildDanmuFingerprint(
    LiveMessage msg, {
    required bool includeUserName,
  }) {
    final parts = <String>[];
    final message = _normalizeDanmuFingerprintPart(msg.message);
    if (message.isNotEmpty) {
      parts.add("m:$message");
    }
    for (final span in msg.spans ?? const <LiveMessageSpan>[]) {
      final text = _normalizeDanmuFingerprintPart(span.text ?? "");
      final imageUrl = _normalizeDanmuFingerprintPart(span.imageUrl ?? "");
      if (text.isNotEmpty) {
        parts.add("t:$text");
      }
      if (imageUrl.isNotEmpty) {
        parts.add("i:$imageUrl");
      }
    }
    for (final imageUrl in msg.imageUrls ?? const <String>[]) {
      final value = _normalizeDanmuFingerprintPart(imageUrl);
      if (value.isNotEmpty) {
        parts.add("u:$value");
      }
    }
    if (parts.isEmpty) {
      return null;
    }
    if (!includeUserName) {
      return parts.join("\u0002");
    }
    final userName = _normalizeDanmuFingerprintPart(msg.userName);
    if (userName.isEmpty) {
      return null;
    }
    return "$userName\u0001${parts.join("\u0002")}";
  }

  String _normalizeDanmuFingerprintPart(String value) {
    return value.trim().replaceAll(RegExp(r"\s+"), " ");
  }

  void _clearDanmuDedupeState() {
    _recentDanmuFingerprints.clear();
    _recentDanmuCounts.clear();
    _recentDanmuEventsSincePrune = 0;
  }

  void _startLiveEventFlowTimer() {
    _liveEventFlowTimer?.cancel();
    _liveEventFlowTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _flushLiveEventFlow(),
    );
  }

  void _recordLiveEventFlow(LiveMessage msg) {
    if (msg.userName == "LiveSysMessage") {
      return;
    }
    final settings = AppSettingsController.instance;
    if (!settings.liveEventFlowEnable.value) {
      clearLiveEventFlow();
      return;
    }
    final text = _normalizeDanmuFingerprintPart(msg.message);
    if (text.isEmpty) {
      return;
    }
    _ensureLiveEventFlowAggregatorSettings();
    _liveEventFlowAggregator.add(text);
    _flushLiveEventFlow();
  }

  void _flushLiveEventFlow() {
    final settings = AppSettingsController.instance;
    if (!settings.liveEventFlowEnable.value) {
      clearLiveEventFlow();
      return;
    }
    _ensureLiveEventFlowAggregatorSettings();
    final summaries = _liveEventFlowAggregator.preview(
      displayTtl: Duration(
        seconds: settings.effectiveLiveEventFlowDisplaySeconds,
      ),
    );
    liveEventFlows.assignAll(summaries);
  }

  void _ensureLiveEventFlowAggregatorSettings() {
    final settings = AppSettingsController.instance;
    final countWindow = Duration(
      seconds: settings.effectiveLiveEventFlowWindowSeconds,
    );
    final minDisplayCount = settings.effectiveLiveEventFlowMinCount;
    if (_liveEventFlowAggregator.countWindow == countWindow &&
        _liveEventFlowAggregator.minDisplayCount == minDisplayCount) {
      return;
    }
    _liveEventFlowAggregator = LiveRepeatedDanmuAggregator(
      countWindow: countWindow,
      minDisplayCount: minDisplayCount,
    );
    liveEventFlows.clear();
  }

  void clearLiveEventFlow() {
    _liveEventFlowAggregator.clear();
    liveEventFlows.clear();
  }

  /// 接收 WebSocket 关闭消息
  void onWSClose(String msg) {
    Log.d("弹幕服务器连接状态：$msg");
    final shouldNotify = msg.contains("失败") || msg.contains("超过最大次数");
    if (shouldNotify && AppSettingsController.instance.danmuEnable.value) {
      SmartDialog.showToast("弹幕连接异常：$msg");
    }
  }

  /// WebSocket 已连接完成
  void onWSReady() {
    Log.d("弹幕服务器连接成功");
  }

  /// 加载直播间信息
  void loadData() async {
    totalViewers.value = 0;
    playbackLoadError.value = "";
    _resetPlaybackRecoveryBookkeeping();
    // 换房丢弃上一间房的弹幕缓冲，避免旧房弹幕漏进新房
    _cancelDanmakuFlushTimer();
    try {
      pageLoadding.value = true;
      detail.value = await site.liveSite.getRoomDetail(roomId: roomId);

      addHistory();
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (liveStatus.value) {
        _autoSwitchOfflineHops = 0;
        getPlayQualites();
      } else {
        _scheduleAutoSwitchFromOfflineRoom();
      }
      if (detail.value!.isRecord) {
        SmartDialog.showToast("当前主播未开播，正在轮播录像");
      }

      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
    } catch (e, stackTrace) {
      Log.e("读取直播间信息失败：${site.id}/$roomId", stackTrace);
      // 房间被封禁/下播后禁止进入等：清掉上一间房残留信息，
      // 落到带重试按钮的错误页（不再只弹 toast 卡在“未开播”），
      // 并与未开播房间一致地调度自动换台（开关开启时）
      detail.value = null;
      liveStatus.value = false;
      playbackLoadError.value = "直播间加载失败，请稍后重试\n($e)";
      _scheduleAutoSwitchFromOfflineRoom();
    } finally {
      pageLoadding.value = false;
    }
  }

  /// 初始化播放器
  Future<void> getPlayQualites() async {
    playbackLoadError.value = "";
    qualites.clear();
    currentQuality = -1;
    try {
      var playQualites =
          await site.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        playbackLoadError.value = "无法读取播放清晰度，请稍后重试";
        Log.e(
          "播放清晰度列表为空：${site.id}/$roomId",
          StackTrace.current,
        );
        return;
      }
      qualites.value = playQualites;
      var qualityLevel = AppSettingsController.instance.qualityLevel.value;
      if (qualityLevel == 2) {
        //最高
        currentQuality = 0;
      } else if (qualityLevel == 0) {
        //最低
        currentQuality = playQualites.length - 1;
      } else if (qualityLevel == 3) {
        // 记住上次：按名称精确匹配，名称不存在时按偏移兜底。
        final memory = AppSettingsController.instance.getQualityMemory(site.id);
        if (memory != null) {
          final resolved = QualityMemory.resolveIndex(
            qualities: playQualites,
            savedName: memory.name,
            savedOffset: memory.offset,
          );
          if (resolved >= 0) {
            currentQuality = resolved;
          }
        }
        // 找不到记忆或匹配失败时，走"中等"兜底（与旧 else 分支相同）。
        if (currentQuality < 0) {
          int middle = (playQualites.length / 2).floor();
          currentQuality = middle;
        }
      } else {
        //中间值
        int middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }

      await getPlayUrl();
    } catch (e, stackTrace) {
      Log.e("读取播放清晰度失败：${site.id}/$roomId error=$e", stackTrace);
      playbackLoadError.value = e.toString();
    }
  }

  Future<void> getPlayUrl() async {
    playUrls.clear();
    currentQualityInfo.value = qualites[currentQuality].quality;
    currentLineInfo.value = "";
    currentLineIndex = -1;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.urls.isEmpty) {
      playbackLoadError.value = "无法读取播放地址，请稍后重试";
      return;
    }
    playUrls.value = playUrl.urls;
    playHeaders = playUrl.headers;
    currentLineIndex = 0;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    //重置错误次数
    mediaErrorRetryCount = 0;
    unawaited(setPlayer());
  }

  Future<bool> _reloadPlayUrls({bool silent = false}) async {
    if (detail.value == null ||
        currentQuality < 0 ||
        currentQuality >= qualites.length) {
      return false;
    }
    currentQualityInfo.value = qualites[currentQuality].quality;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.urls.isEmpty) {
      if (!silent) {
        SmartDialog.showToast("无法读取播放地址");
      }
      return false;
    }
    playUrls.value = playUrl.urls;
    playHeaders = playUrl.headers;
    if (currentLineIndex < 0) {
      currentLineIndex = 0;
    } else if (currentLineIndex >= playUrls.length) {
      currentLineIndex = playUrls.length - 1;
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    return true;
  }

  void changePlayLine(int index) {
    currentLineIndex = index;
    //重置错误次数
    mediaErrorRetryCount = 0;
    unawaited(setPlayer());
  }

  /// 播放器代际号：setPlayer 是异步流程且多处不 await（看门狗、错误重试、
  /// 暂停恢复可能同时触发），await 期间若代际号变化说明有更新的请求，
  /// 旧流程必须中止，避免并发 open 造成解码器/Surface 竞态（卡死、崩溃）
  int _playerGeneration = 0;

  /// 重新拉流并打开播放器。返回 false 表示拉流失败且未打开。
  /// 并发调用时旧请求直接返回 true（表示已被新请求接管，调用方无需降级）。
  Future<bool> setPlayer({bool refreshUrls = false}) async {
    final generation = ++_playerGeneration;
    // 切换清晰度/线路意味着回到正常播放，清除暂停状态
    userPaused.value = false;
    if (refreshUrls) {
      var reloaded = await _reloadPlayUrls(silent: true);
      if (generation != _playerGeneration) {
        return true;
      }
      if (!reloaded) {
        return false;
      }
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";
    await initializePlayer();
    if (generation != _playerGeneration) {
      return true;
    }
    // 全平台：停止旧流并等待资源释放，避免解码器/Surface 渲染冲突
    // （此前仅桌面平台 stop，Android 上快速重开易触发 MediaCodec 竞态）
    if (player.state.playing || player.state.playlist.medias.isNotEmpty) {
      try {
        await player.stop();
        await Future.delayed(const Duration(milliseconds: 120));
      } catch (e, stackTrace) {
        Log.e("停止旧播放失败: $e", stackTrace);
      }
    }
    if (generation != _playerGeneration) {
      return true;
    }
    try {
      await player.open(
        Media(
          playUrls[currentLineIndex],
          httpHeaders: playHeaders,
        ),
      );
    } catch (e, stackTrace) {
      Log.e("打开播放失败: $e", stackTrace);
    }
    if (generation != _playerGeneration) {
      return true;
    }
    await player.setVolume(
      muted.value ? 0 : AppSettingsController.instance.playerVolume.value,
    );

    Log.d("播放链接\r\n：${playUrls[currentLineIndex]}");
    _startPlaybackWatchdog();
    _onPlaybackRecovered();
    return true;
  }

  /// 播放器成功打开后调用：把断流重试计数归零（"连续失败"语义——
  /// 周期性被服务端掐流的房间，不再第 3 次断流就被误判下播），
  /// 同时记录恢复时刻用于恢复风暴检测。
  void _onPlaybackRecovered() {
    if (mediaErrorRetryCount > 0) {
      final now = DateTime.now();
      _playbackRecoveryTimes.add(now);
      _playbackRecoveryTimes.removeWhere(
        (t) => t.isBefore(now.subtract(_recoveryWindow)),
      );
      if (_playbackRecoveryTimes.length >= _maxRecoveriesPerWindow) {
        Log.i(
          "断流恢复风暴：${_recoveryWindow.inMinutes}分钟内已恢复"
          "${_playbackRecoveryTimes.length}次，暂停自动重试",
        );
      }
    }
    mediaErrorRetryCount = 0;
  }

  /// 恢复风暴：短时间内反复"断→恢复"，说明流本身不可持续
  bool get _playbackRecoveryStormDetected {
    final cutoff = DateTime.now().subtract(_recoveryWindow);
    _playbackRecoveryTimes.removeWhere((t) => t.isBefore(cutoff));
    return _playbackRecoveryTimes.length >= _maxRecoveriesPerWindow;
  }

  /// 手动刷新 / 进入新房间时清空恢复记账
  void _resetPlaybackRecoveryBookkeeping() {
    mediaErrorRetryCount = 0;
    _playbackRecoveryTimes.clear();
    _watchdogRefreshTimes.clear();
    _offlineSwitchRetried = false;
    _invalidVideoSizeRecoveries = 0;
    _lastInvalidVideoSizeRecoveryAt = null;
  }

  /// 单次断流恢复：刷新播放地址并重开播放器。取流/打开抛出的异常
  /// 不再静默逃逸（旧逻辑页面会冻住在"播放中"），立即走兜底判定。
  Future<void> _recoverPlaybackOnce() async {
    try {
      await setPlayer(refreshUrls: _shouldRefreshUrlsOnPlaybackRetry);
    } catch (e, stackTrace) {
      Log.e("断流恢复失败：$e", stackTrace);
      await _playbackRetriesExhausted();
    }
  }

  /// 重试耗尽后的兜底：优先切换剩余线路；已是最末线路且未触发恢复风暴时，
  /// 虎牙/斗鱼重置计数重新签名再试一轮（斗鱼常只返回一条线路，靠重签兜底）；
  /// 否则判定下播并尝试自动换台。
  Future<void> _playbackRetriesExhausted({
    bool fromError = false,
    String? error,
  }) async {
    if (playUrls.length - 1 != currentLineIndex) {
      changePlayLine(currentLineIndex + 1);
      return;
    }
    if ((site.id == Constant.kHuya || site.id == Constant.kDouyu) &&
        !_playbackRecoveryStormDetected) {
      Log.d("末线路重试耗尽，重新签名再试一轮：${site.id}/$roomId");
      currentLineIndex = 0;
      mediaErrorRetryCount = 0;
      try {
        await setPlayer(refreshUrls: true);
      } catch (e, stackTrace) {
        Log.e("重签恢复失败：$e", stackTrace);
        _markPlaybackGivenUp(
            fromError: fromError, error: error ?? e.toString());
        await _tryAutoSwitchToNextLiveRoom(
          reason: fromError ? "playback_failure" : "live_end",
        );
        if (!fromError && !_autoSwitchingRoom && !liveStatus.value) {
          _scheduleAutoSwitchFromOfflineRoom();
        }
      }
      return;
    }
    _markPlaybackGivenUp(fromError: fromError, error: error);
    await _tryAutoSwitchToNextLiveRoom(
      reason: fromError ? "playback_failure" : "live_end",
    );
    if (!fromError && !_autoSwitchingRoom && !liveStatus.value) {
      _scheduleAutoSwitchFromOfflineRoom();
    }
  }

  void _markPlaybackGivenUp({bool fromError = false, String? error}) {
    liveStatus.value = false;
    if (fromError) {
      errorMsg.value = "播放失败";
      SmartDialog.showToast("播放失败:${error ?? ''}");
    }
  }

  /// 视频输出失效（播放中尺寸持续为空，对齐移动端 Issue#57 的信号）：
  /// 限量重开当前流恢复，避免与正常切房/刷新互相干扰
  @override
  void onInvalidVideoSize() {
    if (!liveStatus.value || userPaused.value) {
      return;
    }
    // 播放地址尚未就绪（如清晰度还在读取）时不重开，避免越界
    if (playUrls.isEmpty || currentLineIndex < 0) {
      return;
    }
    final now = DateTime.now();
    if (_invalidVideoSizeRecoveries >= 3) {
      return;
    }
    if (_lastInvalidVideoSizeRecoveryAt != null &&
        now.difference(_lastInvalidVideoSizeRecoveryAt!) <
            const Duration(seconds: 10)) {
      return;
    }
    _invalidVideoSizeRecoveries += 1;
    _lastInvalidVideoSizeRecoveryAt = now;
    Log.w(
      "检测到视频输出失效，重开当前流恢复 "
      "($_invalidVideoSizeRecoveries/3)",
    );
    unawaited(setPlayer());
  }

  bool get _shouldRefreshUrlsOnPlaybackRetry =>
      site.id == Constant.kHuya || site.id == Constant.kDouyu;

  @override
  void mediaEnd() async {
    if (mediaErrorRetryCount < 2 && !_playbackRecoveryStormDetected) {
      Log.d("播放结束，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      await _recoverPlaybackOnce();
      return;
    }

    Log.d("播放结束");
    await _playbackRetriesExhausted();
  }

  int mediaErrorRetryCount = 0;
  @override
  void mediaError(String error) async {
    if (mediaErrorRetryCount < 2 && !_playbackRecoveryStormDetected) {
      Log.d("播放失败，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      await _recoverPlaybackOnce();
      return;
    }

    await _playbackRetriesExhausted(fromError: true, error: error);
  }

  /// 房间打开后发现未开播时，若开启了任一自动切换开关，
  /// 延迟片刻后检索下一个正在直播的关注房间。
  /// 覆盖“观看记录进入已关播房间”“自动切换落在刚下播的房间”两种卡在未开播页面的场景。
  void _scheduleAutoSwitchFromOfflineRoom() {
    final settings = AppSettingsController.instance;
    if (!(settings.autoSwitchNextOnLiveEnd.value ||
        settings.autoSwitchNextOnPlaybackFailure.value)) {
      return;
    }
    if (_autoSwitchingRoom) {
      return;
    }
    final now = DateTime.now();
    if (_firstOfflineHopAt == null ||
        now.difference(_firstOfflineHopAt!) >= const Duration(minutes: 5)) {
      _autoSwitchOfflineHops = 0;
      _firstOfflineHopAt = now;
    }
    if (_autoSwitchOfflineHops >= _maxAutoSwitchOfflineHops) {
      return;
    }
    final siteId = site.id;
    final scheduledRoomId = roomId;
    Future.delayed(const Duration(seconds: 2), () async {
      if (_roomDisposed || site.id != siteId || roomId != scheduledRoomId) {
        return;
      }
      if (liveStatus.value || _autoSwitchingRoom) {
        return;
      }
      final switched =
          await _tryAutoSwitchToNextLiveRoom(reason: "room_offline");
      // 首次检索失败（网络抖动/状态缓存过期/触发风控）时延迟补一次，
      // 避免一次性错过换台窗口；每个房间只补一次
      if (!switched && !_offlineSwitchRetried) {
        _offlineSwitchRetried = true;
        Future.delayed(const Duration(seconds: 8), () async {
          if (_roomDisposed || site.id != siteId || roomId != scheduledRoomId) {
            return;
          }
          if (liveStatus.value || _autoSwitchingRoom) {
            return;
          }
          await _tryAutoSwitchToNextLiveRoom(reason: "room_offline");
        });
      }
    });
  }

  Future<bool> _tryAutoSwitchToNextLiveRoom({required String reason}) async {
    final settings = AppSettingsController.instance;
    final enabled = switch (reason) {
      "live_end" => settings.autoSwitchNextOnLiveEnd.value,
      "playback_failure" => settings.autoSwitchNextOnPlaybackFailure.value,
      // 未开播房间：任一开关开启即检索，保持与“关播/播放失败后自动换台”一致的体验
      _ => settings.autoSwitchNextOnLiveEnd.value ||
          settings.autoSwitchNextOnPlaybackFailure.value,
    };
    if (!enabled || _autoSwitchingRoom) {
      return false;
    }

    // 轮播列表开启且非空：候选源切换为轮播列表（#154）
    final playlist = AutoSwitchListService.instance;
    if (settings.autoSwitchListEnabled.value && playlist.items.isNotEmpty) {
      return _tryAutoSwitchViaPlaylist(reason: reason);
    }

    final candidates = FollowUserService.instance.allList.toList();
    if (candidates.isEmpty) {
      return false;
    }

    final currentId = "${site.id}_$roomId";
    final currentIndex = candidates.indexWhere((item) => item.id == currentId);
    final ordered = <FollowUser>[
      if (currentIndex >= 0) ...candidates.skip(currentIndex + 1),
      ...candidates,
    ].where((item) => item.id != currentId).toList();

    FollowUser? target;
    // 第一轮：优先关注列表里缓存为“直播中”的候选，只对其逐一在线确认，
    // 避免对每个未开播候选都发状态请求（关注多时检测明显偏慢）
    for (final candidate in ordered) {
      if (candidate.liveStatus.value != 2) {
        continue;
      }
      final live = await _confirmCandidateLive(candidate);
      if (live == true) {
        target = candidate;
        break;
      }
      if (live == null) {
        return false;
      }
    }
    // 第二轮兜底：先探测状态未知（0）的候选，再在剩余额度内补探缓存
    // “未开播”（1）的——它们可能刚开播、关注列表状态还没刷新到
    if (target == null) {
      var probes = 0;
      for (final pass in const [0, 1]) {
        if (target != null || probes >= 10) {
          break;
        }
        for (final candidate in ordered) {
          if (probes >= 10) {
            break;
          }
          if (candidate.liveStatus.value != pass) {
            continue;
          }
          probes += 1;
          final live = await _confirmCandidateLive(candidate);
          if (live == true) {
            target = candidate;
            break;
          }
          if (live == null) {
            return false;
          }
        }
      }
    }
    if (target == null) {
      SmartDialog.showToast("没有找到正在直播的下一个直播间");
      return false;
    }

    _autoSwitchingRoom = true;
    try {
      SmartDialog.showToast(_autoSwitchToastText(reason));
      if (reason == "room_offline") {
        _autoSwitchOfflineHops += 1;
      }
      resetRoom(Sites.allSites[target.siteId]!, target.roomId);
      return true;
    } finally {
      _autoSwitchingRoom = false;
    }
  }

  String _autoSwitchToastText(String reason) {
    return switch (reason) {
      "live_end" => "当前直播已结束，已切换到下一个直播间",
      "playback_failure" => "当前直播播放失败，已切换到下一个直播间",
      _ => "当前直播间未开播，已切换到下一个直播间",
    };
  }

  /// 轮播列表自动换台（#154）。
  /// 换台前整体刷新成员开播状态（"关播后重新刷新列表"），
  /// 再按顺序（从当前成员环形顺延）或随机点名一个在播成员。
  Future<bool> _tryAutoSwitchViaPlaylist({required String reason}) async {
    final playlist = AutoSwitchListService.instance;
    if (!await playlist.refreshStatuses()) {
      SmartDialog.showToast("直播状态查询触发风控，稍后再试");
      return false;
    }
    final currentId = "${site.id}_$roomId";
    final liveTargets = playlist.liveItems(excludeId: currentId);
    if (liveTargets.isEmpty) {
      SmartDialog.showToast("轮播列表中没有正在直播的直播间");
      return false;
    }

    final AutoSwitchListItem target;
    if (AppSettingsController.instance.autoSwitchListMode.value == 1) {
      // 随机点名在播成员
      target = liveTargets[Random().nextInt(liveTargets.length)];
    } else {
      // 顺序：从当前播放成员的下一个开始环形顺延，点名第一个在播成员
      final all = playlist.items.toList();
      final startIndex = playlist.cursor.clamp(0, all.length - 1);
      final ordered = [
        ...all.skip(startIndex + 1),
        ...all.take(startIndex + 1),
      ];
      AutoSwitchListItem? picked;
      for (final item in ordered) {
        if (item.id == currentId) {
          continue;
        }
        if (playlist.statusCache[item.id] == true) {
          picked = item;
          break;
        }
      }
      // liveTargets 非空时理论上必能命中，兜底防御
      picked ??= liveTargets.first;
      target = picked;
    }

    _autoSwitchingRoom = true;
    try {
      SmartDialog.showToast(_autoSwitchToastText(reason));
      if (reason == "room_offline") {
        _autoSwitchOfflineHops += 1;
      }
      playlist.cursor = playlist.items.indexWhere((e) => e.id == target.id);
      resetRoom(Sites.allSites[target.siteId]!, target.roomId);
      return true;
    } finally {
      _autoSwitchingRoom = false;
    }
  }

  /// 确认候选房间是否在播。
  /// true=在播；false=不在播或查询失败；null=触发平台风控（444），应立即中止扫描
  Future<bool?> _confirmCandidateLive(FollowUser candidate) async {
    try {
      return await Sites.allSites[candidate.siteId]!.liveSite
          .getLiveStatus(roomId: candidate.roomId);
    } catch (e, stackTrace) {
      if (e is CoreError && e.statusCode == 444) {
        Log.e("查询候选直播状态触发风控：${candidate.id}", stackTrace);
        SmartDialog.showToast("直播状态查询触发风控，稍后再试");
        return null;
      }
      Log.e("检查自动切换候选直播状态失败：${candidate.id}", stackTrace);
      return false;
    }
  }

  /// 添加历史记录
  void addHistory() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    var history = DBService.instance.getHistory(id);
    if (history != null) {
      history.updateTime = DateTime.now();
    }
    history ??= History(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      updateTime: DateTime.now(),
    );

    DBService.instance.addOrUpdateHistory(history);
  }

  /// 关注用户
  void followUser() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    DBService.instance.addFollow(
      FollowUser(
        id: id,
        roomId: roomId,
        siteId: site.id,
        userName: detail.value?.userName ?? "",
        face: detail.value?.userAvatar ?? "",
        addTime: DateTime.now(),
      ),
    );
    followed.value = true;
    specialFollowed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
    SmartDialog.showToast("已关注");
  }

  /// 取消关注用户
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    // if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
    //   return;
    // }

    var id = "${site.id}_$roomId";
    DBService.instance.deleteFollow(id);
    followed.value = false;
    specialFollowed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
    SmartDialog.showToast("已取消关注");
  }

  void toggleSpecialFollow(bool enabled) {
    if (detail.value == null) {
      return;
    }
    final id = "${site.id}_$roomId";
    var follow = DBService.instance.followBox.get(id);
    follow ??= FollowUser(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      addTime: DateTime.now(),
    );
    follow.isSpecialFollow = enabled;
    DBService.instance.addFollow(follow);
    followed.value = true;
    specialFollowed.value = enabled;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
    SmartDialog.showToast(enabled ? "已设为特别关注" : "已取消特别关注");
  }

  Future<void> setCurrentFollowTag(String tagName) async {
    if (detail.value == null) return;
    final id = "${site.id}_$roomId";
    var follow = DBService.instance.followBox.get(id);
    if (follow == null) {
      followUser();
      follow = DBService.instance.followBox.get(id);
    }
    if (follow == null) return;
    final ok = await FollowUserService.instance.setItemTag(follow, tagName);
    if (!ok) return;
    followed.value = true;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
    SmartDialog.showToast("已设置标签：$tagName");
  }

  void resetRoom(Site site, String roomId) async {
    if (this.site == site && this.roomId == roomId) {
      return;
    }

    rxSite.value = site;
    rxRoomId.value = roomId;
    CurrentRoomService.instance.setRoom(site, roomId);
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    specialFollowed.value = DBService.instance.followBox
            .get("${site.id}_$roomId")
            ?.isSpecialFollow ??
        false;

    // 清除全部消息
    liveDanmaku.stop();
    _clearDanmuDedupeState();
    clearLiveEventFlow();

    danmakuController?.clear();

    // 重新设置LiveDanmaku
    liveDanmaku = site.liveSite.getDanmaku();

    // 停止播放
    await player.stop();

    // 清掉上一间房的信息再加载，避免加载失败时残留旧房标题/头像
    detail.value = null;
    liveStatus.value = false;

    // 刷新信息
    loadData();
  }

  /// 手动切台候选源：轮播列表开启且非空时使用轮播列表的在播成员（#154），
  /// 否则使用关注在播列表
  Future<List<({String siteId, String roomId})>>
      _manualSwitchChannels() async {
    if (AppSettingsController.instance.autoSwitchListEnabled.value) {
      final playlist = AutoSwitchListService.instance;
      if (playlist.items.isNotEmpty) {
        if (!await playlist.ensureStatusFresh()) {
          SmartDialog.showToast("直播状态查询触发风控，稍后再试");
          return [];
        }
        return playlist
            .liveItems()
            .map((e) => (siteId: e.siteId, roomId: e.roomId))
            .toList();
      }
    }
    return FollowUserService.instance.livingList
        .map((e) => (siteId: e.siteId, roomId: e.roomId))
        .toList();
  }

  /// 手动切台落在轮播成员上时同步顺序模式游标
  void _syncPlaylistCursor(String siteId, String roomId) {
    final playlist = AutoSwitchListService.instance;
    final index =
        playlist.items.indexWhere((e) => e.siteId == siteId && e.roomId == roomId);
    if (index >= 0) {
      playlist.cursor = index;
    }
  }

  Future<void> nextChannel() async {
    //读取正在直播的频道
    var liveChannels = await _manualSwitchChannels();
    if (liveChannels.isEmpty) {
      SmartDialog.showToast("没有正在直播的频道");
      return;
    }
    // 当前房间可能已下播被移出在播列表，或来自历史记录不在关注列表里：
    // 视为"列表之外"，从列表头继续切台，避免卡死无法换台
    var index = liveChannels
        .indexWhere((e) => e.siteId == site.id && e.roomId == roomId);
    index += 1;
    if (index >= liveChannels.length) {
      index = 0;
    }
    var nextChannel = liveChannels[index];

    _syncPlaylistCursor(nextChannel.siteId, nextChannel.roomId);
    resetRoom(Sites.allSites[nextChannel.siteId]!, nextChannel.roomId);
  }

  Future<void> prevChannel() async {
    //读取正在直播的频道
    var liveChannels = await _manualSwitchChannels();
    if (liveChannels.isEmpty) {
      SmartDialog.showToast("没有正在直播的频道");
      return;
    }
    // 同 nextChannel：不在在播列表时视为"列表之外"，从列表尾继续切台
    var index = liveChannels
        .indexWhere((e) => e.siteId == site.id && e.roomId == roomId);
    index -= 1;
    if (index < 0) {
      index = liveChannels.length - 1;
    }
    var nextChannel = liveChannels[index];

    _syncPlaylistCursor(nextChannel.siteId, nextChannel.roomId);
    resetRoom(Sites.allSites[nextChannel.siteId]!, nextChannel.roomId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      Log.d("进入后台:$state");
      //进入后台，关闭弹幕
      danmakuController?.clear();
      isBackground = true;
    } else
    //返回前台
    if (state == AppLifecycleState.resumed) {
      Log.d("返回前台");
      _refreshAutoExitCountdown();
      isBackground = false;
    }
  }

  @override
  void onClose() {
    _roomDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    autoExitTimer?.cancel();
    _autoExitSession.stop();
    _clockTimer?.cancel();
    _playbackWatchdog?.cancel();
    doubleClickTimer?.cancel();
    liveDanmaku.stop();
    _liveEventFlowTimer?.cancel();
    clearLiveEventFlow();
    _cancelDanmakuFlushTimer();
    _hideVolumeOSDTimer?.cancel();

    danmakuController = null;
    super.onClose();
  }
}
