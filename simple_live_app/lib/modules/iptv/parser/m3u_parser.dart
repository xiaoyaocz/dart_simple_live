import 'province_mapper.dart';
import 'iptv_channel.dart';

/// M3U 解析结果：频道列表
class M3uParseResult {
  final List<IptvChannel> channels;

  const M3uParseResult({required this.channels});
}

class M3uParser {
  static const String defaultGroup = "未分组";

  static final RegExp _attrReg = RegExp(r'([a-zA-Z0-9-]+)="([^"]*)"');

  static M3uParseResult parse(String content, {String? baseUrl}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <IptvChannel>[];

    // 兼容TXT格式直播源，自动识别分组标记
    if (!content.contains("#EXTM3U") && content.contains("#genre#")) {
      var currentGroup = defaultGroup;
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        if (line.endsWith("#genre#")) {
          currentGroup = line.replaceAll("#genre#", "").trim();
          continue;
        }
        final commaIndex = line.indexOf(",");
        if (commaIndex <= 0) continue;
        final name = line.substring(0, commaIndex).trim();
        final url = _resolve(line.substring(commaIndex + 1).trim(), baseUrl);
        channels.add(IptvChannel(
          id: url,
          name: name,
          logo: "",
          group: currentGroup,
          url: url,
        ));
      }
    } else {
      // 待与下一条播放地址配对的 EXTINF 信息
      Map<String, String>? pendingAttrs;
      String pendingName = "";
      String pendingGroup = "";

      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;

        if (line.startsWith("#EXTM3U")) continue;

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
    }

    // 拆分地方频道为省份分组
    final processedChannels = channels.map((channel) {
      if (channel.group != "地方频道") return channel;
      final province = ProvinceMapper.matchProvince(channel.name);
      return IptvChannel(
        id: channel.id,
        name: channel.name,
        logo: channel.logo,
        group: province != null ? "$province地方台" : "其他地方台",
        url: channel.url,
      );
    }).toList();

    return M3uParseResult(channels: processedChannels);
  }

  /// EXTINF 频道名分隔逗号：属性值（引号内）可能含逗号，取引号外最后一个逗号，兼容-1后多余逗号的异常格式
  static int _findNameSeparator(String line) {
    var inQuotes = false;
    var lastComma = -1;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        lastComma = i;
      }
    }
    return lastComma;
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
