import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/log.dart';

class LocalStorageService extends GetxService {
  static LocalStorageService get instance => Get.find<LocalStorageService>();

  static const String kFirstRun = "FirstRun";
  static const String kPlayerScaleMode = "ScaleMode";
  static const String kSiteSort = "SiteSort";
  static const String kHomeSort = "HomeSort";
  static const String kLiveRoomTabSort = "LiveRoomTabSort";
  static const String kLiveRoomQuickAccessSort = "LiveRoomQuickAccessSort";
  static const String kLiveRoomQuickAccessEnabled =
      "LiveRoomQuickAccessEnabled";
  static const String kLiveRoomShortcutFullScreen =
      "LiveRoomShortcutFullScreen";
  static const String kLiveRoomShortcutDanmaku = "LiveRoomShortcutDanmaku";
  static const String kLiveRoomShortcutMute = "LiveRoomShortcutMute";
  static const String kLiveRoomShortcutRefresh = "LiveRoomShortcutRefresh";
  static const String kLiveRoomShortcutToggleChat =
      "LiveRoomShortcutToggleChat";
  static const String kLiveRoomShortcutVolumeUp = "LiveRoomShortcutVolumeUp";
  static const String kLiveRoomShortcutVolumeDown =
      "LiveRoomShortcutVolumeDown";
  static const String kLastSearchSiteId = "LastSearchSiteId";
  static const String kFollowGroupMode = "FollowGroupMode";
  static const String kFollowSelectedGroupId = "FollowSelectedGroupId";
  static const String kFollowDisplayStyle = "FollowDisplayStyle";
  static const String kFollowOnlyLive = "FollowOnlyLive";
  static const String kFollowRefreshOnEnter = "FollowRefreshOnEnter";
  static const String kFollowShowLiveCover = "FollowShowLiveCover";
  static const String kRememberWindowPlacement = "RememberWindowPlacement";
  static const String kDesktopWindowBounds = "DesktopWindowBounds";
  static const String kDesktopWindowMaximized = "DesktopWindowMaximized";
  static const String kMultiRoomGap = "MultiRoomGap";
  static const String kMultiRoomCollapseChat = "MultiRoomCollapseChat";
  static const String kThemeMode = "ThemeMode";
  static const String kDebugModeKey = "DebugMode";
  static const String kDanmuSize = "DanmuSize";
  static const String kDanmuSpeed = "DanmuSpeed";
  static const String kDanmuArea = "DanmuArea";
  static const String kDanmuLineCount = "DanmuLineCount";
  static const String kDanmuDelay = "DanmuDelay";
  static const String kDanmuOpacity = "DanmuOpacity";
  static const String kDanmuStrokeWidth = "DanmuStrokeWidth";
  static const String kDanmuHideScroll = "DanmuHideScroll";
  static const String kDanmuHideBottom = "DanmuHideBottom";
  static const String kDanmuHideTop = "DanmuHideTop";
  static const String kDanmuTopMargin = "DanmuTopMargin";
  static const String kDanmuBottomMargin = "DanmuBottomMargin";
  static const String kDanmuEnable = "DanmuEnable";
  static const String kDanmuRenderEmoji = "DanmuRenderEmoji";
  static const String kDanmuShieldEnable = "DanmuShieldEnable";
  static const String kDanmuKeywordShieldEnable = "DanmuKeywordShieldEnable";
  static const String kDanmuUserShieldEnable = "DanmuUserShieldEnable";
  static const String kDanmuFontWeight = "DanmuFontWeight";
  static const String kContributionRankEnable = "ContributionRankEnable";
  static const String kHardwareDecode = "HardwareDecode";
  static const String kIosOriginalQualityPowerSaving =
      "IosOriginalQualityPowerSaving";
  static const String kChatTextSize = "ChatTextSize";
  static const String kChatTextGap = "ChatTextGap";
  static const String kChatBubbleStyle = "ChatBubbleStyle";
  static const String kQualityLevel = "QualityLevel";
  static const String kQualityLevelCellular = "QualityLevelCellular";
  static const String kAutoExitEnable = "AutoExitEnable";
  static const String kAutoExitDuration = "AutoExitDuration";
  static const String kRoomAutoExitDuration = "RoomAutoExitDuration";
  static const String kPlayerCompatMode = "PlayerCompatMode";
  static const String kPlayerAutoPause = "PlayerAutoPause";
  static const String kAllowBackgroundPlayback = "AllowBackgroundPlayback";
  static const String kPlayerBufferSize = "PlayerBufferSize";
  static const String kPlayerForceHttps = "PlayerForceHttps";
  static const String kPlayerGestureControlEnable =
      "PlayerGestureControlEnable";
  static const String kAutoSwitchNextOnLiveEnd = "AutoSwitchNextOnLiveEnd";
  static const String kAutoSwitchNextOnPlaybackFailure =
      "AutoSwitchNextOnPlaybackFailure";
  static const String kAutoFullScreen = "AutoFullScreen";
  static const String kAutoPipOnExit = "AutoPipOnExit";
  static const String kPlayerShowSuperChat = "PlayerShowSuperChat";
  static const String kLiveEventFlowEnable = "LiveEventFlowEnable";
  static const String kLiveEventFlowLimit = "LiveEventFlowLimit";
  static const String kLiveEventFlowOverlayEnable =
      "LiveEventFlowOverlayEnable";
  static const String kLiveEventFlowWindowSeconds =
      "LiveEventFlowWindowSeconds";
  static const String kLiveEventFlowDisplaySeconds =
      "LiveEventFlowDisplaySeconds";
  static const String kLiveEventFlowMinCount = "LiveEventFlowMinCount";
  static const String kPlayerVolume = "PlayerVolume";
  static const String kPIPHideDanmu = "PIPHideDanmu";
  static const String kPIPHideDanmuDefaultMigrated =
      "PIPHideDanmuDefaultMigrated";
  static const String kSuperChatSortDesc = "SuperChatSortDesc";
  static const String kDanmuDedupeEnable = "DanmuDedupeEnable";
  static const String kDanmuDedupeMode = "DanmuDedupeMode";
  static const String kDanmuDedupeWindow = "DanmuDedupeWindow";
  static const String kDanmuDedupeStep = "DanmuDedupeStep";
  static const String kBilibiliCookie = "BilibiliCookie";
  static const String kDouyinCookie = "DouyinCookie";
  static const String kKuaishouCookie = "KuaishouCookie";
  static const String kKuaishouKww = "KuaishouKww";
  static const String kKuaishouCookieExpiresAt = "KuaishouCookieExpiresAt";
  static const String kStyleColor = "kStyleColor";
  static const String kIsDynamic = "kIsDynamic";
  static const String kBilibiliLoginTip = "BilibiliLoginTip";
  static const String kLogEnable = "LogEnable";
  static const String kCustomPlayerOutput = "CustomPlayerOutput";
  static const String kVideoOutputDriver = "VideoOutputDriver";
  static const String kVideoHardwareDecoder = "VideoHardwareDecoder";
  static const String kWindowsGpuPreference = "WindowsGpuPreference";
  static const String kAudioOutputDriver = "AudioOutputDriver";
  static const String kMpvProfile = "MpvProfile";
  static const String kMpvAdvancedOptions = "MpvAdvancedOptions";
  static const String kImportedMpvConfPath = "ImportedMpvConfPath";
  static const String kAutoUpdateFollowEnable = "AutoUpdateFollowEnable";
  static const String kUpdateFollowDuration = "AutoUpdateFollowDuration";
  static const String kUpdateFollowThreadCount = "UpdateFollowThreadCount";
  static const String kFollowPageSize = "FollowPageSize";
  static const String kFollowRefreshTaskState = "FollowRefreshTaskState";
  static const String kFollowRefreshTaskTargets = "FollowRefreshTaskTargets";
  static const String kUserRemarks = "UserRemarks";
  static const String kLastLiveRoom = "LastLiveRoom";
  static const String kLastLiveRoomResumePending = "LastLiveRoomResumePending";
  static const String kWebDAVUri = "WebDAVUri";
  static const String kWebDAVUser = "WebDAVUser";
  static const String kWebDAVPassword = "kWebDAVPassword";
  static const String kWebDAVLastUploadTime = "kWebDAVLastUploadTime";
  static const String kWebDAVLastRecoverTime = "kWebDAVLastRecoverTime";
  static const String kSyncServerUrl = "SyncServerUrl";
  static const String kSyncProxyUrl = "SyncProxyUrl";
  static const String kLiveSubtitleEnable = "LiveSubtitleEnable";
  static const String kLiveSubtitleModelPath = "LiveSubtitleModelPath";
  static const String kLiveSubtitleLanguage = "LiveSubtitleLanguage";
  static const String kLiveSubtitleFontSize = "LiveSubtitleFontSize";
  static const String kLiveSubtitlePosition = "LiveSubtitlePosition";
  static const String kLiveSubtitleOffsetX = "LiveSubtitleOffsetX";
  static const String kLiveSubtitleOffsetY = "LiveSubtitleOffsetY";
  static const String kLiveSubtitleColor = "LiveSubtitleColor";
  static const String kLiveSubtitleFontWeight = "LiveSubtitleFontWeight";
  static const String kLiveSubtitleBackgroundEnable =
      "LiveSubtitleBackgroundEnable";
  static const String kLiveSubtitlePositionLocked =
      "LiveSubtitlePositionLocked";
  static const String kLiveSubtitleStartupGuard = "LiveSubtitleStartupGuard";

  // 小窗弹幕设置
  static const String kSmallWindowDanmuScale = "SmallWindowDanmuScale";
  static const String kSmallWindowDanmuMaxLines = "SmallWindowDanmuMaxLines";
  static const String kSmallWindowDanmuAutoTransparent = "SmallWindowDanmuAutoTransparent";

  // PIP弹幕设置
  static const String kEnablePipDanmu = "EnablePipDanmu";
  static const String kPipDanmuScale = "PipDanmuScale";

  // SuperChat 全屏滚动
  static const String kSuperChatScrollInFullscreen = "SuperChatScrollInFullscreen";

  late Box settingsBox;
  late Box<String> shieldBox;
  late Box<String> shieldPresetBox;

  Future init() async {
    settingsBox = await Hive.openBox("LocalStorage");
    shieldBox = await Hive.openBox("DanmuShield");
    shieldPresetBox = await Hive.openBox("DanmuShieldPreset");
  }

  T getValue<T>(dynamic key, T defaultValue) {
    try {
      final value = settingsBox.get(key, defaultValue: defaultValue) as T;
      Log.d("Get LocalStorage: $key");
      return value;
    } catch (e) {
      Log.logPrint(e);
      return defaultValue;
    }
  }

  Future setValue<T>(dynamic key, T value) async {
    Log.d("Set LocalStorage: $key");
    return await settingsBox.put(key, value);
  }

  Future removeValue<T>(dynamic key) async {
    Log.d("Remove LocalStorage: $key");
    return await settingsBox.delete(key);
  }
}
