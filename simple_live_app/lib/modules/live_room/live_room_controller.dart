import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/services/room_emoticons.dart';
import 'package:simple_live_app/services/self_danmaku_identity.dart';
import 'package:simple_live_app/services/search_danmaku_credentials.dart';
import 'package:simple_live_app/services/playback_diagnostics.dart';
import 'package:simple_live_app/services/room_startup_cache.dart';
import 'package:simple_live_app/services/playback_route_history.dart';
import 'package:simple_live_app/widgets/live_message_content.dart';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/services/windows_share_service.dart';
import 'playback_session.dart';
import 'player/native_playback_events.dart';
import 'room_share_dialog.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class _RoomOffline implements Exception {
  const _RoomOffline();
}

class LiveRoomController extends PlayerController with WidgetsBindingObserver {
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
    // 抖音应该默认是竖屏的
    if (site.id == "douyin") {
      isVertical.value = true;
    }
  }

  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var followed = false.obs;
  var liveStatus = false.obs;
  // Unlike the initial false liveStatus, this means the server confirmed offline.
  var roomOffline = false.obs;
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();

  /// 滚动控制
  final ScrollController scrollController = ScrollController();
  bool _chatScrollScheduled = false;

  /// 聊天信息
  RxList<LiveMessage> messages = RxList<LiveMessage>();

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  bool _nativeAutoSelection = false;
  final _nativeDropGuard = PlaybackDropGuard();
  List<NativeHlsVariant> _nativeVariants = [];
  int? _nativeFallbackFrom;
  double? _nativeFpsCeiling;
  final _qualityFallbacks = <int>{};

  @override
  void playbackSample(PlaybackSnapshot sample) {
    if (!_nativeAutoSelection || !AppSettingsController.instance.preferNativeFrameRate.value ||
        _roomClosed || isBackground ||
        !hasPlayed.value || _playback.recovery != null || !player.state.playing) {
      _nativeDropGuard.reset();
      return;
    }
    if (!_nativeDropGuard.add(sample, sample.elapsed,
        buffering: player.state.buffering)) {
      return;
    }
    final fps = sample.sourceFps;
    if (fps == null) return;
    final variant = chooseNativeHlsVariant(_nativeVariants,
        displayHz: nativeDisplayHz, maxFrameRate: fps - 1);
    if (variant != null && variant.frameRate >= 59 &&
        (playUrls.isEmpty || variant.uri.toString() != playUrls[currentLineIndex])) {
      // Reuse the already parsed manifest; do not probe the network on every sample.
      playUrls.value = _nativeVariants
          .where((v) => (v.frameRate - variant.frameRate).abs() < 0.01)
          .map((v) => v.uri.toString()).toSet().toList();
      playUrls.remove(variant.uri.toString());
      playUrls.insert(0, variant.uri.toString());
      currentLineIndex = 0;
      _nativeFpsCeiling = variant.frameRate;
      currentQualityInfo.value = 'HLS · ${variant.frameRate.toStringAsFixed(2)}fps（清单标称）';
      _nativeDropGuard.reset();
      unawaited(setPlayer());
      return;
    }
    var candidate = -1;
    var best = 0.0;
    for (var i = 0; i < qualites.length; i++) {
      final rate = nativeFrameRate(qualites[i].frameRate);
      if (i == currentQuality || _qualityFallbacks.contains(i) || rate == null ||
          rate >= fps - 1 || rate < 59 ||
          (nativeDisplayHz > 0 && rate > nativeDisplayHz + 1)) {
        continue;
      }
      if (rate > best) { candidate = i; best = rate; }
    }
    if (candidate < 0) return;
    _qualityFallbacks.add(currentQuality);
    _nativeFallbackFrom = currentQuality;
    currentQuality = candidate;
    _nativeDropGuard.reset();
    Log.d('持续丢帧，自动回退到已知原生帧率档位：${qualites[candidate].quality}');
    getPlayUrl();
  }

  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 退出倒计时
  var countdown = 60.obs;

  Timer? autoExitTimer;
  Timer? _autoExitFallbackTimer;

  /// 设置的自动关闭时间（分钟）
  var autoExitMinutes = 60.obs;

  ///是否延迟自动关闭
  var delayAutoExit = false.obs;

  /// 是否启用自动关闭
  var autoExitEnable = false.obs;

  /// 是否禁用自动滚动聊天栏
  /// - 当用户向上滚动聊天栏时，不再自动滚动
  var disableAutoScroll = false.obs;

  /// 是否处于后台
  var isBackground = false;

  /// 直播间加载失败
  var loadError = false.obs;
  Object? error;
  StackTrace? errorStackTrace;

  // 开播时长状态变量
  var liveDuration = "00:00:00".obs;
  Timer? _liveDurationTimer;
  final volumeScrollAnchorKey = GlobalKey();
  Timer? _volumeSliderTimer;
  bool _volumeSliderOpen = false;
  static const _volumeSliderTag = 'simple-live-volume-slider';
  int _roomRequest = 0;
  final _playback = PlaybackSession();
  NativePlaybackEvents? _nativePlaybackEvents;
  bool _roomClosed = false;
  bool similarGameRoomsOpen = false;
  Future<bool>? _offlineCheck;
  Future<int>? _qualityLevelFuture;
  Future<bool>? _cellularNetworkFuture;
  final _openWatch = Stopwatch();
  final _openMarks = <String, int>{};
  final _lineWatch = Stopwatch();
  (String, String, String)? _openingRoute;
  String get _routeQuality => currentQuality >= 0 && currentQuality < qualites.length
      ? qualites[currentQuality].quality : '';
  int _offlineCheckRequest = -1;
  bool _isCurrentRoomRequest(int request) =>
      !_roomClosed && request == _roomRequest;
  bool _isCurrentRequest(int request) =>
      !_roomClosed && request == _playback.generation;

  Future<T> _retryPlayRequest<T>(
      Future<T> Function() request, int generation) async {
    try {
      return await request();
    } catch (_) {
      if (!_isCurrentRequest(generation)) rethrow;
      if (await _confirmRoomOffline(generation)) throw const _RoomOffline();
      if (!_isCurrentRequest(generation)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!_isCurrentRequest(generation)) rethrow;
      return request();
    }
  }

  Future<bool> _confirmRoomOffline(int request) {
    if (!_isCurrentRequest(request) || detail.value == null) {
      return Future.value(false);
    }
    if (roomOffline.value) return Future.value(true);
    if (_offlineCheckRequest == request && _offlineCheck != null) {
      return _offlineCheck!;
    }
    _offlineCheckRequest = request;
    final check = _readOfflineStatus(request);
    _offlineCheck = check;
    return check.whenComplete(() {
      if (identical(_offlineCheck, check)) _offlineCheck = null;
    });
  }

  Future<bool> _readOfflineStatus(int request) async {
    final source = site.liveSite;
    final id = roomId;
    try {
      // Status verification must not turn a transient failure into another long wait.
      final fresh = await source
          .getRoomDetail(roomId: id)
          .timeout(const Duration(seconds: 3));
      if (!_isCurrentRequest(request)) return false;
      if (fresh.status || fresh.isRecord) return false;
      _setRoomOffline(fresh);
      return true;
    } catch (e) {
      // A timeout, rate limit or transport error is NOT evidence of shutdown.
      Log.d('核验直播状态失败，保留原重试流程：${e.runtimeType}');
      return false;
    }
  }

  void _setRoomOffline(LiveRoomDetail room) {
    _lineWatch.stop();
    _nativePlaybackEvents?.reset();
    final request =
        _playback.advance(); // All old quality/URL/player results are stale.
    detail.value = room;
    roomOffline.value = true;
    liveStatus.value = false;
    online.value = 0;
    loadError.value = false;
    error = null;
    errorStackTrace = null;
    errorMsg.value = '';
    qualites.clear();
    playUrls.clear();
    playHeaders = null;
    currentQuality = -1;
    currentLineIndex = -1;
    currentQualityInfo.value = '';
    currentLineInfo.value = '';
    _liveDurationTimer?.cancel();
    liveDuration.value = '00:00:00';
    _stopDanmaku();
    addSysMsg('主播已下播，已停止加载和自动重试');
    SmartDialog.dismiss(status: SmartStatus.loading);
    // Show offline immediately. A previous native open/stop may still be pending;
    // serialize cleanup behind it without holding the UI/loading dialog hostage.
    unawaited(_playback.enqueue(() async {
      if (!_isCurrentRequest(request) || !roomOffline.value) return;
      try {
        await player.stop();
      } catch (e) {
        Log.logPrint(e);
      }
    }));
  }

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    if (FollowService.instance.followList.isEmpty) {
      FollowService.instance.loadData();
    }
    initAutoExit();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    _loadSelfChatNickname();
    loadData(reusePrefetch: true);

    scrollController.addListener(scrollListener);

    super.onInit();
  }

  void scrollListener() {
    if (scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      disableAutoScroll.value = true;
    }
  }

  /// 初始化自动关闭倒计时
  void initAutoExit() {
    if (AppSettingsController.instance.autoExitEnable.value) {
      autoExitEnable.value = true;
      autoExitMinutes.value =
          AppSettingsController.instance.autoExitDuration.value;
      setAutoExit();
    } else {
      autoExitMinutes.value =
          AppSettingsController.instance.roomAutoExitDuration.value;
    }
  }

  void setAutoExit() {
    _autoExitFallbackTimer?.cancel();
    if (_roomClosed) return;
    if (!autoExitEnable.value) {
      autoExitTimer?.cancel();
      return;
    }
    autoExitTimer?.cancel();
    countdown.value = autoExitMinutes.value * 60;
    autoExitTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      countdown.value -= 1;
      if (countdown.value <= 0) {
        timer.cancel();
        _autoExitFallbackTimer = Timer(const Duration(seconds: 10), () async {
          if (_roomClosed || !autoExitEnable.value) return;
          await WakelockPlus.disable();
          if (_roomClosed || !autoExitEnable.value) return;
          exit(0);
        });
        autoExitTimer?.cancel();
        var delay = await Utils.showAlertDialog("定时关闭已到时,是否延迟关闭?",
            title: "延迟关闭", confirm: "延迟", cancel: "关闭", selectable: true);
        if (_roomClosed) return;
        _autoExitFallbackTimer?.cancel();
        _autoExitFallbackTimer = null;
        if (delay) {
          delayAutoExit.value = true;
          showAutoExitSheet();
          setAutoExit();
        } else {
          delayAutoExit.value = false;
          await WakelockPlus.disable();
          exit(0);
        }
      }
    });
  }
  // 弹窗逻辑

  void refreshRoom() {
    //messages.clear();
    superChats.clear();
    loadData();
  }

  /// 聊天栏始终滚动到底部
  void chatScrollToBottom() {
    if (scrollController.hasClients) {
      // 如果手动上拉过，就不自动滚动到底部
      if (disableAutoScroll.value) {
        return;
      }
      final position = scrollController.position;
      if (position.pixels != position.maxScrollExtent) {
        scrollController.jumpTo(position.maxScrollExtent);
      }
    }
  }

  RoomEmoticons? _emoticons;
  RoomEmoticons? get roomEmoticons => _emoticons;
  int _pendingEmoticonDanmaku = 0;
  List<LiveMessagePart> messageParts(LiveMessage message) =>
      _emoticons?.resolve(message) ?? message.parts;

  /// 初始化弹幕接收事件
  void initDanmau() {
    _emoticons?.dispose();
    final resolver = RoomEmoticons(platform:site.id,roomId:roomId,
      args:detail.value?.danmakuData);
    _emoticons = resolver;
    resolver.addListener(() {
      if (!_roomClosed && identical(_emoticons,resolver)) messages.refresh();
    });
    unawaited(resolver.load());
    final request = _roomRequest;
    final source = liveDanmaku;
    bool current() => _isCurrentRoomRequest(request) &&
        identical(source, liveDanmaku) && !roomOffline.value;
    source.onMessage = (message) { if (current()) onWSMessage(message); };
    source.onClose = (message) { if (current()) onWSClose(message); };
    source.onReady = () { if (current()) onWSReady(); };
  }

  void _stopDanmaku() {
    // Detach first: socket.close may emit callbacks after the next room starts.
    liveDanmaku.onMessage = null;
    liveDanmaku.onClose = null;
    liveDanmaku.onReady = null;
    unawaited(liveDanmaku.stop().catchError((Object error) {
      Log.d('关闭弹幕连接失败：${error.runtimeType}');
    }));
  }

  void _appendChatMessage(LiveMessage message) {
    if (_roomClosed) return;
    // Reading older history must not turn an active room into an unbounded log.
    final limit = disableAutoScroll.value ? 1000 : 200;
    if (messages.length >= limit) {
      messages.removeRange(0, messages.length - limit + 1);
    }
    messages.add(message);
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) {
    if (_roomClosed) return;
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

      _appendChatMessage(msg);

      // 同一帧消息合并滚动，避免每条消息重复提交布局后的滚动操作。
      if (!_chatScrollScheduled && !disableAutoScroll.value) {
        _chatScrollScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _chatScrollScheduled = false;
          if (!_roomClosed) chatScrollToBottom();
        });
      }
      if (!liveStatus.value || isBackground) {
        return;
      }

      final resolver = _emoticons;
      final request = _roomRequest;
      void display() {
        if (_roomClosed || request != _roomRequest || isBackground ||
            !liveStatus.value || !identical(resolver,_emoticons)) return;
        final parts = messageParts(msg);
        addDanmaku([
          DanmakuContentItem(msg.message,
            extra: msg,
            selfSend: isSelfMessage(msg),
            spans: parts.any((p)=>p.emoticon != null) ? emoticonDanmakuSpans(parts) : null,
            color:Color.fromARGB(255,msg.color.r,msg.color.g,msg.color.b)),
        ]);
      }
      final resolved = messageParts(msg);
      // Unknown first-room tokens can use the in-flight directory. Ordinary
      // text and known/native images never wait; chat itself is always immediate.
      final hasUnknownToken = resolved.any((p)=>p.emoticon == null &&
        (p.text.contains('[') || p.text.contains('/{'))) ||
        (msg.emoticonKey != null && !resolved.any((p)=>p.emoticon != null));
      final pending = hasUnknownToken ? resolver?.retryIfDue() : null;
      if (pending != null && _pendingEmoticonDanmaku < 200) {
        _pendingEmoticonDanmaku++;
        unawaited(pending.then((_)=>display()).whenComplete(()=>_pendingEmoticonDanmaku--));
      } else {
        display();
      }
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      superChats.add(msg.data);
    }
  }

  /// 添加一条系统消息
  void addSysMsg(String msg) {
    _appendChatMessage(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: msg,
        color: LiveMessageColor.white,
      ),
    );
  }

  /// 接收到WebSocket关闭信息
  void onWSClose(String msg) {
    addSysMsg(msg);
  }

  /// WebSocket准备就绪
  void onWSReady() {
    addSysMsg("弹幕服务器连接正常");
  }

  /// 加载直播间信息
  void loadData({bool reusePrefetch = false}) async {
    resetFollowShortcut();
    if (_roomClosed) return;
    final request = ++_roomRequest;
    final playRequest = _playback.advance();
    _nativePlaybackEvents?.reset();
    _stopDanmaku();
    liveDanmaku = site.liveSite.getDanmaku();
    _openWatch
      ..reset()
      ..start();
    _openMarks.clear();
    startupTiming.value = '';
    _lineWatch.stop();
    // 网络类型判断和播放器初始化都不依赖房间数据，先和下面的请求并行跑，
    // 地址到手时播放器已经就绪，可以直接 open。
    _cellularNetworkFuture = null;
    _qualityLevelFuture = _readQualityLevel();
    unawaited(initializePlayer().catchError((Object e) {
      Log.d('播放器预热失败：$e');
    }));
    // 只依赖 roomId 的取流请求（B 站清晰度、斗鱼加密串）和房间详情并行发出。
    site.liveSite.prefetchRoom(roomId);
    playUrls.clear();
    currentLineIndex = -1;
    currentLineInfo.value = "";
    try {
      // 打开直播间不弹全屏加载圈：白色转圈会盖住画面，
      // 加载状态由聊天区的系统消息和播放器自身表现。
      loadError.value = false;
      roomOffline.value = false;
      errorMsg.value = '';
      error = null;
      errorStackTrace = null;
      update();
      addSysMsg("正在读取直播间信息");
      final roomSite = site;
      final roomIdToLoad = roomId;
      final roomDetail = await (reusePrefetch
          ? RoomStartupCache.instance.take(roomSite.liveSite, roomIdToLoad)
          : RoomStartupCache.instance.refresh(roomSite.liveSite, roomIdToLoad));
      if (!_isCurrentRoomRequest(request)) return;
      detail.value = roomDetail;
      _markOpen('详情');
      if (!roomDetail.status && !roomDetail.isRecord) {
        _setRoomOffline(roomDetail);
        addHistory();
        return;
      }

      if (site.id == Constant.kDouyin) {
        // 1.6.0之前收藏的WebRid
        // 1.6.0收藏的RoomID
        // 1.6.0之后改回WebRid
        if (detail.value!.roomId != roomId) {
          var oldId = roomId;
          rxRoomId.value = detail.value!.roomId;
          if (followed.value) {
            // 更新关注列表
            DBService.instance.deleteFollow("${site.id}_$oldId");
            DBService.instance.addFollow(
              FollowUser(
                id: "${site.id}_$roomId",
                roomId: roomId,
                siteId: site.id,
                userName: detail.value!.userName,
                face: detail.value!.userAvatar,
                addTime: DateTime.now(),
              ),
            );
          } else {
            followed.value =
                DBService.instance.getFollowExist("${site.id}_$roomId");
          }
        }
      }

      // 取流优先发出，历史记录/关注状态和弹幕不占据网络请求的前置链路。
      getPlayQualites(playRequest);
      getSuperChatMessage(request);

      addHistory();
      // 确认房间关注状态
      followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (detail.value!.isRecord) {
        addSysMsg("当前主播未开播，正在轮播录像");
      }
      addSysMsg("开始连接弹幕服务器");
      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
      startLiveDurationTimer(); // 启动开播时长定时器
    } catch (e, stackTrace) {
      if (!_isCurrentRoomRequest(request)) return;
      Log.logPrint(e);
      //SmartDialog.showToast(e.toString());
      loadError.value = true;
      error = e;
      errorStackTrace = stackTrace;
    }
  }

  /// 记录开播链路各阶段耗时，仅在日志开关打开时输出。
  void _markOpen(String name) {
    if (!_openWatch.isRunning) return;
    _openMarks[name] = _openWatch.elapsedMilliseconds;
  }

  void _logOpenDuration() {
    if (!_openWatch.isRunning) return;
    _openWatch.stop();
    if (_openMarks.isEmpty) {
      return;
    }
    var last = 0;
    final segments = <String>[];
    for (final entry in _openMarks.entries) {
      segments.add('${entry.key} ${entry.value - last}ms');
      last = entry.value;
    }
    startupTiming.value = '${segments.join(' · ')} · 合计 ${_openWatch.elapsedMilliseconds}ms';
    if (AppSettingsController.instance.logEnable.value) {
      Log.d('开播耗时 ${startupTiming.value}');
    }
  }

  /// 初始化播放器
  void getPlayQualites(int request) async {
    if (!_isCurrentRequest(request) ||
        roomOffline.value ||
        detail.value == null) return;
    qualites.clear();
    _qualityFallbacks.clear();
    _nativeFpsCeiling = null;
    _nativeDropGuard.reset();
    currentQuality = -1;

    try {
      var playQualites = await _retryPlayRequest(() async {
        final result =
            await site.liveSite.getPlayQualites(detail: detail.value!);
        if (result.isEmpty) throw StateError('播放清晰度列表为空');
        return result;
      }, request);
      if (!_isCurrentRequest(request)) return;
      qualites.value = playQualites;
      _markOpen('清晰度');
      var qualityLevel = await getQualityLevel();
      final cellular = usesCellularQuality && await _isCellularNetwork();
      if (!_isCurrentRequest(request)) return;
      _nativeAutoSelection =
          !cellular && AppSettingsController.instance.preferNativeFrameRate.value;
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

      if (_nativeAutoSelection) {
        currentQuality = preferredNativeQuality(playQualites,
            fallback: currentQuality, displayHz: nativeDisplayHz);
      }
      getPlayUrl(request: request);
    } catch (e) {
      if (!_isCurrentRequest(request)) return;
      Log.logPrint(e);
      SmartDialog.showToast("无法读取播放清晰度");
    }
  }

  /// 清晰度偏好只取决于当前网络类型，查一次就够。
  /// 提前预热，避免它夹在「房间详情 → 清晰度列表 → 播放地址」的串行链里。
  Future<int> getQualityLevel() {
    return _qualityLevelFuture ??= _readQualityLevel();
  }

  Future<int> _readQualityLevel() async {
    final settings = AppSettingsController.instance;
    return usesCellularQuality && await _isCellularNetwork()
        ? settings.qualityLevelCellular.value
        : settings.qualityLevel.value;
  }

  // 桌面没有移动流量画质策略，不调用原生网络查询。
  @visibleForTesting
  bool get usesCellularQuality => Platform.isAndroid || Platform.isIOS;

  Future<bool> _isCellularNetwork() =>
      _cellularNetworkFuture ??= _readCellularNetwork();

  Future<bool> _readCellularNetwork() async {
    try {
      final transports = await Connectivity().checkConnectivity()
          .timeout(const Duration(milliseconds: 700));
      return transports.contains(ConnectivityResult.mobile) &&
          !transports.contains(ConnectivityResult.wifi) &&
          !transports.contains(ConnectivityResult.ethernet);
    } catch (e) {
      Log.logPrint(e);
      return false;
    }
  }

  void getPlayUrl({int? request}) async {
    if (roomOffline.value) return;
    final currentRequest = request ?? _playback.advance();
    if (!_isCurrentRequest(currentRequest) ||
        currentQuality < 0 ||
        currentQuality >= qualites.length ||
        detail.value == null) {
      return;
    }
    final quality = qualites[currentQuality];
    final fallbackFrom = _nativeFallbackFrom;
    _nativeFallbackFrom = null;
    final roomDetail = detail.value!;
    try {
      var playUrl = await _retryPlayRequest(() async {
        final result = await site.liveSite
            .getPlayUrls(detail: roomDetail, quality: quality);
        if (result.urls.isEmpty) throw StateError('播放地址列表为空');
        return result;
      }, currentRequest);
      if (!_isCurrentRequest(currentRequest)) return;
      // Manual quality choices are never replaced by automatic master selection.
      if (_nativeAutoSelection && AppSettingsController.instance.preferNativeFrameRate.value) {
        final qualityCap = fallbackFrom != null ? nativeFrameRate(quality.frameRate) : null;
        final fallbackFps = qualityCap != null && (_nativeFpsCeiling == null || qualityCap < _nativeFpsCeiling!)
            ? qualityCap : _nativeFpsCeiling;
        final ceiling = fallbackFps != null && (nativeDisplayHz <= 0 || fallbackFps < nativeDisplayHz)
            ? fallbackFps : nativeDisplayHz;
        playUrl = await preferNativeHls(playUrl, displayHz: ceiling, maxFrameRate: fallbackFps);
        if (playUrl.urls.isEmpty) throw StateError('此清单没有符合稳定播放要求的帧率档位');
        if (fallbackFps != null && _isCurrentRequest(currentRequest)) _nativeFpsCeiling = fallbackFps;
        if (!_isCurrentRequest(currentRequest)) return;
      }
      _nativeVariants = playUrl.nativeVariants;
      final urls = [...playUrl.urls];
      final preferred = playUrl.selectedNativeVariant == null
          ? PlaybackRouteHistory.instance.select(site.id, quality.quality, urls) : 0;
      if (preferred > 0) urls.insert(0, urls.removeAt(preferred));
      playUrls.value = urls;
      _markOpen('地址');
      playHeaders = playUrl.headers;
      final variant = playUrl.selectedNativeVariant;
      currentQualityInfo.value = variant == null ? quality.quality
          : 'HLS · ${variant.frameRate.toStringAsFixed(2)}fps（清单标称）';
      currentLineIndex = 0;
      currentLineInfo.value = "线路1";
      mediaErrorRetryCount = 0;
      errorMsg.value = '';
      initPlaylist(currentRequest);
    } catch (e) {
      if (!_isCurrentRequest(currentRequest)) return;
      if (fallbackFrom != null) {
        _qualityFallbacks.add(currentQuality);
        currentQuality = fallbackFrom;
        _nativeDropGuard.reset();
        Log.d('自动降档未取得可用流，保留原连接');
        return;
      }
      Log.logPrint(e);
      if (site.id == Constant.kHuya && e is StateError) {
        errorMsg.value = e.message.toString();
      }
      SmartDialog.showToast("无法读取播放地址");
    }
  }

  void changePlayLine(int index) {
    if (roomOffline.value) return;
    if (index < 0 || index >= playUrls.length) return;
    _playback.bufferingTimer?.cancel();
    currentLineIndex = index;
    //重置错误次数
    mediaErrorRetryCount = 0;
    setPlayer();
  }

  void initPlaylist(int request) {
    if (!_isCurrentRequest(request)) return;
    // Initial play and manual/recovery actions must share the same pending key.
    // Otherwise an action during startup can queue a second open after first frame.
    unawaited(setPlayer());
  }
  Future<void> setPlayer() async {
    if (roomOffline.value) return;
    if (currentLineIndex < 0 || currentLineIndex >= playUrls.length) return;
    _playback.cancelWatchdogs();
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";
    final request = _playback.generation;
    final lineIndex = currentLineIndex;
    final mediaUrl = playUrls[lineIndex];
    final headers = playHeaders;
    final key = (request, lineIndex, mediaUrl, headers);
    await _playback.open(key, (isLatest) async {
      bool isCurrent() =>
          isLatest() && _isCurrentRequest(request) && currentLineIndex == lineIndex;
      if (!isCurrent()) return;
      try {
        await initializePlayer();
        if (!isCurrent()) return;
        var url = mediaUrl;
        if (AppSettingsController.instance.playerForceHttps.value) {
          url = url.replaceAll('http://', 'https://');
        }
        await configurePlaybackProxy(url);
        if (!isCurrent()) return;
        hasPlayed.value = false;
        _douyinRecoveryProgress = null;
        playbackDiagnostics?.reset();
        _nativeDropGuard.reset();
        _openingRoute = (site.id, _routeQuality, mediaUrl);
        _lineWatch..reset()..start();
        _markOpen('提交开流');
        final native = await _prepareNativePlaybackEvents();
        if (!isCurrent()) return;
        final revision = _playback.openRevision;
        await player.open(Media(url, httpHeaders: headers));
        if (native != null && isCurrent()) {
          try {
            final entry = int.tryParse(await native.getProperty('playlist/0/id'));
            if (entry != null && isCurrent()) {
              _nativePlaybackEvents?.track(revision, entry);
            }
          } catch (e) {
            Log.d('读取播放条目失败：${e.runtimeType}');
          }
        }
      } catch (e) {
        if (!isCurrent()) return;
        if (await _confirmRoomOffline(request)) return;
        if (!isCurrent()) return;
        Log.logPrint(e);
        errorMsg.value = "播放失败";
      }
    });
  }

  Future<NativePlayer?> _prepareNativePlaybackEvents() async {
    if (!Platform.isWindows && !Platform.isAndroid) return null;
    try {
      final native = player.platform;
      if (native is! NativePlayer) return null;
      final handle = await native.handle;
      if (_roomClosed || handle == 0) return null;
      _nativePlaybackEvents ??= NativePlaybackEvents(handle, (revision, error) {
        if (revision == _playback.openRevision) {
          _checkPlaybackFailure(error: 'libmpv ($error)', nativeTerminal: true);
        }
      });
      _nativePlaybackEvents!.reset();
      return native;
    } catch (_) {
      return null;
    }
  }

  @override
  void mediaEnd() {
    _checkPlaybackFailure();
  }

  int mediaErrorRetryCount = 0;
  Duration? _douyinRecoveryProgress;
  @override
  void mediaError(String error) {
    if (_nativePlaybackEvents?.tracking ?? false) return;
    _checkPlaybackFailure(error: error);
  }

  void _checkPlaybackFailure({String? error, bool nativeTerminal = false}) {
    if (_roomClosed ||
        roomOffline.value ||
        isBackground ||
        (!nativeTerminal && _playback.recovery != null) ||
        playUrls.isEmpty ||
        (!nativeTerminal && (_playback.failureTimer?.isActive ?? false))) {
      return;
    }
    final request = _playback.generation;
    final revision = _playback.openRevision;
    final line = currentLineIndex;
    final position = player.state.position;
    // SDK 的错误流包含可恢复的解码和网络日志，不能每条日志都清空视频重连。
    _playback.failureTimer?.cancel();
    _playback.failureTimer = Timer(const Duration(seconds: 3), () {
      _playback.failureTimer = null;
      if (!_isCurrentRequest(request) || currentLineIndex != line ||
          revision != _playback.openRevision || isBackground) {
        return;
      }
      final state = player.state;
      if (state.position > position ||
          (!nativeTerminal && state.playing && !state.buffering && !state.completed)) {
        return;
      }
      // 结束通知可能属于上一条流，只有当前流也结束时才恢复。
      if (error == null && !state.completed) return;
      _recoverPlayback(error: error, nativeTerminal: nativeTerminal);
    });
  }

  Future<void> _recoverPlayback({String? error, bool startup = false,
      bool nativeTerminal = false}) async {
    final request = _playback.generation;
    if (_playback.recovery != null || !_isCurrentRequest(request) || playUrls.isEmpty) return;
    final originalLine = currentLineIndex;
    final position = player.state.position;
    final openRevision = _playback.openRevision;
    bool stillStalled() {
      if (!_isCurrentRequest(request) || isBackground ||
          currentLineIndex != originalLine ||
          openRevision != _playback.openRevision) {
        return false;
      }
      final state = player.state;
      return state.position <= position &&
          (nativeTerminal || !(state.playing && !state.buffering && !state.completed));
    }
    final recovery = _playback.recovery = Object();
    _playback.bufferingTimer?.cancel();
    try {
      if (site.id == Constant.kDouyin && stillStalled()) {
        if (currentLineIndex + 1 < playUrls.length) {
          PlaybackRouteHistory.instance.failure(site.id, _routeQuality, playUrls[originalLine]);
          currentLineIndex++;
          await setPlayer();
          return;
        }
        if (mediaErrorRetryCount == 0 &&
            currentQuality >= 0 && currentQuality < qualites.length &&
            detail.value != null) {
          await _recoverDouyinRoutes(stillStalled);
          return;
        }
      }
      if (await _confirmRoomOffline(request)) return;
      // 网络核验期间可能已经自然恢复或被手动切线，不再打断新连接。
      if (!stillStalled()) return;
      PlaybackRouteHistory.instance.failure(site.id, _routeQuality, playUrls[currentLineIndex]);
      _lineWatch.stop();
      // 首次无进展且已有备用流，不再串行等待同一平台重新签名取流。
      // 播放中断流仍保留下面的鉴权更新流程。
      if (startup && !hasPlayed.value && currentLineIndex + 1 < playUrls.length) {
        currentLineIndex++;
        mediaErrorRetryCount = 0;
        await setPlayer();
        return;
      }
      if ((site.id == Constant.kHuya || site.id == Constant.kBiliBili) &&
          detail.value != null &&
          currentQuality >= 0 && currentQuality < qualites.length) {
        final line = currentLineIndex;
        final oldUri = Uri.tryParse(playUrls[line]);
        try {
          var fresh = await site.liveSite.getPlayUrls(
              detail: detail.value!, quality: qualites[currentQuality])
              .timeout(const Duration(seconds: 4));
          if (!stillStalled()) return;
          if (_nativeAutoSelection && AppSettingsController.instance.preferNativeFrameRate.value) {
            fresh = await preferNativeHls(fresh,
                displayHz: nativeDisplayHz, maxFrameRate: _nativeFpsCeiling);
            if (!stillStalled()) return;
          }
          if (fresh.urls.isNotEmpty) {
            _nativeVariants = fresh.nativeVariants;
            final sameLine = fresh.urls.indexWhere((url) {
              final uri = Uri.tryParse(url);
              return uri?.host == oldUri?.host && uri?.path == oldUri?.path;
            });
            playUrls.value = fresh.urls;
            playHeaders = fresh.headers;
            currentLineIndex = sameLine >= 0 ? sameLine : -1;
          }
        } catch (e) {
          Log.d('${site.name}重新获取播放地址失败：${e.runtimeType}');
          if (!stillStalled()) return;
        }
        if (!_isCurrentRequest(request) || isBackground) return;
      }
      // 优先切换备用线路，不在已失效的 CDN 上连续等待。
      if (currentLineIndex + 1 < playUrls.length) {
        currentLineIndex++;
        mediaErrorRetryCount = 0;
        await setPlayer();
      } else if (mediaErrorRetryCount < 2) {
        mediaErrorRetryCount++;
        await setPlayer();
      } else if (error == null) {
        errorMsg.value = '直播连接已中断，请刷新重试';
      } else {
        errorMsg.value = "播放失败";
        SmartDialog.showToast("播放失败:$error");
      }
    } finally {
      if (identical(_playback.recovery, recovery)) _playback.recovery = null;
      // 核验期间进度恢复但仍处于缓冲时，继续观察，不能丢失看门狗。
      if (_isCurrentRequest(request) && !isBackground &&
          currentLineIndex == originalLine && player.state.buffering &&
          player.state.position > position) {
        mediaBuffering(true);
      }
    }
  }

  Future<void> _recoverDouyinRoutes(bool Function() stillStalled) async {
    final source = site.liveSite;
    final qualityIndex = currentQuality;
    final quality = qualites[qualityIndex];
    final args = detail.value?.danmakuData;
    final id = args is DouyinDanmakuArgs ? args.webRid : roomId;
    PlaybackRouteHistory.instance.failure(site.id, quality.quality, playUrls[currentLineIndex]);
    try {
      final freshRoom = await source.refreshRoomDetail(roomId: id)
          .timeout(const Duration(seconds: 3));
      if (!stillStalled()) return;
      if (!freshRoom.status && !freshRoom.isRecord) {
        _setRoomOffline(freshRoom);
        return;
      }
      final qualities = await source.getPlayQualites(detail: freshRoom);
      if (!stillStalled()) return;
      for (final freshQuality in qualities) {
        if (freshQuality.sort != quality.sort ||
            freshQuality.quality != quality.quality) continue;
        var fresh = await source.getPlayUrls(detail: freshRoom, quality: freshQuality);
        if (!stillStalled()) return;
        if (_nativeAutoSelection && AppSettingsController.instance.preferNativeFrameRate.value) {
          fresh = await preferNativeHls(fresh,
              displayHz: nativeDisplayHz, maxFrameRate: _nativeFpsCeiling);
          if (!stillStalled()) return;
        }
        final newLine = fresh.urls.indexWhere((url) => !playUrls.contains(url));
        if (newLine >= 0) {
          final urls = [...fresh.urls];
          urls.insert(0, urls.removeAt(newLine));
          qualites[qualityIndex] = freshQuality;
          playUrls.value = urls;
          playHeaders = fresh.headers;
          _nativeVariants = fresh.nativeVariants;
          final variant = fresh.selectedNativeVariant;
          currentQualityInfo.value = variant == null ? freshQuality.quality
              : 'HLS · ${variant.frameRate.toStringAsFixed(2)}fps（清单标称）';
          currentLineIndex = 0;
          mediaErrorRetryCount++;
          await setPlayer();
          return;
        }
        break;
      }
    } catch (e) {
      Log.d('抖音刷新播放地址失败：${e.runtimeType}');
    }
    if (!stillStalled()) return;
    mediaErrorRetryCount++;
    await setPlayer();
  }

  @override
  void mediaPosition(Duration position) {
    super.mediaPosition(position);
    if (site.id == Constant.kDouyin && mediaErrorRetryCount > 0 &&
        position > Duration.zero && !player.state.buffering) {
      final start = _douyinRecoveryProgress ??= position;
      if (position - start >= const Duration(seconds: 10)) {
        mediaErrorRetryCount = 0;
      }
    }
    if (position > Duration.zero && _lineWatch.isRunning && !_roomClosed &&
        !roomOffline.value && !isBackground) {
      _lineWatch.stop();
      final route = _openingRoute;
      if (route != null) {
        PlaybackRouteHistory.instance.success(route.$1, route.$2, route.$3, _lineWatch.elapsed);
      }
    }
    if (position > Duration.zero && _openMarks.containsKey('提交开流')) {
      // open() completes when mpv accepts the command, not when playback starts.
      _markOpen('播放进度');
      _logOpenDuration();
    }
  }

  @override
  void mediaBuffering(bool buffering) {
    if (!buffering) {
      final watch = _playback.rebufferWatch..stop();
      final route = _openingRoute;
      if (route != null && !isBackground) {
        PlaybackRouteHistory.instance.rebuffer(route.$1, route.$2, route.$3, watch.elapsed);
      }
      watch.reset();
      _playback.bufferingTimer?.cancel();
      _playback.bufferingTimer = null;
      return;
    }
    if (_playback.bufferingTimer?.isActive ?? false) return;
    if (_roomClosed || isBackground || playUrls.isEmpty) return;
    if (hasPlayed.value) _playback.rebufferWatch.start();
    final request = _playback.generation;
    final line = currentLineIndex;
    final position = player.state.position;
    // 多线路起播无进展时提早试备用线；单线路保留15秒宽限。
    final hasBackup = line + 1 < playUrls.length;
    final timeout = Duration(seconds:
        site.id == Constant.kDouyin && hasPlayed.value && hasBackup
            ? 4
            : hasPlayed.value || playUrls.length > 1 ? 8 : 15);
    _playback.bufferingTimer = Timer(timeout, () {
      _playback.bufferingTimer = null;
      if (!_isCurrentRequest(request) || currentLineIndex != line ||
          isBackground || !liveStatus.value ||
          !player.state.buffering) {
        return;
      }
      if (player.state.position > position) {
        // 仍有播放进展时继续观察，不打断健康连接。
        mediaBuffering(true);
        return;
      }
      _recoverPlayback(error: "缓冲超时", startup: !hasPlayed.value);
    });
  }

  /// 读取SC
  void getSuperChatMessage(int request) async {
    try {
      var sc =
          await site.liveSite.getSuperChatMessage(roomId: detail.value!.roomId);
      if (!_isCurrentRoomRequest(request)) return;
      superChats.addAll(sc);
    } catch (e) {
      if (!_isCurrentRoomRequest(request)) return;
      Log.logPrint(e);
      addSysMsg("SC读取失败");
    }
  }

  /// 移除掉已到期的SC
  void removeSuperChats() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    superChats.value = superChats
        .where((x) => x.endTime.millisecondsSinceEpoch > now)
        .toList();
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

  Timer? _followShortcutTimer;
  final officialEditorFocusRequest = 0.obs;
  final officialEditorExpanded = false.obs;
  final officialEditorEmojiOpen = false.obs;
  final officialEditorVisible = false.obs;
  final officialEditorFocused = false.obs;
  final officialSelfName = ''.obs;
  final _selfIdentity = SelfDanmakuIdentity();
  final _selfIdentityRevision = 0.obs;
  bool isSelfMessage(LiveMessage message) {
    _selfIdentityRevision.value;
    return _selfIdentity.matches(message);
  }
  void updateSelfIdentity(String? id, String? name) {
    final normalizedId = SelfDanmakuIdentity.validId(id);
    final normalizedName = name?.trim().isNotEmpty == true ? name!.trim()
        : normalizedId != null && normalizedId == _selfIdentity.userId ? _selfIdentity.userName : null;
    if(_selfIdentity.userId == normalizedId && _selfIdentity.userName == normalizedName) return;
    _selfIdentity.update(normalizedId,normalizedName);
    officialSelfName.value = normalizedName ?? '';
    _selfIdentityRevision.value++;
    messages.refresh(); // A receive can precede the HTTP/SDK acknowledgement.
    // O(active bullets), only on identity changes; never replay received messages.
    final canvas = danmakuController;
    if (canvas != null) {
      for (final item in [...canvas.scrollDanmaku, ...canvas.staticDanmaku]) {
        final message = item.content.extra;
        if (message is LiveMessage) item.updateSelfSend(isSelfMessage(message));
      }
    }
  }

  void _loadSelfChatNickname() {
    if (!Get.isRegistered<LocalStorageService>()) {
      officialSelfName.value = '';
      return;
    }
    officialSelfName.value = LocalStorageService.instance.getSelfChatNickname(site.id);
  }

  void updateOfficialSelfName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    // A nickname change alone is not evidence of an account/UID change.
    updateSelfIdentity(_selfIdentity.userId,clean);
    if (Get.isRegistered<LocalStorageService>()) {
      unawaited(LocalStorageService.instance.setSelfChatNickname(site.id, clean));
    }
  }

  Uri get officialEditorRoomUri => SearchRoomUrl.homeUriFor(site.id)
      .replace(pathSegments: site.id == Constant.kBiliBili
          // Normal Bilibili URLs can be activity shells containing a room
          // iframe. Open the official desktop room itself with the same profile.
          ? ['blanc', detail.value?.roomId ?? roomId] : [roomId]);

  Future<WebViewEnvironment?>? get officialEditorEnvironment {
    final search = Get.isRegistered<AppSearchController>()
        ? Get.find<AppSearchController>() : null;
    return search?.selectedSite.value?.id == site.id
        ? search!.webViewEnvironment : null;
  }

  SearchLoginView? resolveDanmakuLoginView() {
    final search = Get.isRegistered<AppSearchController>()
        ? Get.find<AppSearchController>() : null;
    final view = search?.webViewController;
    if (search == null || view == null || search.selectedSite.value?.id != site.id) return null;
    final revision = search.webViewRevision.value;
    return (view: view, isCurrent: () => search.selectedSite.value?.id == site.id &&
      search.isCurrentWebView(view, revision));
  }

  Future<void> openDanmakuComposer() async {
    if (!Platform.isWindows || _roomClosed || isClosed || detail.value == null) return;
    officialEditorVisible.value = true;
    officialEditorFocusRequest.value++;
  }

  void _resetOfficialEditor() {
    officialEditorVisible.value = false;
    officialEditorFocused.value = false;
    officialEditorExpanded.value = false;
    officialEditorEmojiOpen.value = false;
    officialEditorFocusRequest.value = 0;
    updateSelfIdentity(null,null);
    _loadSelfChatNickname();
  }
  (Site, String, LiveRoomDetail)? _followShortcutRoom;

  void resetFollowShortcut() {
    _followShortcutTimer?.cancel();
    _followShortcutTimer = null;
    _followShortcutRoom = null;
  }

  void followByDoubleQ() {
    final currentDetail = detail.value;
    if (_roomClosed || isClosed || currentDetail == null || followed.value) {
      resetFollowShortcut();
      return;
    }
    final currentRoom = (site, roomId, currentDetail);
    final secondPress = _followShortcutTimer?.isActive == true &&
        _followShortcutRoom == currentRoom;
    resetFollowShortcut();
    if (secondPress) {
      followUser();
      if (followed.value) {
        SmartDialog.showToast('关注成功', displayTime: const Duration(seconds: 2));
      }
    } else {
      _followShortcutRoom = currentRoom;
      _followShortcutTimer = Timer(
          const Duration(milliseconds: 400), resetFollowShortcut);
    }
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
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  /// 取消关注用户
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
      return;
    }

    var id = "${site.id}_$roomId";
    DBService.instance.deleteFollow(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  bool _sharingRoom = false;

  Future<void> share() async {
    final room = detail.value;
    if (room == null) return;
    final url = Uri.tryParse(room.url.trim());
    if (url == null ||
        !['http', 'https'].contains(url.scheme) ||
        url.host.isEmpty) {
      SmartDialog.showToast("直播间链接无效，暂时无法分享");
      return;
    }
    if (_sharingRoom) return;
    _sharingRoom = true;
    try {
      final userName = room.userName.trim();
      final title = room.title.trim().isNotEmpty
          ? room.title.trim()
          : userName.isNotEmpty
              ? '$userName的直播间'
              : '${site.name}直播间';
      final shareText = '$title\n$url';

      if (defaultTargetPlatform == TargetPlatform.windows) {
        await Get.dialog<void>(RoomShareDialog(
          title: title,
          url: url.toString(),
          shareText: shareText,
          onSystemShare: () => _shareUsingWindowsNative(
            title: title,
            description: userName.isNotEmpty
                ? '${site.name} - $userName'
                : '${site.name}直播间',
            url: url,
            text: shareText,
          ),
        ));
        return;
      }
      await _shareUsingSystem(title, shareText);
    } finally {
      _sharingRoom = false;
    }
  }

  Future<void> _shareUsingWindowsNative({
    required String title,
    required String description,
    required Uri url,
    required String text,
  }) async {
    try {
      final result = await WindowsShareService.shareRoom(
        title: title,
        description: description,
        url: url,
        text: text,
      );
      Log.i(
        '[RoomShare] windows native share site=${site.id} '
        'status=${result.status.name} code=${result.code} '
        'hr=${result.hresult} dataRequested=${result.dataRequested} '
        'elevated=${result.elevated} cdpDisabled=${result.cdpDisabled}',
      );
      if (result.status == WindowsShareStatus.opened) {
        // ShowShareUIForWindow only opens the OS share panel; Windows does not
        // report whether a target app completed delivery to a recipient.
        return;
      }
      if (result.status == WindowsShareStatus.unsupported) {
        SmartDialog.showToast("当前系统不支持 Windows 原生分享");
        return;
      }
      SmartDialog.showToast("无法打开系统分享面板");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开系统分享面板");
    }
  }

  Future<void> _shareUsingSystem(
    String title,
    String shareText,
  ) async {
    try {
      // Mobile platforms continue to use share_plus system share sheet.
      await SharePlus.instance.share(ShareParams(
        title: title,
        subject: title,
        text: shareText,
      ));
      // Opening a share sheet is not proof that the recipient received it.
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开系统分享，请尝试“复制链接”");
    }
  }

  void copyUrl() {
    if (detail.value == null) {
      return;
    }
    Utils.copyToClipboard(detail.value!.url);
    SmartDialog.showToast("已复制直播间链接");
  }

  /// 复制新生成的直播流
  void copyPlayUrl() async {
    // 未开播不复制
    if (!liveStatus.value) {
      return;
    }
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.urls.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    Utils.copyToClipboard(playUrl.urls.first);
    SmartDialog.showToast("已复制播放直链");
  }

  /// 底部打开播放器设置
  void showDanmuSettingsSheet() {
    Utils.showBottomSheet(
      title: "弹幕设置",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmuSettingsView(
            danmakuController: danmakuController,
            onTapDanmuShield: () {
              Get.back();
              showDanmuShield();
            },
          ),
        ],
      ),
    );
  }

  void showVolumeSlider(BuildContext targetContext) {
    _volumeSliderTimer?.cancel();
    _volumeSliderTimer = Timer(const Duration(milliseconds: 2500), () {
      SmartDialog.dismiss(status: SmartStatus.attach, tag: _volumeSliderTag);
    });
    if (_volumeSliderOpen) return;
    _volumeSliderOpen = true;
    SmartDialog.showAttach(
      targetContext: targetContext,
      alignment: Alignment.topCenter,
      maskColor: const Color(0x00000000),
      tag: _volumeSliderTag,
      usePenetrate: true,
      useAnimation: false,
      onDismiss: () {
        _volumeSliderOpen = false;
        _volumeSliderTimer?.cancel();
      },
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colors.surfaceContainerHigh,
            border: Border.all(color: colors.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Obx(
            () => SizedBox(
              width: 208,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.volume_up_outlined,
                          size: 18, color: colors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('音量', style: TextStyle(color: colors.onSurface)),
                      const Spacer(),
                      Text(
                        '${AppSettingsController.instance.playerVolume.value.round()}%',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      min: 0,
                      max: 100,
                      value: AppSettingsController.instance.playerVolume.value,
                      onChanged: (newValue) {
                        player.setVolume(newValue);
                        AppSettingsController.instance
                            .setPlayerVolume(newValue);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showQualitySheet() {
    Utils.showBottomSheet(
      title: "切换清晰度",
      child: RadioGroup(
        groupValue: currentQuality,
        onChanged: (e) {
          Get.back();
          _nativeFallbackFrom = null;
          _nativeFpsCeiling = null;
          _nativeAutoSelection = false;
          _nativeDropGuard.reset();
          currentQuality = e ?? 0;
          getPlayUrl();
        },
        child: ListView.builder(
          itemCount: qualites.length,
          itemBuilder: (_, i) {
            var item = qualites[i];
            return RadioListTile(
              value: i,
              title: Text(item.quality),
            );
          },
        ),
      ),
    );
  }

  void showPlayUrlsSheet() {
    Utils.showBottomSheet(
      title: "切换线路",
      child: RadioGroup(
        groupValue: currentLineIndex,
        onChanged: (e) {
          Get.back();
          //currentLineIndex = i;
          //setPlayer();
          changePlayLine(e ?? 0);
        },
        child: ListView.builder(
          itemCount: playUrls.length,
          itemBuilder: (_, i) {
            return RadioListTile(
              value: i,
              title: Text("线路${i + 1}"),
              secondary: Text(
                playUrls[i].contains(".flv") ? "FLV" : "HLS",
              ),
            );
          },
        ),
      ),
    );
  }

  void showPlayerSettingsSheet() {
    Utils.showBottomSheet(
      title: "画面尺寸",
      child: Obx(
        () => RadioGroup(
          groupValue: AppSettingsController.instance.scaleMode.value,
          onChanged: (e) {
            AppSettingsController.instance.setScaleMode(e ?? 0);
            updateScaleMode();
          },
          child: ListView(
            padding: AppStyle.edgeInsetsV12,
            children: const [
              RadioListTile(
                value: 0,
                title: Text("适应"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 1,
                title: Text("拉伸"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 2,
                title: Text("铺满"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 3,
                title: Text("16:9"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 4,
                title: Text("4:3"),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showDanmuShield() {
    TextEditingController keywordController = TextEditingController();

    void addKeyword() {
      if (keywordController.text.isEmpty) {
        SmartDialog.showToast("请输入关键词");
        return;
      }

      AppSettingsController.instance
          .addShieldList(keywordController.text.trim());
      keywordController.text = "";
    }

    Utils.showBottomSheet(
      title: "关键词屏蔽",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          TextField(
            controller: keywordController,
            decoration: InputDecoration(
              contentPadding: AppStyle.edgeInsetsH12,
              border: const OutlineInputBorder(),
              hintText: "请输入关键词",
              suffixIcon: TextButton.icon(
                onPressed: addKeyword,
                icon: const Icon(Icons.add),
                label: const Text("添加"),
              ),
            ),
            onSubmitted: (e) {
              addKeyword();
            },
          ),
          AppStyle.vGap12,
          Obx(
            () => Text(
              "已添加${AppSettingsController.instance.shieldList.length}个关键词（点击移除）",
              style: Get.textTheme.titleSmall,
            ),
          ),
          AppStyle.vGap12,
          Obx(
            () => Wrap(
              runSpacing: 12,
              spacing: 12,
              children: AppSettingsController.instance.shieldList
                  .map(
                    (item) => InkWell(
                      borderRadius: AppStyle.radius24,
                      onTap: () {
                        AppSettingsController.instance.removeShieldList(item);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: AppStyle.radius24,
                        ),
                        padding: AppStyle.edgeInsetsH12.copyWith(
                          top: 4,
                          bottom: 4,
                        ),
                        child: Text(
                          item,
                          style: Get.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void showFollowUserSheet() {
    Utils.showBottomSheet(
      title: "关注列表",
      child: Obx(
        () => Stack(
          children: [
            RefreshIndicator(
              onRefresh: FollowService.instance.loadData,
              child: ListView.builder(
                itemCount: FollowService.instance.liveList.length,
                itemBuilder: (_, i) {
                  var item = FollowService.instance.liveList[i];
                  return Obx(
                    () => FollowUserItem(
                      item: item,
                      playing: rxSite.value.id == item.siteId &&
                          rxRoomId.value == item.roomId,
                      onTap: () {
                        Get.back();
                        resetRoom(
                          Sites.allSites[item.siteId]!,
                          item.roomId,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Positioned(
                right: 12,
                bottom: 12,
                child: Obx(
                  () => DesktopRefreshButton(
                    refreshing: FollowService.instance.updating.value,
                    onPressed: FollowService.instance.loadData,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void showAutoExitSheet() {
    if (AppSettingsController.instance.autoExitEnable.value &&
        !delayAutoExit.value) {
      SmartDialog.showToast("已设置了全局定时关闭");
      return;
    }
    Utils.showBottomSheet(
      title: "定时关闭",
      child: ListView(
        children: [
          Obx(
            () => SwitchListTile(
              title: Text(
                "启用定时关闭",
                style: Get.textTheme.titleMedium,
              ),
              value: autoExitEnable.value,
              onChanged: (e) {
                autoExitEnable.value = e;

                setAutoExit();
                //controller.setAutoExitEnable(e);
              },
            ),
          ),
          Obx(
            () => ListTile(
              enabled: autoExitEnable.value,
              title: Text(
                "自动关闭时间：${autoExitMinutes.value ~/ 60}小时${autoExitMinutes.value % 60}分钟",
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
                //setAutoExitDuration(duration.inMinutes);
                setAutoExit();
              },
            ),
          ),
        ],
      ),
    );
  }

  void openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site.id == Constant.kBiliBili) {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyin) {
      final args = detail.value?.danmakuData;
      webUrl = "https://live.douyin.com/${args is DouyinDanmakuArgs ? args.webRid : detail.value?.roomId ?? roomId}";
      // Offline details deliberately skip chat/session initialization. Their web
      // room URL remains usable even when no native live-session ID exists.
      naviteUrl = args is DouyinDanmakuArgs
          ? "snssdk1128://webcast_room?room_id=${args.roomId}" : webUrl;
    } else if (site.id == Constant.kHuya) {
      final args = detail.value?.danmakuData;
      webUrl = "https://www.huya.com/${detail.value?.roomId ?? roomId}";
      naviteUrl = args is HuyaDanmakuArgs
          ? "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide"
          : webUrl;
    } else if (site.id == Constant.kDouyu) {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    }
    try {
      await launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void resetRoom(Site site, String roomId) async {
    resetFollowShortcut();
    if (this.site == site && this.roomId == roomId) {
      return;
    }
    _resetOfficialEditor();

    final request = ++_roomRequest;
    _lineWatch.stop();
    _playback.advance();
    _nativePlaybackEvents?.reset();
    _emoticons?.dispose();
    _emoticons = null;
    // The next identity must never expose the previous canonical send target
    // while player.stop() or the new detail request is still pending.
    detail.value = null;
    rxSite.value = site;
    rxRoomId.value = roomId;

    // 清除全部消息
    _stopDanmaku();
    messages.clear();
    superChats.clear();
    danmakuController?.clear();

    // loadData creates a new source after the native player has stopped.

    // 停止播放
    await _playback.settled;
    if (!_isCurrentRoomRequest(request)) return;
    await player.stop();
    if (!_isCurrentRoomRequest(request)) return;

    // 刷新信息
    loadData(reusePrefetch: true);
  }

  void copyErrorDetail() {
    Utils.copyToClipboard('''直播平台：${rxSite.value.name}
房间号：${rxRoomId.value}
错误信息：
${error?.toString()}
----------------
${errorStackTrace ?? ''}''');
    SmartDialog.showToast("已复制错误信息");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      Log.d("进入后台");
      //进入后台，关闭弹幕
      danmakuController?.clear();
      isBackground = true;
      _playback.cancelWatchdogs();
    } else
    //返回前台
    if (state == AppLifecycleState.resumed) {
      Log.d("返回前台");
      final wasBackground = isBackground;
      isBackground = false;
      if (wasBackground && playUrls.isNotEmpty && player.state.buffering) {
        mediaBuffering(true);
      }
    }
  }

  // 用于启动开播时长计算和更新的函数
  void startLiveDurationTimer() {
    // 如果不是直播状态或者 showTime 为空，则不启动定时器
    if (!(detail.value?.status ?? false) || detail.value?.showTime == null) {
      liveDuration.value = "00:00:00"; // 未开播时显示 00:00:00
      _liveDurationTimer?.cancel();
      return;
    }

    try {
      int startTimeStamp = int.parse(detail.value!.showTime!);
      // 取消之前的定时器
      _liveDurationTimer?.cancel();
      // 创建新的定时器，每秒更新一次
      _liveDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        int durationInSeconds = currentTimeStamp - startTimeStamp;

        int hours = durationInSeconds ~/ 3600;
        int minutes = (durationInSeconds % 3600) ~/ 60;
        int seconds = durationInSeconds % 60;

        String formattedDuration =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        liveDuration.value = formattedDuration;
      });
    } catch (e) {
      liveDuration.value = "--:--:--"; // 错误时显示 --:--:--
    }
  }

  @override
  void onClose() async {
    resetFollowShortcut();
    _resetOfficialEditor();
    _roomClosed = true;
    _nativePlaybackEvents?.dispose();
    _nativePlaybackEvents = null;
    _lineWatch.stop();
    disposeStream();
    _emoticons?.dispose();
    _emoticons = null;
    ++_roomRequest;
    _playback.advance();
    SmartDialog.dismiss(status: SmartStatus.loading);
    _volumeSliderTimer?.cancel();
    if (_volumeSliderOpen) {
      SmartDialog.dismiss(status: SmartStatus.attach, tag: _volumeSliderTag);
    }
    WidgetsBinding.instance.removeObserver(this);
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    autoExitTimer?.cancel();
    _autoExitFallbackTimer?.cancel();

    _stopDanmaku();
    danmakuController = null;
    _liveDurationTimer?.cancel(); // 页面关闭时取消定时器
    await _playback.settled;
    super.onClose();
  }
}
