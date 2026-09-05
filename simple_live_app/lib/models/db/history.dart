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

  factory History.fromJson(Map<String, dynamic> json) {
    final roomId = json["roomId"]?.toString().trim() ?? "";
    final siteId = json["siteId"]?.toString().trim() ?? "";
    final id = (json["id"]?.toString().trim().isNotEmpty ?? false)
        ? json["id"].toString().trim()
        : "${siteId}_$roomId";
    return History(
      id: id,
      roomId: roomId,
      siteId: siteId,
      userName: json["userName"]?.toString() ?? "",
      face: json["face"]?.toString() ?? "",
      updateTime: DateTime.tryParse(json["updateTime"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "roomId": roomId,
        "siteId": siteId,
        "userName": userName,
        "face": face,
        "updateTime": updateTime.toString(),
      };
}
