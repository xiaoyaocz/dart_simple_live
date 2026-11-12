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
      };
}
