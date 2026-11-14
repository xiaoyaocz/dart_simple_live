import 'package:get/get.dart';
import 'package:hive/hive.dart';

part 'follow_user.g.dart';

@HiveType(typeId: 1)
class FollowUser {
  FollowUser(
      {required this.id,
      required this.roomId,
      required this.siteId,
      required this.userName,
      required this.face,
      required this.addTime,
      this.tag = "全部",
      this.isSpecialFollow = false,
      this.roomTitle = "",
      this.roomCover = "",
      this.previewUpdatedAt});

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
  String tag;

  @HiveField(7)
  bool isSpecialFollow;

  @HiveField(8)
  String roomTitle;

  @HiveField(9)
  String roomCover;

  @HiveField(10)
  DateTime? previewUpdatedAt;

  /// 直播状态
  /// 0=未知(加载中) 1=未开播 2=直播中
  Rx<int> liveStatus = 0.obs;

  /// 开播时间戳
  String? liveStartTime;

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    final roomId = json['roomId']?.toString().trim() ?? "";
    final siteId = json['siteId']?.toString().trim() ?? "";
    final id = (json['id']?.toString().trim().isNotEmpty ?? false)
        ? json['id'].toString().trim()
        : "${siteId}_$roomId";
    final tagValue = json["tag"]?.toString().trim();
    return FollowUser(
      id: id,
      roomId: roomId,
      siteId: siteId,
      userName: json['userName']?.toString() ?? "",
      face: json['face']?.toString() ?? "",
      addTime: DateTime.tryParse(json['addTime']?.toString() ?? "") ??
          DateTime.now(),
      tag: tagValue?.isNotEmpty == true ? tagValue! : "全部",
      isSpecialFollow:
          json["isSpecialFollow"] == true || json["isSpecialFollow"] == 1,
      roomTitle: json["roomTitle"]?.toString() ?? "",
      roomCover: json["roomCover"]?.toString() ?? "",
      previewUpdatedAt:
          DateTime.tryParse(json["previewUpdatedAt"]?.toString() ?? ""),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'siteId': siteId,
        'userName': userName,
        'face': face,
        'addTime': addTime.toString(),
        'tag': tag,
        'isSpecialFollow': isSpecialFollow,
        'roomTitle': roomTitle,
        'roomCover': roomCover,
        'previewUpdatedAt': previewUpdatedAt?.toIso8601String() ?? "",
      };
}
