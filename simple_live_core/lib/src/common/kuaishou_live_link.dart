class KuaishouLiveLink {
  static final RegExp _roomIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  static Uri? publicRoomUri(String roomId) {
    final normalized = roomId.trim();
    if (!_roomIdPattern.hasMatch(normalized)) {
      return null;
    }
    return Uri(
      scheme: "https",
      host: "live.kuaishou.com",
      pathSegments: ["u", normalized],
    );
  }

  static Uri? parseHttpUrl(String value) {
    final text = value.trim();
    var uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      final normalized = Uri.tryParse("https://$text");
      if (normalized == null || !_isKnownHost(normalized)) {
        return null;
      }
      uri = normalized;
    }
    return isHttpUri(uri) && _isKnownHost(uri) ? uri : null;
  }

  static bool _isKnownHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == "v.kuaishou.com" ||
        host == "live.kuaishou.com" ||
        host == "m.chenzhongtech.com" ||
        host.endsWith(".m.chenzhongtech.com");
  }

  static bool isHttpUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return uri.userInfo.isEmpty &&
        uri.host.isNotEmpty &&
        (scheme == "http" || scheme == "https");
  }

  static bool isShortLink(Uri uri) {
    return isHttpUri(uri) && uri.host.toLowerCase() == "v.kuaishou.com";
  }

  static bool isTrustedRedirectTarget(Uri uri) {
    return isShortLink(uri) || roomIdFromUri(uri) != null;
  }

  static String? roomIdFromUri(Uri uri) {
    if (!isHttpUri(uri)) {
      return null;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final host = uri.host.toLowerCase();
    final isLiveHost = host == "live.kuaishou.com";
    final isMobileLiveHost =
        host == "m.chenzhongtech.com" || host.endsWith(".m.chenzhongtech.com");
    final roomId = isLiveHost && segments.length == 2 && segments[0] == "u"
        ? segments[1]
        : isMobileLiveHost &&
              segments.length == 3 &&
              segments[0] == "fw" &&
              segments[1] == "live"
        ? segments[2]
        : "";
    return _roomIdPattern.hasMatch(roomId) ? roomId : null;
  }
}
