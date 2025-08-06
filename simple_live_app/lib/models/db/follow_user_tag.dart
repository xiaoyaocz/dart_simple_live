import 'package:hive/hive.dart';

part 'follow_user_tag.g.dart';

@HiveType(typeId: 3)
class FollowUserTag {
  @HiveField(1)
  String id;

  // 用户自定义tag
  @HiveField(2)
  String tag;

  // followUserId
  @HiveField(3)
  List<String> userId;

  FollowUserTag({
    required this.id,
    required this.tag,
    required this.userId,
  });

  factory FollowUserTag.fromJson(Map<String, dynamic> json) {
    return FollowUserTag(
      id: json['id'],
      tag: json['tag'],
      userId: List<String>.from(json['userId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag': tag,
      'userId': userId,
    };
  }

  FollowUserTag copyWith({
    String? id,
    String? tag,
    List<String>? userId,
  }) {
    return FollowUserTag(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      userId: userId ?? this.userId,
    );
  }
}