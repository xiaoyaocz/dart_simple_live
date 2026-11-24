import 'package:hive/hive.dart';

part 'follow_user_tag.g.dart';

/// 自定义关注标签，与手机端 simple_live_app 的 FollowUserTag 对齐
/// 注意：typeId 3，TV 端仅 1(FollowUser)/2(History) 已占用
@HiveType(typeId: 3)
class FollowUserTag {
  FollowUserTag({
    required this.id,
    required this.tag,
    required this.userId,
  });

  @HiveField(1)
  String id;

  @HiveField(2)
  String tag;

  @HiveField(3)
  List<String> userId;

  factory FollowUserTag.fromJson(Map<String, dynamic> json) {
    final rawIds = json['userId'];
    return FollowUserTag(
      id: json['id']?.toString() ?? "",
      tag: json['tag']?.toString() ?? "",
      userId: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'userId': userId,
      };

  FollowUserTag copyWith({
    String? id,
    String? tag,
    List<String>? userId,
  }) {
    return FollowUserTag(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      userId: userId ?? List<String>.from(this.userId),
    );
  }
}
