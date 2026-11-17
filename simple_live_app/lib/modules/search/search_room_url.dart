import 'package:simple_live_app/app/constant.dart';

class SearchRoomUrl {
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
          if (segments.length == 2 && {'h5', 'blanc'}.contains(segments.first)) {
            id = segments.last;
          }
        } else if (uri.host == 'm.bilibili.com' &&
            segments.length == 2 && segments.first == 'live') {
          id = segments.last;
        }
        return id != null && RegExp(r'^\d+$').hasMatch(id) ? id : null;
      case Constant.kHuya:
        if (!{'www.huya.com', 'm.huya.com'}.contains(uri.host) ||
            segments.length != 1) {
          return null;
        }
        if ({
          'search', 'index', 'g', 'all', 'video', 'match',
          'live', 'l', 'hot', 'home', 'category', 'zhubo', 'topic',
        }.contains(segments.first)) {
          return null;
        }
        return _roomSlug(segments.first);
      case Constant.kDouyu:
        if (!{'www.douyu.com', 'm.douyu.com'}.contains(uri.host)) return null;
        if (segments.length == 2 && segments.first == 'topic') {
          final id = uri.queryParameters['rid'];
          return id != null && RegExp(r'^\d+$').hasMatch(id) ? id : null;
        }
        if (segments.length != 1 ||
            segments.first.startsWith('g_') ||
            {'search', 'topic', 'directory', 'category'}
                .contains(segments.first)) {
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
