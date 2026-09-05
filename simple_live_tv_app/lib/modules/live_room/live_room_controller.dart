import 'dart:async';
import 'dart:collection';
import 'dart:io';

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
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/modules/live_room/player/player_controller.dart';
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
  var followed = false.obs;
  var specialFollowed = false.obs;
  var liveStatus = false.obs;
  var playbackLoadError = "".obs;
  var muted = false.obs;
  bool _autoSwitchingRoom = false;
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
      setPlayer(refreshUrls: true);
    } else {
      userPaused.value = true;
      await player.pause();
      SmartDialog.showToast("已暂停");
    }
  }

  /// 停滞看门狗：播放中连续 3 次采样（每 5 秒）位置不变时自动刷新
  void _startPlaybackWatchdog() {
    _playbackWatchdog?.cancel();
    _lastWatchdogPosition = null;
    _stallSampleCount = 0;
    _playbackWatchdog = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isBackground || !liveStatus.value || userPaused.value) {
        _lastWatchdogPosition = null;
        _stallSampleCount = 0;
        return;
      }
      if (!player.state.playing || player.state.buffering) {
        // 缓冲中不算停滞，等待起播
        _lastWatchdogPosition = null;
        _stallSampleCount = 0;
        return;
      }
      final position = player.state.position;
      if (_lastWatchdogPosition != null && position == _lastWatchdogPosition) {
        _stallSampleCount += 1;
        if (_stallSampleCount >= 3) {
          _stallSampleCount = 0;
          _lastWatchdogPosition = null;
          Log.w("检测到播放停滞，自动刷新播放");
          setPlayer(refreshUrls: true);
          return;
        }
      } else {
        _stallSampleCount = 0;
      }
      _lastWatchdogPosition = position;
    });
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
    await player.setVolume(muted.value ? 0 : 100);
    SmartDialog.showToast(muted.value ? "已静音" : "已恢复声音");
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

      final renderEmoji = AppSettingsController.instance.danmuRenderEmoji.value;
      final parts = renderEmoji ? _buildDanmakuContentParts(msg.spans) : null;
      addDanmaku([
        DanmakuContentItem(
          msg.message,
          color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b),
          imageUrls: renderEmoji && parts == null ? msg.imageUrls : null,
          parts: parts,
        ),
      ]);
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
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
    playbackLoadError.value = "";
    try {
      pageLoadding.value = true;
      detail.value = await site.liveSite.getRoomDetail(roomId: roomId);

      addHistory();
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (liveStatus.value) {
        getPlayQualites();
      }
      if (detail.value!.isRecord) {
        SmartDialog.showToast("当前主播未开播，正在轮播录像");
      }

      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
    } catch (e) {
      SmartDialog.showToast(e.toString());
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
    setPlayer();
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
    setPlayer();
  }

  void setPlayer({bool refreshUrls = false}) async {
    // 切换清晰度/线路意味着回到正常播放，清除暂停状态
    userPaused.value = false;
    if (refreshUrls) {
      var reloaded = await _reloadPlayUrls(silent: true);
      if (!reloaded) {
        return;
      }
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";
    await initializePlayer();
    // 桌面平台：停止旧流并等待资源释放，避免视频纹理渲染冲突（Issue #115 相关）
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (player.state.playing || player.state.playlist.medias.isNotEmpty) {
        try {
          await player.stop();
          await Future.delayed(const Duration(milliseconds: 120));
        } catch (e, stackTrace) {
          Log.e("停止旧播放失败: $e", stackTrace);
        }
      }
    }
    player.open(
      Media(
        playUrls[currentLineIndex],
        httpHeaders: playHeaders,
      ),
    );
    await player.setVolume(muted.value ? 0 : 100);

    Log.d("播放链接\r\n：${playUrls[currentLineIndex]}");
    _startPlaybackWatchdog();
  }

  bool get _shouldRefreshUrlsOnPlaybackRetry =>
      site.id == Constant.kHuya || site.id == Constant.kDouyu;

  @override
  void mediaEnd() async {
    if (mediaErrorRetryCount < 2) {
      Log.d("播放结束，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      setPlayer(refreshUrls: _shouldRefreshUrlsOnPlaybackRetry);
      return;
    }

    Log.d("播放结束");
    // 遍历线路，如果全部链接都断开就是直播结束了
    if (playUrls.length - 1 == currentLineIndex) {
      liveStatus.value = false;
      await _tryAutoSwitchToNextLiveRoom(reason: "live_end");
    } else {
      changePlayLine(currentLineIndex + 1);

      //setPlayer();
    }
  }

  int mediaErrorRetryCount = 0;
  @override
  void mediaError(String error) async {
    if (mediaErrorRetryCount < 2) {
      Log.d("播放失败，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      setPlayer(refreshUrls: _shouldRefreshUrlsOnPlaybackRetry);
      return;
    }

    if (playUrls.length - 1 == currentLineIndex) {
      errorMsg.value = "播放失败";
      SmartDialog.showToast("播放失败:$error");
      await _tryAutoSwitchToNextLiveRoom(reason: "playback_failure");
    } else {
      //currentLineIndex += 1;
      //setPlayer();
      changePlayLine(currentLineIndex + 1);
    }
  }

  Future<void> _tryAutoSwitchToNextLiveRoom({required String reason}) async {
    final settings = AppSettingsController.instance;
    final enabled = reason == "live_end"
        ? settings.autoSwitchNextOnLiveEnd.value
        : settings.autoSwitchNextOnPlaybackFailure.value;
    if (!enabled || _autoSwitchingRoom) {
      return;
    }

    final liveChannels = FollowUserService.instance.livingList.toList();
    if (liveChannels.isEmpty) {
      return;
    }

    final currentId = "${site.id}_$roomId";
    final currentIndex =
        liveChannels.indexWhere((item) => item.id == currentId);
    final candidates =
        liveChannels.where((item) => item.id != currentId).toList();
    if (candidates.isEmpty) {
      return;
    }

    FollowUser target;
    if (currentIndex < 0 || currentIndex >= liveChannels.length - 1) {
      target = candidates.first;
    } else {
      target = liveChannels[currentIndex + 1];
      if (target.id == currentId) {
        target = candidates.first;
      }
    }

    _autoSwitchingRoom = true;
    try {
      SmartDialog.showToast(
        reason == "live_end" ? "当前直播已结束，已切换到下一个直播间" : "当前直播播放失败，已切换到下一个直播间",
      );
      resetRoom(Sites.allSites[target.siteId]!, target.roomId);
    } finally {
      _autoSwitchingRoom = false;
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

  void setCurrentFollowTag(String tagName) {
    if (detail.value == null) return;
    final id = "${site.id}_$roomId";
    var follow = DBService.instance.followBox.get(id);
    if (follow == null) {
      followUser();
      follow = DBService.instance.followBox.get(id);
    }
    if (follow == null) return;
    follow.tag = tagName;
    DBService.instance.addFollow(follow);
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

    // 刷新信息
    loadData();
  }

  void nextChannel() {
    //读取正在直播的频道
    var liveChannels = FollowUserService.instance.livingList;
    if (liveChannels.isEmpty) {
      SmartDialog.showToast("没有正在直播的频道");
      return;
    }
    var index = liveChannels
        .indexWhere((element) => element.id == "${site.id}_$roomId");
    if (index == -1) {
      SmartDialog.showToast("当前直播间不在直播列表中");
      return;
    }
    index += 1;
    if (index >= liveChannels.length) {
      index = 0;
    }
    var nextChannel = liveChannels[index];

    resetRoom(Sites.allSites[nextChannel.siteId]!, nextChannel.roomId);
  }

  void prevChannel() {
    //读取正在直播的频道
    var liveChannels = FollowUserService.instance.livingList;
    if (liveChannels.isEmpty) {
      SmartDialog.showToast("没有正在直播的频道");
      return;
    }
    var index = liveChannels
        .indexWhere((element) => element.id == "${site.id}_$roomId");
    if (index == -1) {
      SmartDialog.showToast("当前直播间不在直播列表中");
      return;
    }
    index -= 1;
    if (index < 0) {
      index = liveChannels.length - 1;
    }
    var nextChannel = liveChannels[index];

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

    danmakuController = null;
    super.onClose();
  }
}
