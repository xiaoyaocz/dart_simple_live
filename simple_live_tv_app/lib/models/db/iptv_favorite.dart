import 'package:hive/hive.dart';

part 'iptv_favorite.g.dart';

@HiveType(typeId: 5)
class IptvFavorite {
  IptvFavorite({
    required this.id,
    required this.playlistId,
    required this.channelId,
    required this.name,
    required this.logo,
    required this.group,
    required this.url,
    this.sourceName = "",
  });

  /// 唯一键：订阅源 id + 频道地址，避免跨源冲突
  @HiveField(0)
  String id;

  @HiveField(1)
  String playlistId;

  /// 对应 tvg-id
  @HiveField(2)
  String channelId;

  @HiveField(3)
  String name;

  @HiveField(4)
  String logo;

  @HiveField(5)
  String group;

  @HiveField(6)
  String url;

  /// 收藏线路所属的源名称，用于同步还原对应源的频道
  @HiveField(7)
  String sourceName;

  factory IptvFavorite.fromJson(Map<String, dynamic> json) {
    final playlistId = json["playlistId"]?.toString() ?? "";
    final url = json["url"]?.toString() ?? "";
    return IptvFavorite(
      id: json["id"]?.toString().isNotEmpty == true
          ? json["id"].toString()
          : "${playlistId}_$url",
      playlistId: playlistId,
      channelId: json["channelId"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      logo: json["logo"]?.toString() ?? "",
      group: json["group"]?.toString() ?? "",
      url: url,
      sourceName: json["sourceName"]?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "playlistId": playlistId,
        "channelId": channelId,
        "name": name,
        "logo": logo,
        "group": group,
        "url": url,
        "sourceName": sourceName,
      };
}
