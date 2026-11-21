import 'package:hive/hive.dart';

part 'iptv_tag.g.dart';

/// IPTV 收藏标签：标签持有收藏 id 列表，对齐关注页 FollowUserTag 的组织方式
@HiveType(typeId: 6)
class IptvTag {
  @HiveField(1)
  String id;

  @HiveField(2)
  String tag;

  @HiveField(3)
  List<String> favoriteIds;

  IptvTag({
    required this.id,
    required this.tag,
    required this.favoriteIds,
  });

  factory IptvTag.fromJson(Map<String, dynamic> json) {
    final rawIds = json['favoriteIds'];
    return IptvTag(
      id: json['id']?.toString().trim() ?? "",
      tag: json['tag']?.toString().trim() ?? "",
      favoriteIds: rawIds is List ? rawIds.map((e) => e.toString()).toList() : <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'favoriteIds': favoriteIds,
      };

  IptvTag copyWith({
    String? id,
    String? tag,
    List<String>? favoriteIds,
  }) {
    return IptvTag(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      favoriteIds: favoriteIds ?? this.favoriteIds,
    );
  }
}
