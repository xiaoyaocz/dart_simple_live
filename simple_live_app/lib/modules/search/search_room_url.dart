import 'package:simple_live_app/app/constant.dart';

class SearchRoomUrl {
  /// 移动端强制使用桌面版 Chrome UA，避免四大平台跳手机 H5 页或诱导拉起外部 APP。
  static const desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  static const _allowedWebSchemes = {
    'http',
    'https',
    'about',
    'data',
    'blob',
    'javascript',
  };

  static const _blockedDownloadHosts = {
    'a.app.qq.com',
    'sj.qq.com',
    'app.huya.com',
    'dldir1.qq.com',
  };

  static const _huyaNonRoomSegments = {
    'search', 'index', 'g', 'all', 'video', 'match',
    'live', 'l', 'hot', 'home', 'category', 'zhubo', 'topic',
    'my', 'login', 'register', 'download', 'about', 'help',
    'feedback', 'activity', 'pc', 'm', 'rank', 'subscribe',
    'follow', 'message', 'notice', 'order', 'game', 'games',
    'i', 'u', 'profile', 'user', 'udb', 'auth', 'oauth', 'sso',
    'passport', 'verify',
  };

  static const _douyuNonRoomSegments = {
    'search', 'topic', 'directory', 'category',
    'member', 'login', 'register', 'client', 'download',
    'follow', 'my', 'message', 'center', 'room', 'u', 'i',
    'pages', 'beta', 'auth', 'oauth', 'sso', 'passport', 'verify',
  };

  static Uri homeUriFor(String siteId) {
    final host = switch (siteId) {
      Constant.kBiliBili => 'live.bilibili.com',
      Constant.kHuya => 'www.huya.com',
      Constant.kDouyu => 'www.douyu.com',
      Constant.kDouyin => 'live.douyin.com',
      _ => throw ArgumentError.value(siteId, 'siteId', '不支持的直播平台'),
    };
    return Uri.https(host, '/');
  }

  /// 判断是否为应拦截的外部 APP 唤醒协议或下载诱导链接。
  static bool isBlockedExternalScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isNotEmpty && !_allowedWebSchemes.contains(scheme)) {
      return true;
    }
    if (scheme == 'http' || scheme == 'https') {
      final host = uri.host.toLowerCase();
      if (_blockedDownloadHosts.contains(host)) return true;
      if (uri.path.toLowerCase().endsWith('.apk')) return true;
    }
    return false;
  }

  /// 将误跳的手机版网页地址转换为对应平台的电脑版网页地址。
  static Uri? desktopUriFor(String siteId, Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    switch (siteId) {
      case Constant.kHuya:
        if (uri.host == 'm.huya.com') {
          return Uri.https(
            'www.huya.com',
            uri.path.isEmpty ? '/' : uri.path,
            uri.queryParameters.isEmpty ? null : uri.queryParameters,
          );
        }
        return null;
      case Constant.kDouyu:
        if (uri.host == 'm.douyu.com') {
          return Uri.https(
            'www.douyu.com',
            uri.path.isEmpty ? '/' : uri.path,
            uri.queryParameters.isEmpty ? null : uri.queryParameters,
          );
        }
        return null;
      case Constant.kBiliBili:
        if (uri.host == 'm.bilibili.com' &&
            segments.length == 2 &&
            segments.first == 'live' &&
            RegExp(r'^\d+$').hasMatch(segments.last)) {
          return Uri.https('live.bilibili.com', '/${segments.last}');
        }
        if (uri.host == 'live.bilibili.com' &&
            segments.length == 2 &&
            segments.first == 'h5' &&
            RegExp(r'^\d+$').hasMatch(segments.last)) {
          return Uri.https('live.bilibili.com', '/${segments.last}');
        }
        return null;
      case Constant.kDouyin:
        if (uri.host == 'm.douyin.com' &&
            segments.length >= 3 &&
            segments[0] == 'share' &&
            segments[1] == 'live' &&
            RegExp(r'^\d+$').hasMatch(segments[2])) {
          return Uri.https('live.douyin.com', '/${segments[2]}');
        }
        return null;
      default:
        return null;
    }
  }

  static String? roomIdFor(String siteId, Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    switch (siteId) {
      case Constant.kBiliBili:
        String? id;
        if (uri.host == 'live.bilibili.com') {
          if (segments.length == 1) {
            id = segments.first;
          }
          if (segments.length == 2 &&
              {'h5', 'blanc'}.contains(segments.first)) {
            id = segments.last;
          }
        } else if (uri.host == 'm.bilibili.com' &&
            segments.length == 2 &&
            segments.first == 'live') {
          id = segments.last;
        }
        return id != null && RegExp(r'^\d+$').hasMatch(id) ? id : null;
      case Constant.kHuya:
        if (!{'www.huya.com', 'm.huya.com'}.contains(uri.host) ||
            segments.length != 1) {
          return null;
        }
        if (_huyaNonRoomSegments.contains(segments.first.toLowerCase())) {
          return null;
        }
        return _roomSlug(segments.first);
      case Constant.kDouyu:
        if (!{'www.douyu.com', 'm.douyu.com'}.contains(uri.host)) return null;
        if (segments.length == 2 && segments.first == 'beta') {
          return _roomSlug(segments.last);
        }
        if (segments.length == 2 &&
            {'topic', 'pages'}.contains(segments.first)) {
          final id = uri.queryParameters['rid'];
          return id != null && RegExp(r'^\d+$').hasMatch(id) ? id : null;
        }
        if (segments.length != 1 ||
            segments.first.startsWith('g_') ||
            _douyuNonRoomSegments.contains(segments.first.toLowerCase())) {
          return null;
        }
        return _roomSlug(segments.first);
      case Constant.kDouyin:
        if (uri.host == 'www.douyin.com' &&
            segments.length == 3 &&
            {'root', 'follow'}.contains(segments[0]) &&
            segments[1] == 'live') {
          return RegExp(r'^\d+$').hasMatch(segments[2]) ? segments[2] : null;
        }
        if (uri.host == 'm.douyin.com' &&
            segments.length >= 3 &&
            segments[0] == 'share' &&
            segments[1] == 'live') {
          return RegExp(r'^\d+$').hasMatch(segments[2]) ? segments[2] : null;
        }
        if (uri.host == 'webcast.amemv.com' &&
            segments.length >= 4 &&
            segments[0] == 'douyin' &&
            segments[1] == 'webcast' &&
            segments[2] == 'reflow') {
          return RegExp(r'^\d+$').hasMatch(segments[3]) ? segments[3] : null;
        }
        if (uri.host != 'live.douyin.com' || segments.length != 1) return null;
        return RegExp(r'^\d+$').hasMatch(segments.first)
            ? segments.first
            : null;
      default:
        return null;
    }
  }

  static String? _roomSlug(String value) {
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value) ? value : null;
  }
}
