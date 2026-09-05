class DouyinCookieHelper {
  static bool hasCustomCookie(String cookie) {
    return cookie.trim().isNotEmpty;
  }

  static bool isOnlyTtwid(String cookie) {
    final normalized = cookie.trim().toLowerCase();
    return normalized.startsWith("ttwid=") && !normalized.contains(";");
  }

  static bool hasFullCookie(String cookie) {
    final normalized = cookie.trim();
    return normalized.isNotEmpty && !isOnlyTtwid(normalized);
  }

  /// Returns the minimum anonymous playback cookie from a Cookie header.
  ///
  /// Room and playback endpoints do not need an account session. Keeping only
  /// [ttwid] prevents unrelated account cookies from being sent to them.
  static String? extractTtwid(String cookie) {
    var value = extractCookieFromHeaderText(cookie) ?? cookie.trim();
    if (value.toLowerCase().startsWith("cookie:")) {
      value = value.substring(value.indexOf(":") + 1).trim();
    }
    for (final part in value.split(";")) {
      final item = part.trim();
      final separatorIndex = item.indexOf("=");
      if (separatorIndex <= 0) {
        continue;
      }
      final key = item.substring(0, separatorIndex).trim().toLowerCase();
      final cookieValue = item.substring(separatorIndex + 1).trim();
      if (key == "ttwid" && cookieValue.isNotEmpty) {
        return "ttwid=$cookieValue";
      }
    }
    return null;
  }

  static String cookieCompletenessHint(String cookie) {
    final normalized = cookie.trim();
    if (normalized.isEmpty) {
      return "未配置 Cookie";
    }
    if (isOnlyTtwid(normalized)) {
      return "仅检测到 ttwid，播放通常可用，但抖音关注状态可能需要完整 Cookie";
    }
    final lower = normalized.toLowerCase();
    final hasDouyinIdentity =
        lower.contains('sessionid=') ||
        lower.contains('sid_guard=') ||
        lower.contains('passport_csrf_token=') ||
        lower.contains('passport_csrf_token_default=') ||
        lower.contains('mstoken=') ||
        lower.contains('odin_tt=') ||
        lower.contains('passport_auth_status=') ||
        lower.contains('__ac_nonce=') ||
        lower.contains('__ac_signature=') ||
        lower.contains('ttwid=');
    if (hasDouyinIdentity) {
      return "已检测到非纯 ttwid Cookie，可用于登录态刷新；若仍失败，可能是 Cookie 过期或抖音风控";
    }
    return "已保存自定义 Cookie，但未识别到典型登录字段；若刷新失败，建议重新从浏览器复制完整 Request Headers";
  }

  static String normalizeInput(String input) {
    var cookie = extractCookieFromHeaderText(input) ?? input.trim();
    if (cookie.toLowerCase().startsWith("cookie:")) {
      cookie = cookie.substring(cookie.indexOf(":") + 1).trim();
    }
    if (!cookie.contains("=")) {
      cookie = 'ttwid=$cookie';
    }
    return cookie;
  }

  static String? extractCookieFromHeaderText(String input) {
    final lines = input
        .split(RegExp(r"\r?\n"))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (lower.startsWith("cookie:")) {
        return line.substring(line.indexOf(":") + 1).trim();
      }
      if (lower == "cookie" && i + 1 < lines.length) {
        return lines[i + 1].trim();
      }
    }
    return null;
  }
}
