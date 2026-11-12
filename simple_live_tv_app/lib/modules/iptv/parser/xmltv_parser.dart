import 'package:xml/xml.dart';

import 'iptv_program.dart';

class XmltvParser {
  /// 解析 XMLTV 文本，返回按频道索引的节目数据
  static EpgData parse(String content) {
    final tv = XmlDocument.parse(content).getElement("tv");
    final result = <String, List<IptvProgram>>{};
    if (tv == null) return const EpgData({});

    for (final node in tv.findAllElements("programme")) {
      final channelId = node.getAttribute("channel")?.trim() ?? "";
      final start = parseTime(node.getAttribute("start") ?? "");
      final stop = parseTime(node.getAttribute("stop") ?? "");
      if (channelId.isEmpty || start == null || stop == null) continue;

      final program = IptvProgram(
        channelId: channelId,
        start: start,
        stop: stop,
        title: _firstText(node, "title"),
        desc: _firstText(node, "desc"),
      );
      result.putIfAbsent(channelId, () => <IptvProgram>[]).add(program);
    }

    for (final list in result.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return EpgData(result);
  }

  /// 解析 XMLTV 时间：YYYYMMDDHHMMSS +HHMM，统一转 UTC
  static DateTime? parseTime(String raw) {
    final value = raw.trim();
    if (value.length < 14) return null;
    int part(int start, int end) => int.parse(value.substring(start, end));

    final wallTime = DateTime.utc(
      part(0, 4),
      part(4, 6),
      part(6, 8),
      part(8, 10),
      part(10, 12),
      part(12, 14),
    );

    // 时区偏移缺省视为 UTC
    final tz = value.substring(14).replaceAll(" ", "");
    if (tz.length < 5) return wallTime;
    final sign = tz.startsWith("-") ? -1 : 1;
    final offset = Duration(
      hours: int.parse(tz.substring(1, 3)),
      minutes: int.parse(tz.substring(3, 5)),
    ) * sign;
    return wallTime.subtract(offset);
  }

  /// 取首个同名子元素的文本，缺失返回空串
  static String _firstText(XmlElement node, String name) {
    return node.findElements(name).firstOrNull?.innerText.trim() ?? "";
  }
}
