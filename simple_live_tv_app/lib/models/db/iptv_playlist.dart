import 'package:hive/hive.dart';

part 'iptv_playlist.g.dart';

@HiveType(typeId: 4)
class IptvPlaylist {
  /// 远程订阅（URL）
  static const int typeRemote = 0;

  /// 本地文件（文件路径）
  static const int typeLocal = 1;

  IptvPlaylist({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.updateTime,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// 远程为订阅地址，本地为文件路径
  @HiveField(2)
  String url;

  @HiveField(3)
  int type;

  @HiveField(4)
  DateTime updateTime;

  bool get isLocal => type == typeLocal;

  factory IptvPlaylist.fromJson(Map<String, dynamic> json) {
    return IptvPlaylist(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      url: json["url"]?.toString() ?? "",
      type: (json["type"] as num?)?.toInt() ?? typeRemote,
      updateTime: DateTime.tryParse(json["updateTime"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "url": url,
        "type": type,
        "updateTime": updateTime.toIso8601String(),
      };
}
