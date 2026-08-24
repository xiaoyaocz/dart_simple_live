import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/desktop_startup_args.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/live_room/live_status_refresh_policy.dart';
import 'package:simple_live_app/modules/live_room/widgets/live_contribution_rank_panel.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/current_room_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

class LiveRoomController extends PlayerController
    with WidgetsBindingObserver, WindowListener {
  static const volumeSliderDialogTag = liveRoomVolumeSliderDialogTag;
  static const _appWindowChannel = MethodChannel('simple_live/app_window');
  final Site pSite;
  final String pRoomId;
  final bool initialDesktopSidePanelCollapsed;
  late LiveDanmaku liveDanmaku;
  LiveRoomController({
    required this.pSite,
    required this.pRoomId,
    this.initialDesktopSidePanelCollapsed = false,
  }) {
    rxSite = pSite.obs;
    rxRoomId = pRoomId.obs;
    desktopSidePanelCollapsed.value = initialDesktopSidePanelCollapsed;
    liveDanmaku = site.liveSite.getDanmaku();
    // 抖音直播间默认按竖屏处理。
    if (site.id == "douyin") {
      isVertical.value = true;
    }
  }

  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  @override
  int get playbackLoadGeneration => _loadGeneration;

  int _playbackMediaGeneration = 0;

  @override
  int get playbackMediaGeneration => _playbackMediaGeneration;

  @override
  bool isPlaybackLoadGenerationCurrent(int generation) {
    return !_roomDisposed &&
        !_roomSwitching &&
        super.isPlaybackLoadGenerationCurrent(generation);
  }

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var followed = false.obs;
  var liveStatus = false.obs;
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();
  RxList<LiveContributionRankItem> contributionRanks =
      RxList<LiveContributionRankItem>();
  RxList<LiveRepeatedDanmuSummary> liveEventFlows =
      RxList<LiveRepeatedDanmuSummary>();
  bool _autoSwitchingRoom = false;
  bool _roomSwitching = false;
  Site? _pendingRoomSite;
  String? _pendingRoomId;
  var contributionRankLoading = false.obs;
  var contributionRankFetched = false.obs;
  Rx<String?> contributionRankError = Rx<String?>(null);
  Rx<DateTime?> contributionRankUpdatedAt = Rx<DateTime?>(null);
  RxDouble danmakuViewportHeight = 0.0.obs;
  final liveRoomFollowFilterMode = 0.obs;
  final liveRoomSelectedPanelKey = "chat".obs;
  final desktopSidePanelCollapsed = false.obs;
  RxSet<String> tempMutedUsers = <String>{}.obs;
  bool get supportsContributionRank => const {
        Constant.kBiliBili,
        Constant.kDouyu,
        Constant.kDouyin,
      }.contains(site.id);

  void toggleDesktopSidePanel() {
    desktopSidePanelCollapsed.value = !desktopSidePanelCollapsed.value;
  }

  /// 聊天列表滚动控制器
  final ScrollController scrollController = ScrollController();

  /// 直播间右侧关注列表滚动控制器
  final ScrollController liveRoomFollowScrollController = ScrollController();

  /// 直播间弹窗关注列表滚动控制器
  final ScrollController liveRoomFollowDialogScrollController =
      ScrollController();

  /// 直播间弹窗历史列表滚动控制器
  final ScrollController liveRoomHistoryScrollController = ScrollController();

  /// 直播间弹窗同类推荐列表滚动控制器
  final ScrollController liveRoomRecommendationScrollController =
      ScrollController();

  /// 聊天消息列表
  RxList<LiveMessage> messages = RxList<LiveMessage>();

  /// 清晰度列表
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度索引
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 播放线路列表
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前播放线路索引
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 自动退出倒计时，单位秒
  var countdown = 60.obs;

  Timer? autoExitTimer;
  Timer? _autoExitDeadlineTimer;
  final AutoExitSession _autoExitSession = AutoExitSession();
  final autoExitSource = AutoExitSource.none.obs;
  bool _autoExitCompleting = false;

  /// 设置的自动关闭时长，单位分钟
  var autoExitMinutes = 60.obs;

  /// 是否已请求延迟自动关闭
  var delayAutoExit = false.obs;

  /// 是否启用自动关闭
  var autoExitEnable = false.obs;

  /// 是否禁用聊天自动滚动
  /// - 用户手动上拉聊天列表后，不再自动滚到底部
  var disableAutoScroll = false.obs;

  /// 应用是否处于后台
  var isBackground = false;

  bool get _allowBackgroundPlayback =>
      AppSettingsController.instance.allowBackgroundPlayback.value;

  /// 直播间加载是否失败
  var loadError = false.obs;
  Object? error;
  StackTrace? errorStackTrace;

  // 开播时长展示状态
  var liveDuration = "00:00:00".obs;
  Timer? _liveDurationTimer;
  StreamSubscription<Duration>? _positionSubscription;
  Duration _lastKnownPlayerPosition = Duration.zero;
  Duration? _positionBeforeBackground;
  DateTime? _backgroundedAt;
  Duration? _positionBeforeWindowBlur;
  DateTime? _windowBlurredAt;
  Future<void>? _playerReopeningFuture;
  int? _playerReopeningGeneration;
  bool _roomDisposed = false;
  int _loadGeneration = 0;
  final Set<String> _superChatFingerprints = <String>{};
  LiveRepeatedDanmuAggregator _liveEventFlowAggregator =
      LiveRepeatedDanmuAggregator();
  final Queue<String> _recentDanmuFingerprints = Queue<String>();
  final Map<String, int> _recentDanmuCounts = <String, int>{};
  int _recentDanmuEventsSincePrune = 0;
  final Set<Timer> _pendingDanmakuTimers = <Timer>{};
  Timer? _liveEventFlowTimer;
  Timer? _superChatRefreshTimer;
  Timer? _chatBottomRestoreTimer;
  Timer? _onlineRefreshTimer;
  Timer? _memoryCleanupTimer; // 内存清理定时器
  bool _onlineRefreshInFlight = false;
  final LiveStatusRefreshPolicy _onlineStatusRefreshPolicy =
      LiveStatusRefreshPolicy();
  bool _volumeSliderPointerEntered = false;
  bool _autoPipAttempting = false;

  @override
  void onInit() {
    CurrentRoomService.instance.setRoom(site, roomId);
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      windowManager.addListener(this);
    }
    if (initialDesktopSidePanelCollapsed ||
        DesktopStartupArgs.startupCollapseChat) {
      desktopSidePanelCollapsed.value = true;
    }
    if (FollowService.instance.followList.isEmpty) {
      FollowService.instance.loadData(updateStatus: false);
    }
    initAutoExit();
    showDanmakuState.value = DesktopStartupArgs.isSecondaryDesktopInstance
        ? false
        : AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    loadData();
    _startLiveEventFlowTimer();
    _startMemoryCleanupTimer(); // 启动内存清理定时器

    scrollController.addListener(scrollListener);

    super.onInit();
    _positionSubscription = player.stream.position.listen((event) {
      _lastKnownPlayerPosition = event;
    });
  }

  void scrollListener() {
    if (!scrollController.hasClients) {
      return;
    }
    if (_isChatNearBottom()) {
      disableAutoScroll.value = false;
      return;
    }
    if (scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      disableAutoScroll.value = true;
    }
  }

  bool _isChatNearBottom() {
    if (!scrollController.hasClients) {
      return true;
    }
    return scrollController.position.extentAfter <= 24;
  }

  bool _isKeywordShielded(LiveMessage msg) {
    final settings = AppSettingsController.instance;
    if (!settings.danmuShieldEnable.value ||
        !settings.danmuKeywordShieldEnable.value) {
      return false;
    }
    for (var keyword in settings.shieldList) {
      Pattern? pattern;
      if (Utils.isRegexFormat(keyword)) {
        String removedSlash = Utils.removeRegexFormat(keyword);
        try {
          pattern = RegExp(removedSlash);
        } catch (e) {
          Log.d("正则屏蔽词 $keyword 无法编译，已跳过");
        }
      } else {
        pattern = keyword;
      }
      if (pattern != null && msg.message.contains(pattern)) {
        Log.d("命中屏蔽词 $keyword\n已过滤消息: ${msg.message}");
        return true;
      }
    }
    return false;
  }

  bool _isDuplicateDanmu(LiveMessage msg) {
    if (msg.userName == "LiveSysMessage") {
      return false;
    }
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

  List<LiveSuperChatMessage> get sortedSuperChats {
    final list = superChats.toList();
    list.sort((a, b) => a.endTime.compareTo(b.endTime));
    if (AppSettingsController.instance.superChatSortDesc.value) {
      return list.reversed.toList();
    }
    return list;
  }

  bool _isUserShielded(String userName) {
    return AppSettingsController.instance.shouldShieldUser(
      userName,
      siteId: site.id,
    );
  }

  String _normalizeMessageText(String message) {
    return message.trim();
  }

  LiveRoomDetail _sanitizeRoomDetail(LiveRoomDetail detail) {
    return LiveRoomDetail(
      roomId: detail.roomId.trim(),
      title: detail.title.trim(),
      cover: detail.cover,
      userName: _normalizeUserName(detail.userName),
      userAvatar: detail.userAvatar,
      online: detail.online,
      introduction: detail.introduction?.trim(),
      notice: detail.notice?.trim(),
      status: detail.status,
      data: detail.data,
      danmakuData: detail.danmakuData,
      url: detail.url,
      isRecord: detail.isRecord,
      showTime: detail.showTime?.trim(),
      categoryId: detail.categoryId?.trim(),
      categoryName: detail.categoryName?.trim(),
      categoryParentId: detail.categoryParentId?.trim(),
      categoryParentName: detail.categoryParentName?.trim(),
      categoryPic: detail.categoryPic?.trim(),
    );
  }

  LiveMessage _sanitizeLiveMessage(LiveMessage message) {
    final normalizedUserName = message.userName == "LiveSysMessage"
        ? message.userName
        : _normalizeUserName(message.userName);
    final normalizedMessage = _normalizeMessageText(message.message);
    if (normalizedUserName == message.userName &&
        normalizedMessage == message.message) {
      return message;
    }

    return LiveMessage(
      type: message.type,
      userName: normalizedUserName,
      message: normalizedMessage,
      data: message.data,
      color: message.color,
      imageUrls: message.imageUrls,
      spans: message.spans,
    );
  }

  LiveMessage _superChatToLiveMessage(LiveSuperChatMessage superChat) {
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: superChat.userName,
      message: superChat.message,
      color: LiveMessageColor.white,
    );
  }

  String _normalizeUserName(String userName) {
    return userName.trim();
  }

  LiveSuperChatMessage _sanitizeSuperChatMessage(LiveSuperChatMessage message) {
    final normalizedUserName = _normalizeUserName(message.userName);
    final normalizedMessage = _normalizeMessageText(message.message);
    if (normalizedUserName == message.userName &&
        normalizedMessage == message.message) {
      return message;
    }

    return LiveSuperChatMessage(
      id: message.id,
      backgroundBottomColor: message.backgroundBottomColor,
      backgroundColor: message.backgroundColor,
      endTime: message.endTime,
      face: message.face,
      message: normalizedMessage,
      price: message.price,
      startTime: message.startTime,
      userName: normalizedUserName,
    );
  }

  LiveContributionRankItem _sanitizeContributionRankItem(
    LiveContributionRankItem item,
  ) {
    return LiveContributionRankItem(
      rank: item.rank,
      userName: _normalizeUserName(item.userName),
      avatar: item.avatar,
      scoreText: item.scoreText.trim(),
      scoreDetail: item.scoreDetail?.trim(),
      userLevel: item.userLevel,
      userLevelText: item.userLevelText?.trim(),
      userLevelIcon: item.userLevelIcon,
      fansLevel: item.fansLevel,
      fansName: item.fansName?.trim(),
      fansIcon: item.fansIcon,
    );
  }

  void toggleUserShield(String userName) {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      SmartDialog.showToast("用户名不能为空");
      return;
    }

    final settings = AppSettingsController.instance;
    if (settings.isUserShielded(value, siteId: site.id)) {
      settings.removeUserShieldList(value, siteId: site.id);
      SmartDialog.showToast("已取消屏蔽用户：$value");
      return;
    }

    settings.setDanmuShieldEnable(true);
    settings.setDanmuUserShieldEnable(true);
    settings.addUserShieldList(value, siteId: site.id);
    SmartDialog.showToast("已屏蔽用户：$value");
  }

  bool isTempMutedUser(String userName) {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      return false;
    }
    return tempMutedUsers.contains(value);
  }

  void toggleTempMuteUser(String userName) {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      SmartDialog.showToast("用户名不能为空");
      return;
    }
    if (tempMutedUsers.contains(value)) {
      tempMutedUsers.remove(value);
      tempMutedUsers.refresh();
      SmartDialog.showToast("已取消临时禁言：$value");
      return;
    }
    tempMutedUsers.add(value);
    tempMutedUsers.refresh();
    SmartDialog.showToast("已加入临时禁言：$value");
  }

  void clearTempMutedUsers() {
    if (tempMutedUsers.isEmpty) {
      SmartDialog.showToast("当前没有临时禁言用户");
      return;
    }
    tempMutedUsers.clear();
    tempMutedUsers.refresh();
    SmartDialog.showToast("已恢复全部临时禁言用户");
  }

  String? getUserRemark(String userName) {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      return null;
    }
    return AppSettingsController.instance.getUserRemark(
      value,
      siteId: site.id,
    );
  }

  Future<void> editUserRemark(String userName) async {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      SmartDialog.showToast("用户名不能为空");
      return;
    }
    final currentRemark = getUserRemark(value) ?? "";
    final result = await Utils.showEditTextDialog(
      currentRemark,
      title: "备注用户",
      hintText: "留空表示删除备注",
    );
    if (result == null) {
      return;
    }
    await AppSettingsController.instance.setUserRemark(
      siteId: site.id,
      userName: value,
      remark: result,
    );
    SmartDialog.showToast(
      result.trim().isEmpty ? "已删除备注" : "已更新备注：${result.trim()}",
    );
  }

  void showUserActions(
    String userName, {
    String? messageContent,
  }) {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      SmartDialog.showToast("用户名不能为空");
      return;
    }
    final normalizedMessage = messageContent == null
        ? null
        : _normalizeMessageText(messageContent).trim();
    final isShielded = AppSettingsController.instance.isUserShielded(
      value,
      siteId: site.id,
    );
    final isTempMuted = tempMutedUsers.contains(value);
    final remark = getUserRemark(value);

    Utils.showBottomSheet(
      title: value,
      child: ListView(
        children: [
          if (remark != null && remark.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text("当前备注：$remark"),
              dense: true,
            ),
          ListTile(
            leading: Icon(
              isShielded ? Icons.visibility_outlined : Icons.block_outlined,
            ),
            title: Text(isShielded ? "取消平台屏蔽" : "屏蔽当前平台"),
            subtitle: Text("仅对 ${site.name} 生效，不会误伤其他平台同名用户"),
            onTap: () {
              Get.back();
              toggleUserShield(value);
            },
          ),
          ListTile(
            leading: Icon(
              isTempMuted
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
            title: Text(isTempMuted ? "取消临时禁言" : "加入临时禁言"),
            subtitle: const Text("只在当前直播间本次会话内有效"),
            onTap: () {
              Get.back();
              toggleTempMuteUser(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: const Text("快捷备注"),
            onTap: () async {
              Get.back();
              await editUserRemark(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text("复制用户名"),
            onTap: () {
              Get.back();
              copyUserName(value);
            },
          ),
          if (normalizedMessage != null && normalizedMessage.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text("复制弹幕内容"),
              subtitle: Text(
                normalizedMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Get.back();
                copyMessageContent(normalizedMessage);
              },
            ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text("批量恢复临时禁言"),
            enabled: tempMutedUsers.isNotEmpty,
            onTap: tempMutedUsers.isEmpty
                ? null
                : () {
                    Get.back();
                    clearTempMutedUsers();
                  },
          ),
        ],
      ),
    );
  }

  void copyUserName(String userName) {
    final value = _normalizeUserName(userName);
    if (value.isEmpty) {
      SmartDialog.showToast("用户名不能为空");
      return;
    }
    Utils.copyToClipboard(value);
    SmartDialog.showToast("已复制用户名：$value");
  }

  void copyMessageContent(String message) {
    final value = _normalizeMessageText(message).trim();
    if (value.isEmpty) {
      SmartDialog.showToast("弹幕内容为空");
      return;
    }
    Utils.copyToClipboard(value);
    SmartDialog.showToast("已复制弹幕内容");
  }

  void updateDanmakuViewportHeight(double value) {
    if (value <= 0) {
      return;
    }
    if ((danmakuViewportHeight.value - value).abs() < 0.5) {
      return;
    }
    danmakuViewportHeight.value = value;
  }

  void _cancelPendingDanmakuTimers() {
    for (final timer in _pendingDanmakuTimers.toList()) {
      timer.cancel();
    }
    _pendingDanmakuTimers.clear();
  }

  void _scheduleOverlayDanmaku(LiveMessage msg) {
    final color = Color.fromARGB(
      255,
      msg.color.r,
      msg.color.g,
      msg.color.b,
    );
    final baseDelayMs = AppSettingsController.instance.getDanmuDelayMs(site.id);
    final totalDelayMs = baseDelayMs + (site.id == Constant.kHuya ? 1000 : 0);
    final delay = Duration(milliseconds: totalDelayMs.clamp(0, 6000));
    final renderEmoji = AppSettingsController.instance.danmuRenderEmoji.value;
    final parts = renderEmoji ? _buildDanmakuContentParts(msg.spans) : null;
    rememberDanmakuReplay(
      msg.message,
      color,
      delay: delay,
      imageUrls: renderEmoji && parts == null ? msg.imageUrls : null,
      parts: parts,
    );

    void emit() {
      if (!showDanmakuState.value ||
          !liveStatus.value ||
          (isBackground && !_allowBackgroundPlayback)) {
        return;
      }
      addDanmaku([
        DanmakuContentItem(
          msg.message,
          color: color,
          imageUrls: renderEmoji && parts == null ? msg.imageUrls : null,
          parts: parts,
        ),
      ]);
    }

    if (delay == Duration.zero) {
      emit();
      return;
    }

    Timer? timer;
    timer = Timer(delay, () {
      if (timer != null) {
        _pendingDanmakuTimers.remove(timer);
      }
      emit();
    });
    _pendingDanmakuTimers.add(timer);
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

  String _buildSuperChatFingerprint(LiveSuperChatMessage message) {
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return "id:$id";
    }

    return [
      message.userName,
      message.message,
      message.price,
      message.startTime.millisecondsSinceEpoch,
      message.endTime.millisecondsSinceEpoch,
    ].join("|");
  }

  bool _shouldUpdateSuperChat(
    LiveSuperChatMessage current,
    LiveSuperChatMessage next,
  ) {
    if ((current.endTime.difference(next.endTime).inSeconds).abs() > 1) {
      return true;
    }

    return current.startTime != next.startTime ||
        current.face != next.face ||
        current.message != next.message ||
        current.price != next.price ||
        current.userName != next.userName ||
        current.backgroundColor != next.backgroundColor ||
        current.backgroundBottomColor != next.backgroundBottomColor;
  }

  void _appendSuperChats(Iterable<LiveSuperChatMessage> items) {
    final now = DateTime.now();
    final added = <LiveSuperChatMessage>[];
    for (final item in items) {
      if (!item.endTime.isAfter(now)) {
        continue;
      }
      final fingerprint = _buildSuperChatFingerprint(item);
      final existingIndex = superChats.indexWhere(
        (existing) => _buildSuperChatFingerprint(existing) == fingerprint,
      );
      if (existingIndex >= 0) {
        if (_shouldUpdateSuperChat(superChats[existingIndex], item)) {
          superChats[existingIndex] = item;
        }
        continue;
      }
      if (_superChatFingerprints.add(fingerprint)) {
        added.add(item);
      }
    }
    if (added.isNotEmpty) {
      superChats.addAll(added);
    }
    _sortSuperChats();
  }

  void _sortSuperChats() {
    superChats.sort((a, b) => a.endTime.compareTo(b.endTime));
  }

  void _refreshSuperChatFingerprints() {
    _superChatFingerprints
      ..clear()
      ..addAll(superChats.map(_buildSuperChatFingerprint));
  }

  void _restartSuperChatRefreshTimer() {
    _superChatRefreshTimer?.cancel();
    if (site.id != Constant.kHuya || !liveStatus.value) {
      return;
    }
    _superChatRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      removeSuperChats();
      getSuperChatMessage(silent: true);
    });
  }

  void _clearSuperChatState() {
    superChats.clear();
    _superChatFingerprints.clear();
    _superChatRefreshTimer?.cancel();
    _superChatRefreshTimer = null;
  }

  /// 启动内存清理定时器（iOS 内存优化）
  void _startMemoryCleanupTimer() {
    _memoryCleanupTimer?.cancel();
    // 每分钟清理一次过期的 SuperChat
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      removeSuperChats(); // 清理过期 SC
      // 消息列表已经在添加时自动限制，这里再检查一次
      if (messages.length > 1000) {
        Log.d("内存清理：消息列表过大 (${messages.length})，清理到 500 条");
        messages.removeRange(0, messages.length - 500);
      }
    });
  }

  void _restartOnlineRefreshTimer() {
    _onlineRefreshTimer?.cancel();
    _onlineRefreshInFlight = false;
    _onlineStatusRefreshPolicy.reset();
    if (!liveStatus.value) {
      return;
    }
    final refreshGeneration = _loadGeneration;
    final refreshSiteId = site.id;
    final refreshRoomId = roomId;
    _onlineRefreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_onlineRefreshInFlight ||
          !_isCurrentLoad(refreshGeneration) ||
          site.id != refreshSiteId ||
          roomId != refreshRoomId ||
          !liveStatus.value) {
        return;
      }
      _onlineRefreshInFlight = true;
      try {
        final roomDetail = _sanitizeRoomDetail(
          await site.liveSite
              .getRoomDetail(roomId: refreshRoomId)
              .timeout(const Duration(seconds: 8)),
        );
        if (!_isCurrentLoad(refreshGeneration) ||
            site.id != refreshSiteId ||
            roomId != refreshRoomId) {
          return;
        }
        final reportedLive = roomDetail.status || roomDetail.isRecord;
        if (reportedLive) {
          _onlineStatusRefreshPolicy.reset();
          online.value = roomDetail.online;
          liveStatus.value = true;
          return;
        }
        final confirmedOffline = _onlineStatusRefreshPolicy.confirmOffline(
          reportedLive: false,
          hasActivePlaybackEvidence:
              player.state.playing || player.state.buffering,
        );
        if (!confirmedOffline) {
          Log.d(
            "刷新${site.name}状态暂未确认下播: "
            "${_onlineStatusRefreshPolicy.consecutiveOfflineCount}/"
            "${_onlineStatusRefreshPolicy.requiredOfflineConfirmations}",
          );
          return;
        }
        online.value = roomDetail.online;
        liveStatus.value = false;
        _onlineRefreshTimer?.cancel();
        _onlineRefreshTimer = null;
        _restartSuperChatRefreshTimer();
      } catch (e) {
        _onlineStatusRefreshPolicy.reset();
        Log.d("刷新${site.name}热度失败: $e");
      } finally {
        if (_isCurrentLoad(refreshGeneration)) {
          _onlineRefreshInFlight = false;
        }
      }
    });
  }

  void _refreshDanmakuOverlay(String reason) {
    if (!showDanmakuState.value) {
      return;
    }
    Log.d("$reason 后恢复弹幕覆盖层");
    danmakuController?.resume();
  }

  void _clearContributionRankState() {
    contributionRanks.clear();
    contributionRankFetched.value = false;
    contributionRankLoading.value = false;
    contributionRankError.value = null;
    contributionRankUpdatedAt.value = null;
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
      _liveEventFlowAggregator.clear();
      liveEventFlows.clear();
      return;
    }
    final text = _normalizeMessageText(msg.message);
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
      _liveEventFlowAggregator.clear();
      liveEventFlows.clear();
      return;
    }
    _ensureLiveEventFlowAggregatorSettings();
    final summaries = _liveEventFlowAggregator.preview(
      displayTtl: Duration(
        seconds: settings.effectiveLiveEventFlowDisplaySeconds,
      ),
    );
    liveEventFlows.assignAll(summaries);
    final limit = settings.liveEventFlowLimit.value;
    if (liveEventFlows.length > limit) {
      liveEventFlows.removeRange(limit, liveEventFlows.length);
    }
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

  Future<void> fetchContributionRank({bool forceRefresh = false}) async {
    if (!AppSettingsController.instance.contributionRankEnable.value ||
        !supportsContributionRank ||
        detail.value == null) {
      return;
    }
    if (contributionRankLoading.value) {
      return;
    }
    if (!forceRefresh &&
        contributionRanks.isNotEmpty &&
        contributionRankError.value == null) {
      return;
    }

    final requestSiteId = site.id;
    final requestRoomId = roomId;
    contributionRankLoading.value = true;
    contributionRankError.value = null;
    try {
      final ranks = await site.liveSite.getContributionRank(
        roomId: detail.value!.roomId,
        detail: detail.value,
      );
      if (site.id != requestSiteId || roomId != requestRoomId) {
        return;
      }
      contributionRanks.assignAll(ranks.map(_sanitizeContributionRankItem));
      contributionRankFetched.value = true;
      contributionRankUpdatedAt.value = DateTime.now();
    } catch (e) {
      Log.logPrint(e);
      if (site.id != requestSiteId || roomId != requestRoomId) {
        return;
      }
      contributionRankError.value = e.toString();
    } finally {
      if (site.id == requestSiteId && roomId == requestRoomId) {
        contributionRankLoading.value = false;
      }
    }
  }

  /// 初始化自动关闭计时器
  void initAutoExit() {
    final settings = AppSettingsController.instance;
    _cancelAutoExitTimers();
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
    Log.i("定时关闭已启用，将在${autoExitMinutes.value}分钟后关闭");
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
    Log.i("定时关闭（房间覆盖）已设置，将在${autoExitMinutes.value}分钟后关闭");
    _startAutoExitTicker();
  }

  void _cancelAutoExitTimers() {
    autoExitTimer?.cancel();
    autoExitTimer = null;
    _autoExitDeadlineTimer?.cancel();
    _autoExitDeadlineTimer = null;
  }

  void _scheduleAutoExitDeadline() {
    _autoExitDeadlineTimer?.cancel();
    _autoExitDeadlineTimer = null;
    if (!autoExitEnable.value || !_autoExitSession.enabled) {
      return;
    }
    final deadline = _autoExitSession.deadline;
    if (deadline == null) {
      return;
    }
    final delay =
        deadline.difference(DateTime.now()) + const Duration(milliseconds: 80);
    if (delay <= Duration.zero) {
      unawaited(_completeAutoExit());
      return;
    }
    _autoExitDeadlineTimer = Timer(delay, () {
      _autoExitDeadlineTimer = null;
      _refreshAutoExitCountdown();
    });
  }

  void _startAutoExitTicker() {
    _cancelAutoExitTimers();
    _autoExitCompleting = false;
    _refreshAutoExitCountdown();
    // Keep a 1s UI tick for the countdown label, and also schedule a one-shot
    // timer to the absolute deadline so a delayed periodic tick cannot miss it.
    autoExitTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshAutoExitCountdown(),
    );
    _scheduleAutoExitDeadline();
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
      return;
    }
    _scheduleAutoExitDeadline();
  }

  Future<void> _completeAutoExit() async {
    if (_autoExitCompleting || _roomDisposed) {
      return;
    }
    _autoExitCompleting = true;
    _cancelAutoExitTimers();
    _autoExitSession.stop();
    autoExitSource.value = AutoExitSource.none;
    autoExitEnable.value = false;
    countdown.value = 0;
    Log.i(
        "定时关闭到点：platform=${Platform.operatingSystem} room=${site.id}/$roomId");
    Log.i("定时关闭开始执行，准备关闭播放器和服务");
    await _runAutoExitStep("取消自动画中画", cancelAutoPipOnLeave);
    await _runAutoExitStep("停止后台播放服务", stopBackgroundPlaybackService);
    await _runAutoExitStep("停止弹幕", liveDanmaku.stop);
    await _runAutoExitStep("停止播放器", player.stop);
    await _runAutoExitStep("释放唤醒锁", WakelockPlus.disable);
    Log.i("定时关闭准备退出应用");
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
    if (Platform.isIOS) {
      await _runAutoExitStep("退出播放器窗口模式", () async {
        if (fullScreenState.value || smallWindowState.value) {
          await exitPlayerWindowMode();
        }
      });
      Get.offAllNamed(RoutePath.kIndex);
      return;
    }
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
    _cancelAutoExitTimers();
    _autoExitSession.stop();
    autoExitSource.value = AutoExitSource.none;
    _autoExitCompleting = false;
    countdown.value = 0;
  }

  Future<bool> syncAutoPipOnLeave() async {
    if (_autoPipAttempting) {
      return false;
    }
    if (!Platform.isAndroid ||
        !AppSettingsController.instance.autoPipOnExit.value ||
        !liveStatus.value) {
      if (Platform.isAndroid) {
        await cancelAutoPipOnLeave();
      }
      return false;
    }
    _autoPipAttempting = true;
    try {
      return await prepareAutoPipOnLeave();
    } catch (e) {
      Log.d("配置退后台自动小窗失败: $e");
      return false;
    } finally {
      _autoPipAttempting = false;
    }
  }
  // 页面刷新与重载逻辑

  void refreshRoom() {
    //messages.clear();
    _clearDanmuDedupeState();
    _clearSuperChatState();
    _clearContributionRankState();
    clearLiveEventFlow();
    liveDanmaku.stop();
    if (detail.value != null) {
      getSuperChatMessage();
    }

    loadData();
  }

  @override
  void onPlayerWindowModeExited() {
    clearTransientPlayerOverlays();
    forceChatScrollToBottom(delay: const Duration(milliseconds: 120));
  }

  @override
  void onClose() async {
    _roomDisposed = true;
    clearTransientPlayerOverlays();
    _loadGeneration += 1;
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    unawaited(cancelAutoPipOnLeave());
    CurrentRoomService.instance.clearRoom();
    scrollController.removeListener(scrollListener);
    liveRoomFollowScrollController.dispose();
    liveRoomFollowDialogScrollController.dispose();
    liveRoomHistoryScrollController.dispose();
    liveRoomRecommendationScrollController.dispose();
    _cancelAutoExitTimers();
    _autoExitSession.stop();
    _superChatRefreshTimer?.cancel();
    _liveEventFlowTimer?.cancel();
    _onlineRefreshTimer?.cancel();
    _onlineStatusRefreshPolicy.reset();
    _chatBottomRestoreTimer?.cancel();
    _memoryCleanupTimer?.cancel(); // 取消内存清理定时器
    _cancelPendingDanmakuTimers();
    clearDanmakuReplayHistory();
    _liveDurationTimer?.cancel();
    _positionSubscription?.cancel();
    unawaited(
      AppSettingsController.instance.setLastLiveRoomResumePending(false),
    );
    await _waitForPlayerReopen();
    if (!isPlayerClosing) {
      await player.stop();
    }
    await liveDanmaku.stop();
    LiveSubtitleService.instance.stop();
    super.onClose();
  }

  /// 聊天列表滚动到底部
  void chatScrollToBottom() {
    if (scrollController.hasClients) {
      // 用户手动上拉过时，不再自动滚到底部。
      if (disableAutoScroll.value) {
        return;
      }
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  void forceChatScrollToBottom({Duration delay = Duration.zero}) {
    _chatBottomRestoreTimer?.cancel();
    _chatBottomRestoreTimer = Timer(delay, () {
      disableAutoScroll.value = false;
      if (!scrollController.hasClients) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) {
          return;
        }
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
    });
  }

  /// 初始化弹幕连接回调
  void initDanmau() {
    liveDanmaku.onMessage = onWSMessage;
    liveDanmaku.onClose = onWSClose;
    liveDanmaku.onReady = onWSReady;
  }

  /// 接收 WebSocket 消息
  void onWSMessage(LiveMessage msg) {
    msg = _sanitizeLiveMessage(msg);
    if (msg.type == LiveMessageType.chat) {
      if (messages.length > 200 && !disableAutoScroll.value) {
        messages.removeAt(0);
      }
      if (_isUserShielded(msg.userName) || isTempMutedUser(msg.userName)) {
        Log.d("已过滤被屏蔽用户: ${msg.userName}");
        return;
      }

      if (_isKeywordShielded(msg)) {
        return;
      }

      _recordLiveEventFlow(msg);

      if (_isDuplicateDanmu(msg)) {
        return;
      }

      messages.add(msg);

      // 限制消息列表大小，防止内存溢出（特别是 iOS）
      if (messages.length > 1000) {
        messages.removeRange(0, 500); // 保留最近 500 条
      }

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chatScrollToBottom(),
      );
      if (!liveStatus.value || (isBackground && !_allowBackgroundPlayback)) {
        return;
      }
      _scheduleOverlayDanmaku(msg);
      return;
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      if (msg.data is! LiveSuperChatMessage) {
        return;
      }
      final superChat =
          _sanitizeSuperChatMessage(msg.data as LiveSuperChatMessage);
      if (_isUserShielded(superChat.userName) ||
          isTempMutedUser(superChat.userName)) {
        return;
      }
      if (_isKeywordShielded(_superChatToLiveMessage(superChat))) {
        return;
      }
      _appendSuperChats([superChat]);

      // SC 全屏滚动显示
      if (AppSettingsController.instance.superChatScrollInFullscreen.value &&
          fullScreenState.value) {
        // 格式化为：【头条】用户名：内容
        final formattedMessage = "【头条】${superChat.userName}：${superChat.message}";
        final scDanmakuMsg = LiveMessage(
          type: LiveMessageType.chat,
          userName: superChat.userName,
          message: formattedMessage,
          color: LiveMessageColor(255, 215, 0), // 金黄色，醒目
        );

        // 添加到消息列表（聊天区显示）
        messages.add(scDanmakuMsg);

        // 限制消息列表大小
        if (messages.length > 1000) {
          messages.removeRange(0, 500);
        }

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => chatScrollToBottom(),
        );

        // 如果当前在播放且不在后台，显示为滚动弹幕
        if (liveStatus.value && !isBackground) {
          _scheduleOverlayDanmaku(scDanmakuMsg);
        }
      }

      return;
    }
  }

  /// 添加一条系统消息
  void addSysMsg(String msg) {
    messages.add(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: _normalizeMessageText(msg),
        color: LiveMessageColor.white,
      ),
    );
  }

  /// 接收 WebSocket 关闭消息
  void onWSClose(String msg) {
    addSysMsg(msg);
  }

  /// WebSocket 已连接完成
  void onWSReady() {
    addSysMsg("弹幕服务器连接成功");
  }

  /// 加载直播间信息
  void loadData() async {
    final loadGeneration = ++_loadGeneration;
    final targetSite = site;
    final targetRoomId = roomId;
    final loadStopwatch = Stopwatch()..start();
    _dismissLiveRoomLoadingOverlay();
    try {
      loadError.value = false;
      error = null;
      errorStackTrace = null;
      update();
      await liveDanmaku.stop();
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }
      liveDanmaku = targetSite.liveSite.getDanmaku();
      _clearContributionRankState();
      _clearSuperChatState();
      _cancelPendingDanmakuTimers();
      clearDanmakuReplayHistory();
      rebuildDanmakuView();
      addSysMsg("正在读取直播间信息");
      final detailStopwatch = Stopwatch()..start();
      final loadedDetail = _sanitizeRoomDetail(
        await targetSite.liveSite.getRoomDetail(roomId: targetRoomId),
      );
      detailStopwatch.stop();
      Log.i(
        "读取直播间信息完成：${targetSite.id}/$targetRoomId ${detailStopwatch.elapsedMilliseconds}ms",
      );
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }
      detail.value = loadedDetail;

      if (site.id == Constant.kDouyin) {
        // 1.6.0 之前收藏的是 WebRid，中间一版收藏的是 RoomID，
        // 这里统一修正回当前实际 roomId。
        if (detail.value!.roomId != roomId) {
          var oldId = roomId;
          final resolvedRoomId = detail.value!.roomId;
          rxRoomId.value = detail.value!.roomId;
          if (followed.value) {
            // 同步修正已关注房间的主键
            DBService.instance.deleteFollow("${site.id}_$oldId");
            DBService.instance.addFollow(
              FollowUser(
                id: "${site.id}_$resolvedRoomId",
                roomId: resolvedRoomId,
                siteId: site.id,
                userName: detail.value!.userName,
                face: detail.value!.userAvatar,
                addTime: DateTime.now(),
              ),
            );
          } else {
            followed.value = DBService.instance.getFollowExist(
              "${site.id}_$resolvedRoomId",
            );
          }
        }
      }
      unawaited(
        AppSettingsController.instance.saveLastLiveRoom(
          siteId: site.id,
          roomId: roomId,
        ),
      );

      getSuperChatMessage();
      if (AppSettingsController.instance.contributionRankEnable.value) {
        fetchContributionRank();
      }
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }

      addHistory();
      // 刷新关注状态
      followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      _restartSuperChatRefreshTimer();
      _restartOnlineRefreshTimer();
      unawaited(syncAutoPipOnLeave());
      if (liveStatus.value) {
        getPlayQualites();
      }
      if (detail.value!.isRecord) {
        addSysMsg("当前主播未开播，正在转播录像");
      }
      addSysMsg("正在连接弹幕服务器");
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }
      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
      startLiveDurationTimer();
    } catch (e, stackTrace) {
      Log.logPrint(e);
      //SmartDialog.showToast(e.toString());
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }
      loadError.value = true;
      error = e;
      errorStackTrace = stackTrace;
    } finally {
      if (_isCurrentLoad(loadGeneration)) {
        _dismissLiveRoomLoadingOverlay();
      }
      loadStopwatch.stop();
      Log.i(
        "直播间加载流程结束：${targetSite.id}/$targetRoomId ${loadStopwatch.elapsedMilliseconds}ms",
      );
    }
  }

  void _dismissLiveRoomLoadingOverlay() {
    unawaited(SmartDialog.dismiss(status: SmartStatus.loading));
  }

  bool _isCurrentLoad(int loadGeneration) {
    return !_roomDisposed && loadGeneration == _loadGeneration;
  }

  /// 读取可用清晰度并选择默认值
  Future<void> getPlayQualites() async {
    final loadGeneration = _loadGeneration;
    final roomDetail = detail.value;
    if (roomDetail == null || !_isCurrentLoad(loadGeneration)) {
      return;
    }
    qualites.clear();
    currentQuality = -1;

    try {
      var playQualites =
          await site.liveSite.getPlayQualites(detail: roomDetail);
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }

      if (playQualites.isEmpty) {
        final qualityError = CoreError("无法读取播放清晰度，请稍后重试");
        Log.e(
          "播放清晰度列表为空：${site.id}/$roomId generation=$loadGeneration",
          StackTrace.current,
        );
        loadError.value = true;
        error = qualityError;
        errorStackTrace = StackTrace.current;
        return;
      }
      var qualityLevel = await getQualityLevel();
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }
      qualites.value = playQualites;
      if (qualityLevel == 2) {
        // 最高
        currentQuality = 0;
      } else if (qualityLevel == 0) {
        // 最低
        currentQuality = playQualites.length - 1;
      } else {
        // 中间档
        int middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }

      await getPlayUrl();
    } catch (e, stackTrace) {
      if (!_isCurrentLoad(loadGeneration)) {
        return;
      }
      Log.e(
        "读取播放清晰度失败：${site.id}/$roomId generation=$loadGeneration error=$e",
        stackTrace,
      );
      loadError.value = true;
      error = e;
      errorStackTrace = stackTrace;
    }
  }

  Future<int> getQualityLevel() async {
    var qualityLevel = AppSettingsController.instance.qualityLevel.value;
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.first == ConnectivityResult.mobile) {
        qualityLevel =
            AppSettingsController.instance.qualityLevelCellular.value;
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return qualityLevel;
  }

  Future<bool> _reloadPlayUrls(
      {bool resetLine = false, bool silent = false}) async {
    final loadGeneration = _loadGeneration;
    if (_roomDisposed) {
      return false;
    }
    if (detail.value == null ||
        currentQuality < 0 ||
        currentQuality >= qualites.length) {
      return false;
    }
    currentQualityInfo.value = qualites[currentQuality].quality;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (!_isCurrentLoad(loadGeneration)) {
      return false;
    }
    if (playUrl.urls.isEmpty) {
      if (!silent) {
        SmartDialog.showToast("无法读取播放地址");
      }
      return false;
    }
    playUrls.value = playUrl.urls;
    playHeaders = playUrl.headers;
    if (resetLine || currentLineIndex < 0) {
      currentLineIndex = 0;
    } else if (currentLineIndex >= playUrls.length) {
      currentLineIndex = playUrls.length - 1;
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    return true;
  }

  Future<void> getPlayUrl() async {
    final loadGeneration = _loadGeneration;
    playUrls.clear();
    currentLineInfo.value = "";
    currentLineIndex = -1;
    if (!await _reloadPlayUrls(resetLine: true)) {
      return;
    }
    if (!_isCurrentLoad(loadGeneration)) {
      return;
    }
    // 重置播放器错误重试次数
    mediaErrorRetryCount = 0;
    await initPlaylist();
  }

  Future<void> changePlayLine(int index) async {
    currentLineIndex = index;
    // 切线时同样重置重试次数
    mediaErrorRetryCount = 0;
    await setPlayer();
  }

  Future<void> initPlaylist() async {
    final loadGeneration = _loadGeneration;
    if (_roomDisposed ||
        currentLineIndex < 0 ||
        currentLineIndex >= playUrls.length) {
      return;
    }

    // A room switch may leave an old open() in flight. Wait for that operation
    // to finish before opening the new room, otherwise its stale completion can
    // stop the new media or prevent the new room from starting at all.
    while (true) {
      if (!_isCurrentLoad(loadGeneration) ||
          currentLineIndex < 0 ||
          currentLineIndex >= playUrls.length) {
        return;
      }
      final reopening = _playerReopeningFuture;
      if (reopening == null) {
        break;
      }
      if (_playerReopeningGeneration == loadGeneration) {
        return;
      }
      try {
        await reopening;
      } catch (e, stackTrace) {
        Log.e("等待旧播放器打开完成失败: $e", stackTrace);
      }
    }

    if (!_isCurrentLoad(loadGeneration) ||
        currentLineIndex < 0 ||
        currentLineIndex >= playUrls.length) {
      return;
    }
    final reopening = _openPlaylist(loadGeneration);
    _playerReopeningGeneration = loadGeneration;
    _playerReopeningFuture = reopening;
    try {
      await reopening;
    } finally {
      if (identical(_playerReopeningFuture, reopening)) {
        _playerReopeningFuture = null;
        _playerReopeningGeneration = null;
      }
    }
  }

  Future<void> _openPlaylist(int loadGeneration) async {
    final mediaGeneration = ++_playbackMediaGeneration;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    var finalUrl = playUrls[currentLineIndex];
    if (AppSettingsController.instance.playerForceHttps.value) {
      finalUrl = finalUrl.replaceAll("http://", "https://");
    }

    final previousWidth = player.state.width;
    final previousHeight = player.state.height;
    final wasPlaying = player.state.playing;
    Log.i(
      "准备打开播放器：target=${site.id}/$roomId "
      "quality=${currentQualityInfo.value} line=${currentLineIndex + 1}/${playUrls.length} "
      "previousPlaying=$wasPlaying previousSize=${previousWidth}x$previousHeight "
      "${MpvOptionsService.diagnosticsSummary()}",
    );

    // 重新初始化播放器，并带上当前线路的请求头。
    final openStopwatch = Stopwatch()..start();
    await initializePlayer();
    if (!_isCurrentLoad(loadGeneration)) {
      return;
    }

    await _stopDesktopPlayerBeforeOpen();
    if (!_isCurrentLoad(loadGeneration)) {
      return;
    }

    final opened = await openPlaybackMedia(
      Media(
        finalUrl,
        httpHeaders: playHeaders,
      ),
      loadGeneration: loadGeneration,
      mediaGeneration: mediaGeneration,
    );
    if (!opened) {
      return;
    }
    openStopwatch.stop();
    Log.i(
      "播放器打开完成：${site.id}/$roomId ${openStopwatch.elapsedMilliseconds}ms "
      "line=${currentLineIndex + 1}/${playUrls.length} "
      "size=${player.state.width}x${player.state.height}",
    );
    unawaited(
      LiveSubtitleService.instance.syncPreviewFromSettings(
        mediaUrl: finalUrl,
        httpHeaders: playHeaders,
      ),
    );
    Log.d("播放链接\n$finalUrl");
  }

  Future<void> _waitForPlayerReopen() async {
    final reopening = _playerReopeningFuture;
    if (reopening != null) {
      try {
        await reopening;
      } catch (e, stackTrace) {
        Log.e("等待播放器打开完成失败: $e", stackTrace);
      }
    }
    await waitForPlaybackOpen();
  }

  Future<void> _stopDesktopPlayerBeforeOpen() async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }
    if (!player.state.playing && player.state.playlist.medias.isEmpty) {
      return;
    }
    try {
      await player.stop();
      await Future.delayed(const Duration(milliseconds: 120));
    } catch (e, stackTrace) {
      Log.e("切换直播间前停止旧播放失败: $e", stackTrace);
    }
  }

  Future<void> setPlayer({bool refreshUrls = false}) async {
    if (refreshUrls) {
      var reloaded = await _reloadPlayUrls(silent: true);
      if (!reloaded) {
        return;
      }
    }
    await initPlaylist();
  }

  bool get _shouldRefreshUrlsOnPlaybackRetry =>
      site.id == Constant.kHuya || site.id == Constant.kDouyu;

  bool _isPlaybackEventCurrent(int loadGeneration, int mediaGeneration) {
    return _isCurrentLoad(loadGeneration) &&
        mediaGeneration == _playbackMediaGeneration;
  }

  @override
  void mediaEnd() async {
    final loadGeneration = _loadGeneration;
    final mediaGeneration = _playbackMediaGeneration;
    if (!_isPlaybackEventCurrent(loadGeneration, mediaGeneration)) {
      return;
    }
    super.mediaEnd();
    if (mediaErrorRetryCount < 2) {
      Log.d("播放结束，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        // 第二次重试前稍等一秒
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!_isPlaybackEventCurrent(loadGeneration, mediaGeneration)) {
        return;
      }
      mediaErrorRetryCount += 1;
      await setPlayer(refreshUrls: _shouldRefreshUrlsOnPlaybackRetry);
      return;
    }

    Log.d("播放结束");
    // 依次尝试剩余线路，全部失败后再判定为已下播。
    if (playUrls.length - 1 == currentLineIndex) {
      if (site.id == Constant.kHuya) {
        currentLineIndex = 0;
        mediaErrorRetryCount = 0;
        await setPlayer(refreshUrls: true);
        return;
      }
      liveStatus.value = false;
      await _tryAutoSwitchToNextLiveRoom(reason: "live_end");
    } else {
      await changePlayLine(currentLineIndex + 1);

      //setPlayer();
    }
  }

  int mediaErrorRetryCount = 0;
  @override
  void mediaError(String error) async {
    final loadGeneration = _loadGeneration;
    final mediaGeneration = _playbackMediaGeneration;
    if (!_isPlaybackEventCurrent(loadGeneration, mediaGeneration)) {
      return;
    }
    super.mediaError(error);
    if (mediaErrorRetryCount < 2) {
      Log.d("播放失败，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        // 第二次重试前稍等一秒
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!_isPlaybackEventCurrent(loadGeneration, mediaGeneration)) {
        return;
      }
      mediaErrorRetryCount += 1;
      await setPlayer(refreshUrls: _shouldRefreshUrlsOnPlaybackRetry);
      return;
    }

    if (playUrls.length - 1 == currentLineIndex) {
      if (site.id == Constant.kHuya) {
        currentLineIndex = 0;
        mediaErrorRetryCount = 0;
        await setPlayer(refreshUrls: true);
        return;
      }
      errorMsg.value = "播放失败";
      SmartDialog.showToast("播放失败: $error");
      await _tryAutoSwitchToNextLiveRoom(reason: "playback_failure");
    } else {
      //currentLineIndex += 1;
      //setPlayer();
      await changePlayLine(currentLineIndex + 1);
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

    final liveChannels = FollowService.instance.sortFollowUsers(
      FollowService.instance.liveList,
    );
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

  @override
  void refreshPlayback() {
    // 手动刷新，直接触发错误恢复流程
    mediaError("用户手动刷新");
  }

  /// 读取头条 / SC
  void getSuperChatMessage({bool silent = false}) async {
    if (detail.value == null) {
      return;
    }
    try {
      var sc = await site.liveSite.getSuperChatMessage(
        roomId: detail.value!.roomId,
        detail: detail.value,
      );
      final filtered = sc.map(_sanitizeSuperChatMessage).where((item) {
        if (_isUserShielded(item.userName) || isTempMutedUser(item.userName)) {
          return false;
        }
        return !_isKeywordShielded(_superChatToLiveMessage(item));
      });
      _appendSuperChats(filtered);
      removeSuperChats();
    } catch (e) {
      Log.logPrint(e);
      if (silent) {
        return;
      }
      addSysMsg("SC 读取失败");
    }
  }

  /// 移除已经过期的头条 / SC
  void removeSuperChats() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    superChats.value = superChats
        .where((x) => x.endTime.millisecondsSinceEpoch > now)
        .toList();
    _sortSuperChats();
    _refreshSuperChatFingerprints();
  }

  /// 娣诲姞鍘嗗彶璁板綍
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
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  /// 取消关注当前主播
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    if (!await Utils.showAlertDialog(
      "确定要取消关注这位主播吗？",
      title: "取消关注",
    )) {
      return;
    }

    var id = "${site.id}_$roomId";
    DBService.instance.deleteFollow(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  void share() {
    if (detail.value == null) {
      return;
    }
    final url = detail.value!.url;
    if (Platform.isWindows) {
      Utils.copyToClipboard(url);
      return;
    }
    SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));
  }

  void copyUrl() {
    if (detail.value == null) {
      return;
    }
    Utils.copyToClipboard(detail.value!.url);
    SmartDialog.showToast("已复制直播间链接");
  }

  /// 复制当前生成的播放直链
  void copyPlayUrl() async {
    // 未开播时不复制
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

  /// 底部弹出弹幕设置
  void showDanmuSettingsSheet() {
    Utils.showBottomSheet(
      title: "弹幕设置",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmuSettingsView(
            danmakuController: danmakuController,
            siteId: site.id,
            previewViewportHeight: danmakuViewportHeight.value,
            onTapDanmuShield: () {
              Get.back();
              showDanmuShield();
            },
          ),
        ],
      ),
    );
  }

  void showLiveSettingsSheet() {
    final settings = AppSettingsController.instance;
    Utils.showBottomSheet(
      title: "直播设置",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: "硬件解码",
                    subtitle: "播放失败可尝试关闭此选项",
                    value: settings.hardwareDecode.value,
                    onChanged: settings.setHardwareDecode,
                  ),
                ),
                if (Platform.isAndroid) ...[
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: "兼容模式",
                      subtitle: "若播放卡顿可尝试打开此选项",
                      value: settings.playerCompatMode.value,
                      onChanged: settings.setPlayerCompatMode,
                    ),
                  ),
                ],
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "后台播放",
                    subtitle: "移动端仍可能被系统省电策略关闭",
                    value: settings.allowBackgroundPlayback.value,
                    onChanged: settings.setAllowBackgroundPlayback,
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: "强制 HTTPS",
                    subtitle: "将 http 播放链接替换为 https",
                    value: settings.playerForceHttps.value,
                    onChanged: settings.setPlayerForceHttps,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _cancelVolumeSliderDismiss() {
    hidevolumeTimer?.cancel();
    hidevolumeTimer = null;
  }

  void _scheduleVolumeSliderDismiss(Duration delay) {
    _cancelVolumeSliderDismiss();
    hidevolumeTimer = Timer(delay, () {
      hidevolumeTimer = null;
      _volumeSliderPointerEntered = false;
      volumeSliderVisible = false;
      SmartDialog.dismiss(tag: volumeSliderDialogTag);
    });
  }

  void showVolumeSlider(
    BuildContext targetContext, {
    bool keepAlive = false,
  }) {
    // The attach dialog uses a full-screen mask. Keep the player controls from
    // treating that mask transition as a pointer exit and dismissing the
    // slider immediately after it opens.
    hideControlsTimer?.cancel();
    hideControlsTimer = null;
    _cancelVolumeSliderDismiss();
    volumeSliderVisible = true;
    _volumeSliderPointerEntered = false;
    _scheduleVolumeSliderDismiss(
      keepAlive ? const Duration(seconds: 6) : const Duration(seconds: 4),
    );
    SmartDialog.showAttach(
      targetContext: targetContext,
      alignment: Alignment.topCenter,
      displayTime: null,
      maskColor: const Color(0x00000000),
      clickMaskDismiss: false,
      usePenetrate: true,
      useAnimation: false,
      tag: volumeSliderDialogTag,
      keepSingle: true,
      builder: (context) {
        return MouseRegion(
          onEnter: (_) {
            _volumeSliderPointerEntered = true;
            _cancelVolumeSliderDismiss();
          },
          onExit: (_) => hideVolumeSlider(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppStyle.radius12,
              color: Theme.of(context).cardColor,
            ),
            padding: AppStyle.edgeInsetsA4,
            child: Obx(
              () => SizedBox(
                width: 200,
                child: Slider(
                  min: 0,
                  max: 100,
                  value: AppSettingsController.instance.playerVolume.value,
                  onChangeStart: (_) => _cancelVolumeSliderDismiss(),
                  onChanged: (newValue) {
                    setSessionPlayerVolume(newValue, persist: true);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void hideVolumeSlider() {
    if (!_volumeSliderPointerEntered) {
      return;
    }
    _scheduleVolumeSliderDismiss(const Duration(milliseconds: 600));
  }

  void showQualitySheet() {
    Utils.showBottomSheet(
      title: "切换清晰度",
      child: RadioGroup(
        groupValue: currentQuality,
        onChanged: (e) {
          Get.back();
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
      title: "线路选择",
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
    Get.toNamed(RoutePath.kSettingsDanmuShield);
  }

  LiveSubCategory? _buildRecommendationCategory() {
    final roomDetail = detail.value;
    if (roomDetail == null) {
      return null;
    }
    final categoryId = (roomDetail.categoryId ?? "").trim();
    final categoryName = (roomDetail.categoryName ?? "").trim();
    final parentId = (roomDetail.categoryParentId ?? "").trim();
    final parentName = (roomDetail.categoryParentName ?? "").trim();
    if (categoryId.isEmpty && parentId.isEmpty) {
      return null;
    }
    final resolvedId = categoryId.isNotEmpty ? categoryId : parentId;
    final resolvedParentId = parentId.isNotEmpty ? parentId : resolvedId;
    final resolvedName = categoryName.isNotEmpty
        ? categoryName
        : parentName.isNotEmpty
            ? parentName
            : roomDetail.title.trim();
    if (resolvedId.isEmpty || resolvedName.isEmpty) {
      return null;
    }
    final pic = roomDetail.categoryPic?.trim();
    return LiveSubCategory(
      id: resolvedId,
      name: resolvedName,
      parentId: resolvedParentId,
      pic: pic == null || pic.isEmpty ? null : pic,
    );
  }

  bool get hasCategoryRecommendation => _buildRecommendationCategory() != null;

  String get currentRecommendationSubtitle {
    final roomDetail = detail.value;
    final category = _buildRecommendationCategory();
    if (roomDetail == null || category == null) {
      return "当前直播间暂时还没有可用的分区标签";
    }
    final parentName = (roomDetail.categoryParentName ?? "").trim();
    if (parentName.isNotEmpty && parentName != category.name) {
      return "${site.name} / $parentName / ${category.name}";
    }
    return "${site.name} / ${category.name}";
  }

  bool get useFullscreenSidePanelMenus =>
      fullScreenState.value && (Platform.isAndroid || Platform.isIOS);

  List<String> get enabledQuickAccessKeys {
    final settings = AppSettingsController.instance;
    return settings.liveRoomQuickAccessSort
        .where((key) =>
            settings.liveRoomQuickAccessEnabled.contains(key) &&
            Constant.allLiveRoomQuickAccess.containsKey(key) &&
            (key != "contribution_rank" ||
                (supportsContributionRank &&
                    settings.contributionRankEnable.value)))
        .toList();
  }

  String quickAccessTitle(String key) {
    if (key == "contribution_rank") {
      return site.id == Constant.kDouyu ? "亲密榜" : "贡献榜";
    }
    return Constant.allLiveRoomQuickAccess[key]?.title ?? "";
  }

  String quickAccessSubtitle(String key) {
    if (key == "recommendation") {
      return currentRecommendationSubtitle;
    }
    if (key == "contribution_rank") {
      if (!supportsContributionRank) {
        return "当前平台暂无贡献榜";
      }
      return site.id == Constant.kDouyu ? "打开当前直播间亲密榜" : "打开当前直播间贡献榜";
    }
    return Constant.allLiveRoomQuickAccess[key]?.subtitle ?? "";
  }

  void showContributionRankSheet() {
    if (!supportsContributionRank) {
      return;
    }
    if (!AppSettingsController.instance.contributionRankEnable.value) {
      return;
    }
    fetchContributionRank(forceRefresh: true);
    Utils.showBottomSheet(
      title: site.id == Constant.kDouyu ? "亲密榜" : "贡献榜",
      child: SizedBox(
        height: Get.height * 0.75,
        child: LiveContributionRankPanel(controller: this),
      ),
    );
  }

  Widget buildHistorySelection({
    required VoidCallback onClose,
    ScrollController? scrollController,
  }) {
    final currentSite = site;
    final histories = <History>[].obs;
    final loading = true.obs;

    Future<void> loadHistory() async {
      loading.value = true;
      try {
        histories.value = DBService.instance.getHistores();
      } finally {
        loading.value = false;
      }
    }

    unawaited(loadHistory());

    return Obx(() {
      if (loading.value && histories.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (histories.isEmpty) {
        return AppEmptyWidget(
          message: "暂无观看历史",
          onRefresh: loadHistory,
        );
      }
      return RefreshIndicator(
        onRefresh: loadHistory,
        child: ListView.separated(
          key: const PageStorageKey<String>("liveRoomHistorySelection"),
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppStyle.edgeInsetsA12,
          itemCount: histories.length,
          separatorBuilder: (_, __) => AppStyle.divider,
          itemBuilder: (_, i) {
            final item = histories[i];
            final historySite = Sites.allSites[item.siteId];
            final isCurrent =
                currentSite.id == item.siteId && roomId == item.roomId;
            return Material(
              color: Colors.transparent,
              child: ListTile(
                selected: isCurrent,
                contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 8),
                leading: NetImage(
                  item.face,
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                ),
                title: Text(
                  item.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    if (historySite != null) ...[
                      Image.asset(
                        historySite.logo,
                        width: 20,
                      ),
                      AppStyle.hGap4,
                    ],
                    Expanded(
                      child: Text(
                        historySite?.name ?? item.siteId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    AppStyle.hGap8,
                    Text(
                      Utils.parseTime(item.updateTime),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                onTap: historySite == null
                    ? null
                    : () {
                        onClose();
                        resetRoom(historySite, item.roomId);
                      },
                onLongPress: () async {
                  final confirmed = await Utils.showAlertDialog(
                    "确定要删除此记录吗?",
                    title: "删除记录",
                  );
                  if (!confirmed) {
                    return;
                  }
                  await DBService.instance.historyBox.delete(item.id);
                  await loadHistory();
                },
              ),
            );
          },
        ),
      );
    });
  }

  Widget buildCategoryRecommendationSelection({
    required VoidCallback onClose,
    ScrollController? scrollController,
  }) {
    final currentSite = site;
    final currentRoomId = roomId;
    final category = _buildRecommendationCategory();
    if (category == null) {
      return const AppEmptyWidget(
        message: "当前直播间暂无同类推荐内容",
      );
    }

    final rooms = <LiveRoomItem>[].obs;
    final loading = true.obs;
    final page = 1.obs;
    final hasMore = true.obs;

    Future<void> loadRecommendations({bool refresh = false}) async {
      if (loading.value && !refresh) {
        return;
      }
      loading.value = true;
      try {
        final targetPage = refresh ? 1 : page.value;
        final result = await site.liveSite.getCategoryRooms(
          category,
          page: targetPage,
        );
        final fetched =
            result.items.where((item) => item.roomId != roomId).toList();
        if (refresh) {
          rooms.assignAll(fetched);
          page.value = 2;
        } else {
          final existingRoomIds = rooms.map((item) => item.roomId).toSet();
          rooms.addAll(
            fetched.where((item) => !existingRoomIds.contains(item.roomId)),
          );
          page.value = targetPage + 1;
        }
        hasMore.value = fetched.isNotEmpty;
      } catch (e) {
        if (rooms.isEmpty) {
          SmartDialog.showToast("加载同类推荐失败: ${exceptionToString(e)}");
        } else {
          handleError(e);
        }
      } finally {
        loading.value = false;
      }
    }

    unawaited(loadRecommendations(refresh: true));

    return Obx(() {
      if (loading.value && rooms.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (rooms.isEmpty) {
        return AppEmptyWidget(
          message: "当前分区暂无可用推荐",
          onRefresh: () => loadRecommendations(refresh: true),
        );
      }
      return RefreshIndicator(
        onRefresh: () => loadRecommendations(refresh: true),
        child: ListView.builder(
          key: const PageStorageKey<String>(
            "liveRoomCategoryRecommendationSelection",
          ),
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppStyle.edgeInsetsA12,
          itemCount: rooms.length + 2,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: AppStyle.edgeInsetsB12,
                child: Text(
                  currentRecommendationSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              );
            }
            if (i == rooms.length + 1) {
              if (loading.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!hasMore.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      "已经到底了",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextButton.icon(
                  onPressed: () => loadRecommendations(),
                  icon: const Icon(Icons.expand_more),
                  label: const Text("加载更多"),
                ),
              );
            }

            final item = rooms[i - 1];
            final isCurrent =
                currentSite.id == site.id && currentRoomId == item.roomId;
            return Padding(
              padding: EdgeInsets.only(bottom: i == rooms.length ? 0 : 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    onClose();
                    resetRoom(site, item.roomId);
                  },
                  child: Ink(
                    padding: AppStyle.edgeInsetsA8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isCurrent
                          ? Get.theme.colorScheme.primary.withAlpha(25)
                          : Get.theme.cardColor,
                      border: Border.all(
                        color: isCurrent
                            ? Get.theme.colorScheme.primary.withAlpha(120)
                            : Colors.grey.withAlpha(25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: NetImage(
                            item.cover,
                            width: 108,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        AppStyle.hGap12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              AppStyle.vGap4,
                              Text(
                                item.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              AppStyle.vGap4,
                              Text(
                                "热度 ${Utils.onlineToString(item.online)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  void openHistoryPage() {
    if (useFullscreenSidePanelMenus) {
      Utils.showRightDialog(
        title: "观看历史",
        width: 420,
        useSystem: true,
        child: buildHistorySelection(
          onClose: Utils.hideRightDialog,
          scrollController: liveRoomHistoryScrollController,
        ),
      );
      return;
    }
    AppNavigator.toHistory(
      onRoomSelected: (selectedSite, selectedRoomId) {
        resetRoom(selectedSite, selectedRoomId);
      },
    );
  }

  void openCategoryRecommendation() {
    final category = _buildRecommendationCategory();
    if (category == null) {
      SmartDialog.showToast("当前直播间还没有可用的分区标签");
      return;
    }
    if (useFullscreenSidePanelMenus) {
      Utils.showRightDialog(
        title: "同类推荐",
        width: 420,
        useSystem: true,
        child: buildCategoryRecommendationSelection(
          onClose: Utils.hideRightDialog,
          scrollController: liveRoomRecommendationScrollController,
        ),
      );
      return;
    }
    AppNavigator.toCategoryDetail(
      site: site,
      category: category,
      excludedRoomId: roomId,
      onRoomSelected: (selectedSite, selectedRoomId) {
        resetRoom(selectedSite, selectedRoomId);
      },
    );
  }

  void showQuickAccessSheet() {
    final keys = enabledQuickAccessKeys;
    Utils.showBottomSheet(
      title: "快捷入口",
      child: ListView(
        children: keys.map((key) {
          final item = Constant.allLiveRoomQuickAccess[key]!;
          final enabled = key != "recommendation" || hasCategoryRecommendation;
          return ListTile(
            leading: Icon(item.iconData),
            title: Text(quickAccessTitle(key)),
            subtitle: Text(quickAccessSubtitle(key)),
            enabled: enabled,
            onTap: !enabled
                ? null
                : () {
                    Get.back();
                    switch (key) {
                      case "follow":
                        showFollowUserSheet();
                        break;
                      case "history":
                        openHistoryPage();
                        break;
                      case "recommendation":
                        openCategoryRecommendation();
                        break;
                      case "contribution_rank":
                        showContributionRankSheet();
                        break;
                    }
                  },
          );
        }).toList(),
      ),
    );
  }

  List<FollowUser> _followUsersByFilterMode(int filterMode) {
    switch (filterMode) {
      case 1:
        return FollowService.instance.sortFollowUsers(
          FollowService.instance.liveList,
        );
      case 2:
        return FollowService.instance.sortFollowUsers(
          FollowService.instance.notLiveList,
        );
      default:
        return FollowService.instance.sortFollowUsers(
          FollowService.instance.followList,
        );
    }
  }

  Widget buildFollowUserSelection({
    required VoidCallback onClose,
    ScrollController? scrollController,
  }) {
    const options = ["全部", "直播中", "未开播"];
    return Obx(() {
      final filterMode = liveRoomFollowFilterMode.value;
      final followUsers = _followUsersByFilterMode(filterMode);
      return Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: AppStyle.edgeInsetsA12.copyWith(bottom: 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(options.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == options.length - 1 ? 0 : 12,
                        ),
                        child: FilterButton(
                          text: options[index],
                          selected: filterMode == index,
                          onTap: () {
                            liveRoomFollowFilterMode.value = index;
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: FollowService.instance.loadData,
                  child: ListView.builder(
                    key: const PageStorageKey<String>(
                      "liveRoomFollowUserSelection",
                    ),
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppStyle.edgeInsetsV8,
                    itemCount: followUsers.length,
                    itemBuilder: (_, i) {
                      var item = followUsers[i];
                      return _buildLiveRoomFollowItem(
                        item: item,
                        onClose: onClose,
                      );
                    },
                  ),
                ),
              ),
            ],
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
      );
    });
  }

  Widget _buildLiveRoomFollowItem({
    required FollowUser item,
    required VoidCallback onClose,
  }) {
    return Obx(
      () => FollowUserItem(
        item: item,
        showSpecialMark: true,
        playing:
            rxSite.value.id == item.siteId && rxRoomId.value == item.roomId,
        onTap: () {
          onClose();
          resetRoom(
            Sites.allSites[item.siteId]!,
            item.roomId,
          );
        },
      ),
    );
  }

  void showFollowUserSheet() {
    Utils.showBottomSheet(
      title: "关注列表",
      child: buildFollowUserSelection(
        onClose: Get.back,
      ),
    );
  }

  void showAutoExitSheet() {
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
                dense: true,
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

  void openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site.id == Constant.kBiliBili) {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyin) {
      var args = detail.value?.danmakuData as DouyinDanmakuArgs;
      naviteUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
      webUrl = "https://live.douyin.com/${args.webRid}";
    } else if (site.id == Constant.kHuya) {
      var args = detail.value?.danmakuData as HuyaDanmakuArgs;
      naviteUrl =
          "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
      webUrl = "https://www.huya.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyu) {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    }
    try {
      await launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开 APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void resetRoom(Site site, String roomId) async {
    if (this.site == site && this.roomId == roomId) {
      return;
    }

    if (_roomSwitching) {
      _pendingRoomSite = site;
      _pendingRoomId = roomId;
      return;
    }

    _roomSwitching = true;
    try {
      while (true) {
        final currentSite = site;
        final currentRoomId = roomId;
        rxSite.value = currentSite;
        rxRoomId.value = currentRoomId;
        CurrentRoomService.instance.setRoom(currentSite, currentRoomId);
        _roomDisposed = false;
        _loadGeneration += 1;
        tempMutedUsers.clear();
        danmakuViewportHeight.value = 0;

        // 清理当前房间的会话状态
        await liveDanmaku.stop();
        messages.clear();
        _clearDanmuDedupeState();
        _clearSuperChatState();
        _clearContributionRankState();
        clearLiveEventFlow();
        _cancelPendingDanmakuTimers();
        clearDanmakuReplayHistory();
        danmakuController?.clear();
        rebuildDanmakuView();

        // 重新创建弹幕连接对象
        liveDanmaku = currentSite.liveSite.getDanmaku();

        // 停止当前播放
        await stopBackgroundPlaybackService();
        await _waitForPlayerReopen();
        await player.stop();

        // 重新拉取房间信息
        loadData();

        final pendingSite = _pendingRoomSite;
        final pendingRoomId = _pendingRoomId;
        _pendingRoomSite = null;
        _pendingRoomId = null;
        if (pendingSite == null || pendingRoomId == null) {
          break;
        }
        site = pendingSite;
        roomId = pendingRoomId;
      }
    } finally {
      _roomSwitching = false;
    }
  }

  void copyErrorDetail() {
    Utils.copyToClipboard('''直播平台：${rxSite.value.name}
房间号：${rxRoomId.value}
错误信息：
${error?.toString()}
----------------
${errorStackTrace ?? ""}''');
    SmartDialog.showToast("已复制错误信息");
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    refreshIosVideoOutputLimit(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed) {
      clearTransientPlayerOverlays();
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      Log.d("进入后台:$state");
      isBackground = true;
      _backgroundedAt = DateTime.now();
      _positionBeforeBackground = _lastKnownPlayerPosition;
      if (!_allowBackgroundPlayback) {
        unawaited(
          AppSettingsController.instance.saveLastLiveRoom(
            siteId: site.id,
            roomId: roomId,
            resumePending: true,
          ),
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      Log.d("返回前台");
      _refreshAutoExitCountdown();
      isBackground = false;
      unawaited(
        AppSettingsController.instance.setLastLiveRoomResumePending(false),
      );
      _refreshDanmakuOverlay("返回前台");
      var backgroundedAt = _backgroundedAt;
      var positionBeforeBackground = _positionBeforeBackground;
      _backgroundedAt = null;
      _positionBeforeBackground = null;
      unawaited(
        _recoverPlaybackAfterForeground(
          "返回前台",
          since: backgroundedAt,
          previousPosition: positionBeforeBackground,
        ),
      );
    } else if (state == AppLifecycleState.inactive) {
      Log.d("应用短暂失焦:$state");
      unawaited(syncAutoPipOnLeave());
    }
  }

  Future<void> _recoverPlaybackAfterForeground(
    String reason, {
    required DateTime? since,
    required Duration? previousPosition,
  }) async {
    final loadGeneration = _loadGeneration;
    if (since == null ||
        previousPosition == null ||
        !liveStatus.value ||
        currentLineIndex < 0 ||
        playUrls.isEmpty) {
      return;
    }
    if (DateTime.now().difference(since) < const Duration(seconds: 3)) {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!_isCurrentLoad(loadGeneration) || isBackground) {
      return;
    }
    var currentPosition = _lastKnownPlayerPosition;
    var stalled = currentPosition <= previousPosition ||
        player.state.buffering ||
        player.state.completed ||
        !player.state.playing;
    if (!stalled) {
      return;
    }
    if (!_isCurrentLoad(loadGeneration)) {
      return;
    }
    Log.d("$reason 后检测到播放停滞，尝试恢复");
    await setPlayer(refreshUrls: _shouldRefreshUrlsOnPlaybackRetry);
  }

  @override
  void onWindowBlur() {
    clearTransientPlayerOverlays();
    _windowBlurredAt = DateTime.now();
    _positionBeforeWindowBlur = _lastKnownPlayerPosition;
  }

  @override
  void onWindowFocus() {
    var windowBlurredAt = _windowBlurredAt;
    var positionBeforeWindowBlur = _positionBeforeWindowBlur;
    _windowBlurredAt = null;
    _positionBeforeWindowBlur = null;
    _refreshDanmakuOverlay("窗口重新聚焦");
    unawaited(
      _recoverPlaybackAfterForeground(
        "窗口重新聚焦",
        since: windowBlurredAt,
        previousPosition: positionBeforeWindowBlur,
      ),
    );
  }

  // 启动并更新开播时长计时器
  void startLiveDurationTimer() {
    // 非开播状态，或没有 showTime 时，不启动计时器。
    if (!(detail.value?.status ?? false) || detail.value?.showTime == null) {
      liveDuration.value = "00:00:00"; // 未开播时显示 00:00:00
      _liveDurationTimer?.cancel();
      return;
    }

    try {
      int startTimeStamp = int.parse(detail.value!.showTime!);
      // 先取消旧计时器，再启动新的。
      _liveDurationTimer?.cancel();
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
      liveDuration.value = "--:--:--"; // 解析失败时显示占位值
    }
  }

  // ignore: unused_element
  void _legacyOnClose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    scrollController.removeListener(scrollListener);
    _cancelAutoExitTimers();
    _positionSubscription?.cancel();

    liveDanmaku.stop();
    danmakuController = null;
    _liveDurationTimer?.cancel(); // 页面关闭时取消计时器
    super.onClose();
  }
}
