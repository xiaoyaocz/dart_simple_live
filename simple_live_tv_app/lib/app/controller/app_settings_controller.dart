import 'package:simple_live_tv_app/services/local_storage_service.dart';

import 'package:get/get.dart';

class AppSettingsController extends GetxController {
  static AppSettingsController get instance =>
      Get.find<AppSettingsController>();

  static const String _keywordShieldPrefix = "keyword:";
  static const String _userShieldPrefix = "user:";
  static const int kDanmuDedupeModeUser = 0;
  static const int kDanmuDedupeModeStrict = 1;
  static const int kDanmuDedupeDefaultWindow = 10;
  static const int kDanmuDedupeStrictMinWindow = 5;
  static const int kDanmuDedupeMaxWindow = 100;
  static const int kDanmuDedupeStrictWarnWindow = 20;
  static const int kLiveEventFlowDefaultLimit = 100;
  static const int kLiveEventFlowMinLimit = 100;
  static const int kLiveEventFlowMaxLimit = 500;
  static const int kLiveEventFlowDefaultWindowSeconds = 30;
  static const int kLiveEventFlowMinWindowSeconds = 5;
  static const int kLiveEventFlowMaxWindowSeconds = 120;
  static const int kLiveEventFlowDefaultDisplaySeconds = 10;
  static const int kLiveEventFlowMinDisplaySeconds = 3;
  static const int kLiveEventFlowMaxDisplaySeconds = 60;
  static const int kLiveEventFlowDefaultMinCount = 5;
  static const int kLiveEventFlowMinCount = 2;
  static const int kLiveEventFlowMaxCount = 100;
  static const int kMultiRoomDefaultGap = 8;
  static const int kMultiRoomMinGap = 0;
  static const int kMultiRoomMaxGap = 24;
  static const List<int> kUpdateFollowThreadOptions = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
  ];
  static const int kFollowPageSizeDefault = 200;
  static const int kFollowPageSizeMin = 2;
  static const List<String> followDisplayStyleOptions = [
    "default",
    "compact",
    "card",
  ];

  /// 缩放模式
  var scaleMode = 0.obs;

  var firstRun = false;

  @override
  void onInit() {
    firstRun = LocalStorageService.instance
        .getValue(LocalStorageService.kFirstRun, true);
    danmuSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuSize, 40.0);
    danmuOpacity.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuOpacity, 1.0);
    danmuArea.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuArea, 0.25);
    danmuSpeed.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuSpeed, 10.0);
    danmuEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuEnable, true);
    danmuRenderEmoji.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuRenderEmoji, true);
    liveEventFlowEnable.value = LocalStorageService.instance.getValue(
      LocalStorageService.kLiveEventFlowEnable,
      false,
    );
    liveEventFlowLimit.value = _normalizeLiveEventFlowLimit(
      LocalStorageService.instance.getValue(
        LocalStorageService.kLiveEventFlowLimit,
        kLiveEventFlowDefaultLimit,
      ),
    );
    liveEventFlowOverlayEnable.value = LocalStorageService.instance.getValue(
      LocalStorageService.kLiveEventFlowOverlayEnable,
      true,
    );
    liveEventFlowWindowSeconds.value = _normalizeLiveEventFlowWindowSeconds(
      LocalStorageService.instance.getValue(
        LocalStorageService.kLiveEventFlowWindowSeconds,
        kLiveEventFlowDefaultWindowSeconds,
      ),
    );
    liveEventFlowDisplaySeconds.value = _normalizeLiveEventFlowDisplaySeconds(
      LocalStorageService.instance.getValue(
        LocalStorageService.kLiveEventFlowDisplaySeconds,
        kLiveEventFlowDefaultDisplaySeconds,
      ),
    );
    liveEventFlowMinCount.value = _normalizeLiveEventFlowMinCount(
      LocalStorageService.instance.getValue(
        LocalStorageService.kLiveEventFlowMinCount,
        kLiveEventFlowDefaultMinCount,
      ),
    );
    danmuDedupeEnable.value = LocalStorageService.instance.getValue(
      LocalStorageService.kDanmuDedupeEnable,
      false,
    );
    danmuDedupeMode.value = _normalizeDanmuDedupeMode(
      LocalStorageService.instance.getValue(
        LocalStorageService.kDanmuDedupeMode,
        kDanmuDedupeModeUser,
      ),
    );
    danmuDedupeWindow.value = _normalizeDanmuDedupeWindow(
      LocalStorageService.instance.getValue(
        LocalStorageService.kDanmuDedupeWindow,
        kDanmuDedupeDefaultWindow,
      ),
    );
    danmuDedupeStep.value = LocalStorageService.instance.getValue(
      LocalStorageService.kDanmuDedupeStep,
      2,
    );
    danmuStrokeWidth.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuStrokeWidth, 4.0);
    danmuTopMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuTopMargin, 0.0);
    danmuBottomMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuBottomMargin, 0.0);

    hardwareDecode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kHardwareDecode, true);
    chatTextSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextSize, 14.0);

    chatTextGap.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextGap, 4.0);

    chatBubbleStyle.value = LocalStorageService.instance.getValue(
      LocalStorageService.kChatBubbleStyle,
      false,
    );

    qualityLevel.value = LocalStorageService.instance
        .getValue(LocalStorageService.kQualityLevel, 1);
    qualityLevelCellular.value = LocalStorageService.instance
        .getValue(LocalStorageService.kQualityLevelCellular, 1);

    autoExitEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitEnable, false);

    autoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitDuration, 60);

    roomAutoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kRoomAutoExitDuration, 60);

    playerCompatMode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerCompatMode, false);
    mpvProfile.value = LocalStorageService.instance
        .getValue(LocalStorageService.kMpvProfile, "balanced");

    playerAutoPause.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerAutoPause, false);

    autoFullScreen.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoFullScreen, false);
    autoSwitchNextOnLiveEnd.value = LocalStorageService.instance.getValue(
      LocalStorageService.kAutoSwitchNextOnLiveEnd,
      false,
    );
    autoSwitchNextOnPlaybackFailure.value =
        LocalStorageService.instance.getValue(
      LocalStorageService.kAutoSwitchNextOnPlaybackFailure,
      false,
    );

    shieldList
      ..clear()
      ..addAll(
        LocalStorageService.instance.shieldBox.values
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && !e.startsWith(_userShieldPrefix))
            .map(
              (e) => e.startsWith(_keywordShieldPrefix)
                  ? e.substring(_keywordShieldPrefix.length)
                  : e,
            )
            .where((e) => e.isNotEmpty),
      );

    scaleMode.value = LocalStorageService.instance.getValue(
      LocalStorageService.kPlayerScaleMode,
      0,
    );

    pipHideDanmu.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPIPHideDanmu, true);

    styleColor.value = LocalStorageService.instance
        .getValue(LocalStorageService.kStyleColor, 0xff3498db);

    isDynamic.value = LocalStorageService.instance
        .getValue(LocalStorageService.kIsDynamic, false);

    bilibiliLoginTip.value = LocalStorageService.instance
        .getValue(LocalStorageService.kBilibiliLoginTip, true);

    playerBufferSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerBufferSize, 32);

    autoUpdateFollowEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoUpdateFollowEnable, true);

    autoUpdateFollowDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowDuration, 10);

    updateFollowThreadCount.value = _normalizeUpdateFollowThreadCount(
      LocalStorageService.instance.getValue(
        LocalStorageService.kUpdateFollowThreadCount,
        0,
      ),
    );
    followPageSize.value = _normalizeFollowPageSize(
      LocalStorageService.instance.getValue(
        LocalStorageService.kFollowPageSize,
        kFollowPageSizeDefault,
      ),
    );
    followDisplayStyle.value = _normalizeFollowDisplayStyle(
      LocalStorageService.instance.getValue(
        LocalStorageService.kFollowDisplayStyle,
        "default",
      ),
    );
    followOnlyLive.value = LocalStorageService.instance.getValue(
      LocalStorageService.kFollowOnlyLive,
      false,
    );
    followRefreshOnEnter.value = LocalStorageService.instance.getValue(
      LocalStorageService.kFollowRefreshOnEnter,
      false,
    );
    followShowLiveCover.value = LocalStorageService.instance.getValue(
      LocalStorageService.kFollowShowLiveCover,
      false,
    );
    multiRoomGap.value = _normalizeMultiRoomGap(
      LocalStorageService.instance.getValue(
        LocalStorageService.kMultiRoomGap,
        kMultiRoomDefaultGap,
      ),
    );

    super.onInit();
  }

  void setNoFirstRun() {
    LocalStorageService.instance.setValue(LocalStorageService.kFirstRun, false);
  }

  var hardwareDecode = true.obs;
  void setHardwareDecode(bool e) {
    hardwareDecode.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kHardwareDecode, e);
  }

  var chatTextSize = 14.0.obs;
  void setChatTextSize(double e) {
    chatTextSize.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kChatTextSize, e);
  }

  var chatTextGap = 4.0.obs;
  void setChatTextGap(double e) {
    chatTextGap.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kChatTextGap, e);
  }

  var chatBubbleStyle = false.obs;
  void setChatBubbleStyle(bool e) {
    chatBubbleStyle.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kChatBubbleStyle, e);
  }

  var danmuSize = 40.0.obs;
  void setDanmuSize(double e) {
    danmuSize.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuSize, e);
  }

  var danmuSpeed = 10.0.obs;
  void setDanmuSpeed(double e) {
    danmuSpeed.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuSpeed, e);
  }

  var danmuArea = 0.25.obs;
  void setDanmuArea(double e) {
    danmuArea.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuArea, e);
  }

  var danmuOpacity = 1.0.obs;
  void setDanmuOpacity(double e) {
    danmuOpacity.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuOpacity, e);
  }

  var danmuEnable = true.obs;
  void setDanmuEnable(bool e) {
    danmuEnable.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuEnable, e);
  }

  var danmuRenderEmoji = true.obs;
  void setDanmuRenderEmoji(bool e) {
    danmuRenderEmoji.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuRenderEmoji, e);
  }

  var liveEventFlowEnable = false.obs;
  void setLiveEventFlowEnable(bool e) {
    liveEventFlowEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveEventFlowEnable, e);
  }

  var liveEventFlowLimit = kLiveEventFlowDefaultLimit.obs;
  void setLiveEventFlowLimit(int e) {
    final value = _normalizeLiveEventFlowLimit(e);
    liveEventFlowLimit.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveEventFlowLimit, value);
  }

  int _normalizeLiveEventFlowLimit(int value) {
    return value.clamp(kLiveEventFlowMinLimit, kLiveEventFlowMaxLimit).toInt();
  }

  var liveEventFlowOverlayEnable = true.obs;
  void setLiveEventFlowOverlayEnable(bool e) {
    liveEventFlowOverlayEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveEventFlowOverlayEnable, e);
  }

  var liveEventFlowWindowSeconds = kLiveEventFlowDefaultWindowSeconds.obs;
  int get effectiveLiveEventFlowWindowSeconds =>
      _normalizeLiveEventFlowWindowSeconds(liveEventFlowWindowSeconds.value);
  void setLiveEventFlowWindowSeconds(int e) {
    final value = _normalizeLiveEventFlowWindowSeconds(e);
    liveEventFlowWindowSeconds.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveEventFlowWindowSeconds, value);
  }

  int _normalizeLiveEventFlowWindowSeconds(int value) {
    return value
        .clamp(kLiveEventFlowMinWindowSeconds, kLiveEventFlowMaxWindowSeconds)
        .toInt();
  }

  var liveEventFlowDisplaySeconds = kLiveEventFlowDefaultDisplaySeconds.obs;
  int get effectiveLiveEventFlowDisplaySeconds =>
      _normalizeLiveEventFlowDisplaySeconds(liveEventFlowDisplaySeconds.value);
  void setLiveEventFlowDisplaySeconds(int e) {
    final value = _normalizeLiveEventFlowDisplaySeconds(e);
    liveEventFlowDisplaySeconds.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveEventFlowDisplaySeconds, value);
  }

  int _normalizeLiveEventFlowDisplaySeconds(int value) {
    return value
        .clamp(kLiveEventFlowMinDisplaySeconds, kLiveEventFlowMaxDisplaySeconds)
        .toInt();
  }

  var liveEventFlowMinCount = kLiveEventFlowDefaultMinCount.obs;
  int get effectiveLiveEventFlowMinCount =>
      _normalizeLiveEventFlowMinCount(liveEventFlowMinCount.value);
  void setLiveEventFlowMinCount(int e) {
    final value = _normalizeLiveEventFlowMinCount(e);
    liveEventFlowMinCount.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveEventFlowMinCount, value);
  }

  int _normalizeLiveEventFlowMinCount(int value) {
    return value.clamp(kLiveEventFlowMinCount, kLiveEventFlowMaxCount).toInt();
  }

  var danmuDedupeEnable = false.obs;
  void setDanmuDedupeEnable(bool e) {
    danmuDedupeEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuDedupeEnable, e);
  }

  var danmuDedupeMode = kDanmuDedupeModeUser.obs;
  bool get danmuDedupeStrictMode =>
      danmuDedupeMode.value == kDanmuDedupeModeStrict;
  int get danmuDedupeWindowMin =>
      danmuDedupeStrictMode ? kDanmuDedupeStrictMinWindow : 1;
  int get effectiveDanmuDedupeWindow =>
      _normalizeDanmuDedupeWindow(danmuDedupeWindow.value);

  void setDanmuDedupeMode(int e) {
    final value = _normalizeDanmuDedupeMode(e);
    danmuDedupeMode.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuDedupeMode, value);
    if (value == kDanmuDedupeModeStrict) {
      setDanmuDedupeEnable(true);
      setDanmuDedupeWindow(kDanmuDedupeDefaultWindow);
    }
  }

  int _normalizeDanmuDedupeMode(int value) {
    return value == kDanmuDedupeModeStrict
        ? kDanmuDedupeModeStrict
        : kDanmuDedupeModeUser;
  }

  int _normalizeDanmuDedupeWindow(int value) {
    return value.clamp(danmuDedupeWindowMin, kDanmuDedupeMaxWindow).toInt();
  }

  var danmuDedupeWindow = kDanmuDedupeDefaultWindow.obs;
  void setDanmuDedupeWindow(int e) {
    final value = _normalizeDanmuDedupeWindow(e);
    danmuDedupeWindow.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuDedupeWindow, value);
  }

  var danmuDedupeStep = 2.obs;
  void setDanmuDedupeStep(int e) {
    final value = e.clamp(1, 20).toInt();
    danmuDedupeStep.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuDedupeStep, value);
  }

  var danmuStrokeWidth = 4.0.obs;
  void setDanmuStrokeWidth(double e) {
    danmuStrokeWidth.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuStrokeWidth, e);
  }

  var qualityLevel = 1.obs;
  void setQualityLevel(int level) {
    qualityLevel.value = level;
    LocalStorageService.instance
        .setValue(LocalStorageService.kQualityLevel, level);
  }

  var qualityLevelCellular = 1.obs;
  void setQualityLevelCellular(int level) {
    qualityLevelCellular.value = level;
    LocalStorageService.instance
        .setValue(LocalStorageService.kQualityLevelCellular, level);
  }

  var autoExitEnable = false.obs;
  void setAutoExitEnable(bool e) {
    autoExitEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoExitEnable, e);
  }

  var autoExitDuration = 60.obs;
  void setAutoExitDuration(int e) {
    autoExitDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoExitDuration, e);
  }

  var roomAutoExitDuration = 60.obs;
  void setRoomAutoExitDuration(int e) {
    roomAutoExitDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kRoomAutoExitDuration, e);
  }

  var playerCompatMode = false.obs;
  void setPlayerCompatMode(bool e) {
    playerCompatMode.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerCompatMode, e);
  }

  var mpvProfile = "balanced".obs;
  void setMpvProfile(String e) {
    mpvProfile.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kMpvProfile, e);
  }

  var playerBufferSize = 32.obs;
  void setPlayerBufferSize(int e) {
    playerBufferSize.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerBufferSize, e);
  }

  var playerAutoPause = false.obs;
  void setPlayerAutoPause(bool e) {
    playerAutoPause.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerAutoPause, e);
  }

  var autoFullScreen = false.obs;
  void setAutoFullScreen(bool e) {
    autoFullScreen.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoFullScreen, e);
  }

  var autoSwitchNextOnLiveEnd = false.obs;
  void setAutoSwitchNextOnLiveEnd(bool e) {
    autoSwitchNextOnLiveEnd.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kAutoSwitchNextOnLiveEnd,
      e,
    );
  }

  var autoSwitchNextOnPlaybackFailure = false.obs;
  void setAutoSwitchNextOnPlaybackFailure(bool e) {
    autoSwitchNextOnPlaybackFailure.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kAutoSwitchNextOnPlaybackFailure,
      e,
    );
  }

  RxSet<String> shieldList = <String>{}.obs;

  void importShieldValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty || value.startsWith(_userShieldPrefix)) {
      return;
    }
    if (value.startsWith(_keywordShieldPrefix)) {
      addShieldList(value.substring(_keywordShieldPrefix.length));
      return;
    }
    addShieldList(value);
  }

  void addShieldList(String e) {
    final value = e.trim();
    if (value.isEmpty) {
      return;
    }
    shieldList.add(value);
    LocalStorageService.instance.shieldBox.put(value, value);
  }

  void removeShieldList(String e) {
    final value = e.trim();
    shieldList.remove(value);
    LocalStorageService.instance.shieldBox.delete(value);
  }

  Future clearShieldList() async {
    shieldList.clear();
    await LocalStorageService.instance.shieldBox.clear();
  }

  void setScaleMode(int value) {
    scaleMode.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kPlayerScaleMode,
      value,
    );
  }

  RxList<String> siteSort = RxList<String>();
  void setSiteSort(List<String> e) {
    siteSort.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kSiteSort,
      siteSort.join(","),
    );
  }

  RxList<String> homeSort = RxList<String>();
  void setHomeSort(List<String> e) {
    homeSort.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kHomeSort,
      homeSort.join(","),
    );
  }

  var pipHideDanmu = true.obs;
  void setPIPHideDanmu(bool e) {
    pipHideDanmu.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kPIPHideDanmu, e);
  }

  var styleColor = 0xff3498db.obs;
  void setStyleColor(int e) {
    styleColor.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kStyleColor, e);
  }

  var isDynamic = false.obs;
  void setIsDynamic(bool e) {
    isDynamic.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kIsDynamic, e);
  }

  var danmuTopMargin = 0.0.obs;
  void setDanmuTopMargin(double e) {
    danmuTopMargin.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuTopMargin, e);
  }

  var danmuBottomMargin = 0.0.obs;
  void setDanmuBottomMargin(double e) {
    danmuBottomMargin.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuBottomMargin, e);
  }

  var bilibiliLoginTip = true.obs;
  void setBiliBiliLoginTip(bool e) {
    bilibiliLoginTip.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliLoginTip, e);
  }

  var autoUpdateFollowEnable = false.obs;
  void setAutoUpdateFollowEnable(bool e) {
    autoUpdateFollowEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoUpdateFollowEnable, e);
  }

  var autoUpdateFollowDuration = 10.obs;
  void setAutoUpdateFollowDuration(int e) {
    autoUpdateFollowDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kUpdateFollowDuration, e);
  }

  var updateFollowThreadCount = 0.obs;
  int get effectiveUpdateFollowThreadCount =>
      _normalizeUpdateFollowThreadCount(updateFollowThreadCount.value);
  void setUpdateFollowThreadCount(int e) {
    final value = _normalizeUpdateFollowThreadCount(e);
    updateFollowThreadCount.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kUpdateFollowThreadCount, value);
  }

  int _normalizeUpdateFollowThreadCount(int value) {
    if (kUpdateFollowThreadOptions.contains(value)) {
      return value;
    }
    return 0;
  }

  var followPageSize = kFollowPageSizeDefault.obs;
  int _normalizeFollowPageSize(int value) {
    return value.clamp(kFollowPageSizeMin, 400).toInt();
  }

  void setFollowPageSize(int value) {
    final normalized = _normalizeFollowPageSize(value);
    followPageSize.value = normalized;
    LocalStorageService.instance.setValue(
      LocalStorageService.kFollowPageSize,
      normalized,
    );
  }

  var followDisplayStyle = "default".obs;
  var followOnlyLive = false.obs;
  var followRefreshOnEnter = false.obs;
  var followShowLiveCover = false.obs;

  String _normalizeFollowDisplayStyle(String value) {
    if (followDisplayStyleOptions.contains(value)) {
      return value;
    }
    return "default";
  }

  void setFollowDisplayStyle(String value) {
    final normalized = _normalizeFollowDisplayStyle(value);
    followDisplayStyle.value = normalized;
    LocalStorageService.instance.setValue(
      LocalStorageService.kFollowDisplayStyle,
      normalized,
    );
  }

  void setFollowOnlyLive(bool value) {
    followOnlyLive.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kFollowOnlyLive,
      value,
    );
  }

  void setFollowRefreshOnEnter(bool value) {
    followRefreshOnEnter.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kFollowRefreshOnEnter,
      value,
    );
  }

  void setFollowShowLiveCover(bool value) {
    followShowLiveCover.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kFollowShowLiveCover,
      value,
    );
  }

  var multiRoomGap = kMultiRoomDefaultGap.obs;
  int get effectiveMultiRoomGap => _normalizeMultiRoomGap(multiRoomGap.value);
  void setMultiRoomGap(int value) {
    final normalized = _normalizeMultiRoomGap(value);
    multiRoomGap.value = normalized;
    LocalStorageService.instance.setValue(
      LocalStorageService.kMultiRoomGap,
      normalized,
    );
  }

  int _normalizeMultiRoomGap(int value) {
    return value.clamp(kMultiRoomMinGap, kMultiRoomMaxGap).toInt();
  }
}
