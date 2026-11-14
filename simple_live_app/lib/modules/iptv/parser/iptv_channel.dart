/// IPTV 频道（M3U 解析结果，运行期数据，不入库）
class IptvChannel {
  /// 对应 tvg-id，用于和 EPG 关联；缺失时用播放地址兜底
  final String id;

  final String name;

  final String logo;

  final String group;

  /// 视频流直链
  final String url;

  const IptvChannel({
    required this.id,
    required this.name,
    required this.logo,
    required this.group,
    required this.url,
  });
}
