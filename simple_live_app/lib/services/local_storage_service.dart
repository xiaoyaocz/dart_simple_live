import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/log.dart';

class LocalStorageService extends GetxService {
  static LocalStorageService get instance => Get.find<LocalStorageService>();

  static const String kFirstRun = "FirstRun";
  static const String kPlayerScaleMode = "ScaleMode";
  static const String kSiteSort = "SiteSort";
  static const String kHomeSort = "HomeSort";
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
  static const String kDanmuShieldEnable = "DanmuShieldEnable";
  static const String kDanmuKeywordShieldEnable = "DanmuKeywordShieldEnable";
  static const String kDanmuUserShieldEnable = "DanmuUserShieldEnable";
  static const String kDanmuFontWeight = "DanmuFontWeight";
  static const String kContributionRankEnable = "ContributionRankEnable";
  static const String kHardwareDecode = "HardwareDecode";
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
  static const String kPlayerBufferSize = "PlayerBufferSize";
  static const String kPlayerForceHttps = "PlayerForceHttps";
  static const String kAutoFullScreen = "AutoFullScreen";
  static const String kPlayerShowSuperChat = "PlayerShowSuperChat";
  static const String kPlayerVolume = "PlayerVolume";
  static const String kPIPHideDanmu = "PIPHideDanmu";
  static const String kBilibiliCookie = "BilibiliCookie";
  static const String kDouyinCookie = "DouyinCookie";
  static const String kStyleColor = "kStyleColor";
  static const String kIsDynamic = "kIsDynamic";
  static const String kBilibiliLoginTip = "BilibiliLoginTip";
  static const String kLogEnable = "LogEnable";
  static const String kCustomPlayerOutput = "CustomPlayerOutput";
  static const String kVideoOutputDriver = "VideoOutputDriver";
  static const String kVideoHardwareDecoder = "VideoHardwareDecoder";
  static const String kAudioOutputDriver = "AudioOutputDriver";
  static const String kAutoUpdateFollowEnable = "AutoUpdateFollowEnable";
  static const String kUpdateFollowDuration = "AutoUpdateFollowDuration";
  static const String kUpdateFollowThreadCount = "UpdateFollowThreadCount";
  static const String kUserRemarks = "UserRemarks";
  static const String kLastLiveRoom = "LastLiveRoom";
  static const String kLastLiveRoomResumePending = "LastLiveRoomResumePending";
  static const String kWebDAVUri = "WebDAVUri";
  static const String kWebDAVUser = "WebDAVUser";
  static const String kWebDAVPassword = "kWebDAVPassword";
  static const String kWebDAVLastUploadTime = "kWebDAVLastUploadTime";
  static const String kWebDAVLastRecoverTime = "kWebDAVLastRecoverTime";

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
      Log.d("Get LocalStorage: $key\n$value");
      return value;
    } catch (e) {
      Log.logPrint(e);
      return defaultValue;
    }
  }

  Future setValue<T>(dynamic key, T value) async {
    Log.d("Set LocalStorage: $key\n$value");
    return await settingsBox.put(key, value);
  }

  Future removeValue<T>(dynamic key) async {
    Log.d("Remove LocalStorage: $key");
    return await settingsBox.delete(key);
  }
}
