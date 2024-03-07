import 'package:hive/hive.dart';

part 'history.g.dart';

@HiveType(typeId: 2)
class History {
  History({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.updateTime,
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
  DateTime updateTime;

  factory History.fromJson(Map<String, dynamic> json) => History(
        id: json["id"],
        roomId: json["roomId"],
        siteId: json["siteId"],
        userName: json["userName"],
        face: json["face"],
        updateTime: DateTime.parse(json["updateTime"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "roomId": roomId,
        "siteId": siteId,
        "userName": userName,
        "face": face,
        "updateTime": updateTime.toString(),
      };
}
