/// 单条播放线路：对应一个源的频道地址
class IptvLine {
  /// 所属源名称
  final String sourceName;
  /// 播放地址
  final String url;
  /// 线路logo
  final String logo;
  /// 源内频道 id
  final String channelId;

  const IptvLine({
    required this.sourceName,
    required this.url,
    required this.logo,
    required this.channelId,
  });
}

/// 跨源聚合后的频道：同名频道合并，包含所有可用线路
class AggregatedChannel {
  final String name;
  final String group;
  final String logo;
  final List<IptvLine> lines;

  const AggregatedChannel({
    required this.name,
    required this.group,
    required this.logo,
    required this.lines,
  });

  /// 获取所有支持该频道的源名称，去重
  List<String> get sourceNames =>
      lines.map((e) => e.sourceName).toSet().toList();

  /// 默认取第一条线路播放
  IptvLine get defaultLine => lines.first;
}

/// 聚合解析结果
class AggregatedParseResult {
  final List<AggregatedChannel> channels;

  const AggregatedParseResult({required this.channels});
}
