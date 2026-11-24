import 'package:get/get.dart';
import 'package:hive/hive.dart';

part 'follow_user.g.dart';

@HiveType(typeId: 1)
class FollowUser {
  FollowUser({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.addTime,
    this.isSpecialFollow = false,
    this.roomTitle = "",
    this.roomCover = "",
    this.previewUpdatedAt,
    this.tag = "全部",
  });

  ///id=siteId_roomId
  @HiveField(0)
  String id;

  @HiveField(1)
  String roomId;

  @HiveField(2)
  String siteId;

  @HiveField(3)
  String userName;

  @HiveField(4)
  String face;

  @HiveField(5)
  DateTime addTime;

  @HiveField(6)
  bool isSpecialFollow;

  @HiveField(7)
  String roomTitle;

  @HiveField(8)
  String roomCover;

  @HiveField(9)
  DateTime? previewUpdatedAt;

  @HiveField(10)
  String tag;

  /// 直播状态
  /// 0=未知(加载中) 1=未开播 2=直播中
  Rx<int> liveStatus = 0.obs;

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    final roomId = json['roomId']?.toString().trim() ?? "";
    final siteId = json['siteId']?.toString().trim() ?? "";
    final id = (json['id']?.toString().trim().isNotEmpty ?? false)
        ? json['id'].toString().trim()
        : "${siteId}_$roomId";
    return FollowUser(
      id: id,
      roomId: roomId,
      siteId: siteId,
      userName: json['userName']?.toString() ?? "",
      face: json['face']?.toString() ?? "",
      addTime: DateTime.tryParse(json['addTime']?.toString() ?? "") ??
          DateTime.now(),
      isSpecialFollow:
          json["isSpecialFollow"] == true || json["isSpecialFollow"] == 1,
      roomTitle: json["roomTitle"]?.toString() ?? "",
      roomCover: json["roomCover"]?.toString() ?? "",
      previewUpdatedAt:
          DateTime.tryParse(json["previewUpdatedAt"]?.toString() ?? ""),
      tag: (json["tag"]?.toString().trim().isNotEmpty ?? false)
          ? json["tag"].toString().trim()
          : "全部",
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'siteId': siteId,
        'userName': userName,
        'face': face,
        'addTime': addTime.toString(),
        'isSpecialFollow': isSpecialFollow,
        'roomTitle': roomTitle,
        'roomCover': roomCover,
        'previewUpdatedAt': previewUpdatedAt?.toIso8601String() ?? "",
        'tag': tag,
      };
}
