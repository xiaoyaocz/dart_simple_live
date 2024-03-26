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
    required this.special,
    required this.lastWatchTime,
    required this.lastPlayTime,
    required this.watchSecond,
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
  bool special;

  @HiveField(7)
  DateTime lastWatchTime;

  @HiveField(8)
  DateTime lastPlayTime;

  @HiveField(9)
  int watchSecond;

  /// 直播状态
  /// 0=未知(加载中) 1=未开播 2=直播中
  Rx<int> liveStatus = 0.obs;

  factory FollowUser.fromJson(Map<String, dynamic> json) => FollowUser(
        id: json['id'],
        roomId: json['roomId'],
        siteId: json['siteId'],
        userName: json['userName'],
        face: json['face'],
        addTime: DateTime.parse(json['addTime']),
        special: json.containsKey('special') ? json['special'] : false,
        lastWatchTime: json.containsKey('lastWatchTime')
            ? DateTime.parse(json['lastWatchTime'])
            : DateTime(2000),
        lastPlayTime: json.containsKey('lastPlayTime')
            ? DateTime.parse(json['lastPlayTime'])
            : DateTime(2000),
        watchSecond: json['watchSecond'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'siteId': siteId,
        'userName': userName,
        'face': face,
        'addTime': addTime.toString(),
      };
}
