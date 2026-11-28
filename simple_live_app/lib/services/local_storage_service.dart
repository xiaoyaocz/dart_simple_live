import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/log.dart';

class LocalStorageService extends GetxService {
  static const kPreferNativeFrameRate = "PreferNativeFrameRate";
  static LocalStorageService get instance => Get.find<LocalStorageService>();

  /// 首次运行
  static const String kFirstRun = "FirstRun";

  /// Windows 关闭窗口时的选择：0 询问、1 退出、2 最小化到托盘
  static const String kCloseAction = "WindowsCloseAction";

  /// 缩放模式
  static const String kPlayerScaleMode = "ScaleMode";

  /// 网站排序
  static const String kSiteSort = "SiteSort";

  /// 首页排序
  static const String kHomeSort = "HomeSort";

  /// 关注页默认状态：0 全部、1 直播中、2 未开播（不保存临时筛选）。
  static const String kFollowDefaultFilter = "FollowDefaultFilter";

  /// 关注列表最近一次开播状态快照（本地冷启动秒开用，不上传 WebDAV）。
  static const String kFollowStatusSnapshot = "FollowStatusSnapshot";

  /// 显示模式
  /// * [0] 跟随系统
  /// * [1] 浅色模式
  /// * [2] 深色模式
  static const String kThemeMode = "ThemeMode";

  /// DEBUG模式
  static const String kDebugModeKey = "DebugMode";

  /// 弹幕大小
  static const String kDanmuSize = "DanmuSize";

  /// 弹幕速度
  static const String kDanmuSpeed = "DanmuSpeed";

  /// 弹幕区域
  static const String kDanmuArea = "DanmuArea";

  /// 弹幕透明度
  static const String kDanmuOpacity = "DanmuOpacity";

  /// 弹幕描边大小
  static const String kDanmuStrokeWidth = "DanmuStrokeWidth";

  /// 弹幕-屏蔽滚动
  static const String kDanmuHideScroll = "DanmuHideScroll";

  /// 弹幕-屏蔽底部
  static const String kDanmuHideBottom = "DanmuHideBottom";

  /// 弹幕-屏蔽顶部
  static const String kDanmuHideTop = "DanmuHideTop";

  /// 弹幕-顶部边距
  static const String kDanmuTopMargin = "DanmuTopMargin";

  /// 弹幕-底部边距
  static const String kDanmuBottomMargin = "DanmuBottomMargin";

  /// 弹幕开启
  static const String kDanmuEnable = "DanmuEnable";

  /// 弹幕字重
  static const String kDanmuFontWeight = "DanmuFontWeight";

  /// 硬件解码
  static const String kHardwareDecode = "HardwareDecode";

  /// 聊天区文字大小
  static const String kChatTextSize = "ChatTextSize";

  /// 聊天区间隔
  static const String kChatTextGap = "ChatTextGap";

  /// 聊天区-气泡样式
  static const String kChatBubbleStyle = "ChatBubbleStyle";

  /// 播放清晰度，0=低，1=中，2=高
  static const String kQualityLevel = "QualityLevel";

  /// 蜂窝网络下播放清晰度，0=低，1=中，2=高
  static const String kQualityLevelCellular = "QualityLevelCellular";

  /// 开启定时关闭
  static const String kAutoExitEnable = "AutoExitEnable";

  /// 定时关闭时间（分钟）
  static const String kAutoExitDuration = "AutoExitDuration";

  /// 房间内定时关闭时间（分钟）
  /// 需要一个不同的 key，因为用户在房间内设置的倒计时和全局的可能不同。
  static const String kRoomAutoExitDuration = "RoomAutoExitDuration";

  /// 播放器兼容模式
  static const String kPlayerCompatMode = "PlayerCompatMode";

  /// 播放器后台自动暂停
  static const String kPlayerAutoPause = "PlayerAutoPause";

  /// 播放器缓冲区大小
  static const String kPlayerBufferSize = "PlayerBufferSize";

  /// 播放器强制使用HTTPS
  static const String kPlayerForceHttps = "PlayerForceHttps";

  /// 自动全屏
  static const String kAutoFullScreen = "AutoFullScreen";

  /// 显示SC
  static const String kPlayerShowSuperChat = "PlayerShowSuperChat";

  /// 播放器音量
  static const String kPlayerVolume = "PlayerVolume";

  /// 小窗隐藏弹幕
  static const String kPIPHideDanmu = "PIPHideDanmu";

  /// 哔哩哔哩cookie
  static const String kBilibiliCookie = "BilibiliCookie";

  /// 抖音cookie
  static const String kDouyinCookie = "DouyinCookie";

  ///主题色
  static const String kStyleColor = "kStyleColor";

  ///动态取色
  static const String kIsDynamic = "kIsDynamic";

  /// 提示哔哩哔哩登录
  static const String kBilibiliLoginTip = "BilibiliLoginTip";

  /// 日志记录
  static const String kLogEnable = "LogEnable";

  /// 开启自定义播放器视频输出
  static const String kCustomPlayerOutput = "CustomPlayerOutput";

  /// 视频输出驱动
  static const String kVideoOutputDriver = "VideoOutputDriver";

  /// 视频硬件解码器
  static const String kVideoHardwareDecoder = "VideoHardwareDecoder";

  /// 音频输出驱动
  static const String kAudioOutputDriver = "AudioOutputDriver";

  /// 开启自动更新关注
  static const String kAutoUpdateFollowEnable = "AutoUpdateFollowEnable";

  /// 定时自动更新关注间隔（分钟）
  static const String kUpdateFollowDuration = "AutoUpdateFollowDuration";

  /// 开启多线程更新关注
  static const String kUpdateFollowThreadCount = "UpdateFollowThreadCount";

  /// WebDAV_服务器地址
  static const String kWebDAVUri = "WebDAVUri";

  /// WebDAV_登录账号
  static const String kWebDAVUser = "WebDAVUser";

  /// WebDAV_登录密码
  static const String kWebDAVPassword = "kWebDAVPassword";

  /// WebDAV_最后一次上传时间
  static const String kWebDAVLastUploadTime = "kWebDAVLastUploadTime";

  /// WebDAV_最后一次备份时间
  static const String kWebDAVLastRecoverTime = "kWebDAVLastRecoverTime";

  /// 各平台已识别的本人弹幕昵称（siteId -> nickname）
  static const String kSelfChatNicknames = "SelfChatNicknames";

  /// 主播开播提醒通知
  static const String kLiveNotificationEnable = "LiveNotificationEnable";

  /// WebDAV 自动同步开关
  static const String kWebDAVAutoSync = "WebDAVAutoSync";

  /// 后台切换纯音频听播
  static const String kBackgroundAudioOnly = "BackgroundAudioOnly";

  /// 弹幕屏蔽用户列表
  static const String kDanmuShieldUsers = "DanmuShieldUsers";

  /// 弹幕刷屏重复合并开关
  static const String kDanmuMergeDuplicate = "DanmuMergeDuplicate";

  /// 弹幕刷屏重复合并时间窗（秒）
  static const String kDanmuMergeWindowSeconds = "DanmuMergeWindowSeconds";

  /// 播放器缓冲策略：0=均衡（默认），1=抗抖稳流，2=低延迟
  static const String kPlayerBufferMode = "PlayerBufferMode";

  /// 直播累积延迟自动微倍速追帧
  static const String kLiveCatchupEnable = "LiveCatchupEnable";

  /// 频繁卡顿/丢帧自动降清晰度
  static const String kAutoDowngradeQuality = "AutoDowngradeQuality";

  /// 开播/切清晰度前 CDN 线路测速优选
  static const String kStreamRouteProbeEnable = "StreamRouteProbeEnable";

  /// 持久化 CDN 线路质量历史（仅存 origin，不含签名）
  static const String kPlaybackRouteHistory = "PlaybackRouteHistory";

  /// Windows AI 超分着色器开关（FSRCNNX）
  static const String kWindowsSuperResolution = "WindowsSuperResolution";

  /// Windows 动态画面平滑（补帧）开关
  static const String kWindowsInterpolation = "WindowsInterpolation";

  /// Windows WASAPI 音频独占开关
  static const String kWindowsAudioExclusive = "WindowsAudioExclusive";

  /// 手机端画面去色带（Deband）开关
  static const String kMobileDeband = "MobileDeband";

  /// 手机端高刷动态画面平滑（补帧）开关
  static const String kMobileInterpolation = "MobileInterpolation";

  late Box settingsBox;
  late Box<String> shieldBox;

  Future init() async {
    settingsBox = await Hive.openBox(
      "LocalStorage",
    );
    shieldBox = await Hive.openBox(
      "DanmuShield",
    );
  }

  T getValue<T>(dynamic key, T defaultValue) {
    try {
      var value = settingsBox.get(key, defaultValue: defaultValue) as T;
      Log.d("Get LocalStorage：$key\r\n$value");
      return value;
    } catch (e) {
      Log.logPrint(e);
      return defaultValue;
    }
  }

  Future setValue<T>(dynamic key, T value) async {
    Log.d("Set LocalStorage：$key\r\n$value");
    return await settingsBox.put(key, value);
  }

  Future removeValue<T>(dynamic key) async {
    Log.d("Remove LocalStorage：$key");
    return await settingsBox.delete(key);
  }

  String getSelfChatNickname(String siteId) {
    final raw = getValue<dynamic>(kSelfChatNicknames, const {});
    if (raw is Map && raw[siteId] is String) {
      return (raw[siteId] as String).trim();
    }
    return '';
  }

  Future<void> setSelfChatNickname(String siteId, String nickname) async {
    final clean = nickname.trim();
    if (siteId.isEmpty || clean.isEmpty) return;
    final raw = getValue<dynamic>(kSelfChatNicknames, const {});
    final next = <String, String>{
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
    };
    if (next[siteId] == clean) return;
    next[siteId] = clean;
    await setValue(kSelfChatNicknames, next);
  }
}
