import 'kuaishou_live_link.dart';

/// 直播间链接解析结果。
///
/// [isShortLink] 为 true 时 [roomId] 为空，调用方需先跟随短链重定向，
/// 再对最终地址重新调用 [LiveUrlParser.parse]。
class LiveParsedUrl {
  final String siteId;
  final String roomId;
  final bool isShortLink;
  final Uri uri;

  const LiveParsedUrl({
    required this.siteId,
    required this.uri,
    this.roomId = "",
    this.isShortLink = false,
  });
}

/// 直播间链接解析：按 host + path 段提取站点与房间号。
///
/// 房间号作为完整 path 段校验，而不是从原始字符串里正则截取，
/// 因此含 "." 等字符的房间号不会被截断；host 一律小写匹配。
class LiveUrlParser {
  /// 站点 id，与 App 端 Constant 中的 k* 常量保持一致。
  static const String siteBilibili = "bilibili";
  static const String siteDouyu = "douyu";
  static const String siteHuya = "huya";
  static const String siteDouyin = "douyin";
  static const String siteKuaishou = "kuaishou";

  static final RegExp _roomIdPattern = RegExp(r'^[A-Za-z0-9._-]+$');
  static final RegExp _numericRoomIdPattern = RegExp(r'^\d+$');

  /// 解析直播间链接，无法识别时返回 null。
  static LiveParsedUrl? parse(String value) {
    final uri = _parseUri(value);
    if (uri == null) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

    // 短链：必须先跟随重定向，无法直接提取房间号。
    if (host == "b23.tv") {
      return LiveParsedUrl(siteId: siteBilibili, uri: uri, isShortLink: true);
    }
    if (host == "v.douyin.com") {
      return LiveParsedUrl(siteId: siteDouyin, uri: uri, isShortLink: true);
    }
    if (host == "v.kuaishou.com") {
      return LiveParsedUrl(siteId: siteKuaishou, uri: uri, isShortLink: true);
    }

    if (host == "live.kuaishou.com" ||
        host == "m.chenzhongtech.com" ||
        host.endsWith(".m.chenzhongtech.com")) {
      final roomId = KuaishouLiveLink.roomIdFromUri(uri);
      return roomId == null
          ? null
          : LiveParsedUrl(siteId: siteKuaishou, roomId: roomId, uri: uri);
    }

    if (host == "live.bilibili.com") {
      if (segments.isEmpty) {
        return null;
      }
      return _room(siteBilibili, segments.first, uri);
    }

    // 斗鱼 topic 页面的房间号在 rid 参数里。
    if (host == "douyu.com" || host.endsWith(".douyu.com")) {
      if (segments.isNotEmpty && segments.first == "topic") {
        return _numericRoom(siteDouyu, uri.queryParameters["rid"] ?? "", uri);
      }
      if (segments.isEmpty) {
        return null;
      }
      return _room(siteDouyu, segments.first, uri);
    }

    if (host == "huya.com" || host.endsWith(".huya.com")) {
      if (segments.isEmpty) {
        return null;
      }
      return _room(siteHuya, segments.first, uri);
    }

    if (host == "live.douyin.com") {
      if (segments.isEmpty) {
        return null;
      }
      return _room(siteDouyin, segments.first, uri);
    }

    // www.douyin.com/live/<webRid> 与 www.douyin.com/follow/live/<webRid>
    if (host == "douyin.com" || host.endsWith(".douyin.com")) {
      String? webRid;
      if (segments.length == 2 && segments[0] == "live") {
        webRid = segments[1];
      } else if (segments.length == 3 &&
          segments[0] == "follow" &&
          segments[1] == "live") {
        webRid = segments[2];
      }
      return webRid == null ? null : _room(siteDouyin, webRid, uri);
    }

    // webcast.amemv.com/.../reflow/<roomId>
    if (host.endsWith(".amemv.com")) {
      final reflowIndex = segments.indexOf("reflow");
      if (reflowIndex < 0 || reflowIndex + 1 >= segments.length) {
        return null;
      }
      return _numericRoom(siteDouyin, segments[reflowIndex + 1], uri);
    }

    return null;
  }

  static Uri? _parseUri(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    var uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      // 容忍不带协议头的 "live.douyin.com/123" 形式。
      uri = Uri.tryParse("https://$text");
    }
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != "http" && scheme != "https") {
      return null;
    }
    return uri;
  }

  static LiveParsedUrl? _room(String siteId, String roomId, Uri uri) {
    return _roomIdPattern.hasMatch(roomId)
        ? LiveParsedUrl(siteId: siteId, roomId: roomId, uri: uri)
        : null;
  }

  static LiveParsedUrl? _numericRoom(String siteId, String roomId, Uri uri) {
    return _numericRoomIdPattern.hasMatch(roomId)
        ? LiveParsedUrl(siteId: siteId, roomId: roomId, uri: uri)
        : null;
  }
}
