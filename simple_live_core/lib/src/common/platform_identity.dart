/// 平台身份统一配置：各平台的 User-Agent 等身份指纹集中在此。
///
/// 风控是一持续性的"猫鼠游戏"（参考：虎牙 wup UA 版本号、斗鱼 Edg 变体、
/// 抖音 QQBrowser 指纹），调整任何平台的身份只需改这一个文件；
/// 每个值都可能被服务端用作风控指纹，修改前先抓包核对网页端实际取值。
class PlatformIdentity {
  PlatformIdentity._();

  /// 斗鱼：网页通用请求（房间页 / 贡献榜 / 亲密度等）
  static const String douyuUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// 斗鱼：搜索相关接口（Edg/114.0.1823.51 变体）
  static const String douyuSearchUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51';

  /// 斗鱼：房间信息接口（Edg/114.0.1823.43 变体）
  static const String douyuRoomUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43';

  /// 虎牙：播放/页面请求（Android 移动端指纹）
  static const String huyaUserAgent =
      'Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.91 Mobile Safari/537.36 Edg/117.0.0.0';

  /// 虎牙：弹幕 WebSocket 的 HYSDK 客户端指纹
  static const String huyaHysdkUserAgent =
      'HYSDK(Windows, 30000002)_APP(pc_exe&7060000&official)_SDK(trans&2.32.3.5646)';

  /// 哔哩哔哩：默认请求
  static const String bilibiliUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0';

  /// 哔哩哔哩：房间信息接口（Edg/115 变体）
  static const String bilibiliRoomUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 Edg/115.0.1901.188';

  /// 抖音：QQBrowser 指纹（参考 DouyinLiveRecorder）
  static const String douyinUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.97 Safari/537.36 Core/1.116.567.400 QQBrowser/19.7.6764.400';

  /// 快手：网页请求
  static const String kuaishouUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 斗鱼 Passport：扫码登录与 safeAuth 续期请求
  static const String passportUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}
