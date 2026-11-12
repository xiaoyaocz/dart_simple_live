import 'iptv_channel.dart';

/// M3U 解析结果：频道列表与头部声明的 EPG 地址（url-tvg）
class M3uParseResult {
  final List<IptvChannel> channels;
  final List<String> epgUrls;

  const M3uParseResult({required this.channels, required this.epgUrls});
}

class M3uParser {
  static const String defaultGroup = "未分组";

  static final RegExp _attrReg = RegExp(r'([a-zA-Z0-9-]+)="([^"]*)"');

  static M3uParseResult parse(String content, {String? baseUrl}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <IptvChannel>[];
    final epgUrls = <String>[];

    // 待与下一条播放地址配对的 EXTINF 信息
    Map<String, String>? pendingAttrs;
    String pendingName = "";
    String pendingGroup = "";

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith("#EXTM3U")) {
        // 头部可声明一个或多个 url-tvg
        for (final match in _attrReg.allMatches(line)) {
          if (match.group(1) == "url-tvg") {
            final value = match.group(2)!.trim();
            if (value.isNotEmpty) epgUrls.add(_resolve(value, baseUrl));
          }
        }
        continue;
      }

      if (line.startsWith("#EXTINF")) {
        final attrs = <String, String>{};
        for (final match in _attrReg.allMatches(line)) {
          attrs[match.group(1)!] = match.group(2)!;
        }
        final comma = _findNameSeparator(line);
        pendingAttrs = attrs;
        pendingName = comma >= 0 ? line.substring(comma + 1).trim() : "";
        continue;
      }

      if (line.startsWith("#EXTGRP")) {
        pendingGroup = line.split(":").last.trim();
        continue;
      }

      if (line.startsWith("#")) continue;

      final url = _resolve(line, baseUrl);
      final attrs = pendingAttrs ?? const <String, String>{};
      final group = (attrs["group-title"]?.trim().isNotEmpty ?? false)
          ? attrs["group-title"]!.trim()
          : (pendingGroup.isNotEmpty ? pendingGroup : defaultGroup);
      final tvgId = attrs["tvg-id"]?.trim() ?? "";
      channels.add(
        IptvChannel(
          id: tvgId.isNotEmpty ? tvgId : url,
          name: pendingName.isNotEmpty ? pendingName : url,
          logo: _resolve(attrs["tvg-logo"] ?? "", baseUrl),
          group: group,
          url: url,
        ),
      );
      pendingAttrs = null;
      pendingName = "";
      pendingGroup = "";
    }

    return M3uParseResult(channels: channels, epgUrls: epgUrls);
  }

  /// EXTINF 频道名分隔逗号：属性值（引号内）可能含逗号，取引号外的首个逗号
  static int _findNameSeparator(String line) {
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        return i;
      }
    }
    return -1;
  }

  /// 相对地址按订阅源 URL 补全，绝对地址原样返回
  static String _resolve(String url, String? baseUrl) {
    final value = url.trim();
    if (value.isEmpty || baseUrl == null) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme) return value;
    return Uri.parse(baseUrl).resolve(value).toString();
  }
}
