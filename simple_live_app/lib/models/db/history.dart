import 'package:hive/hive.dart';
import 'package:simple_live_app/app/utils/duration_2_str_utils.dart';
import 'package:simple_live_app/app/utils/dynamic_filter.dart';

part 'history.g.dart';

@HiveType(typeId: 2)
class History implements Mappable {
  History({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.updateTime,
    this.watchDuration = "00:00:00",
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

  @HiveField(6)
  String? watchDuration; // "00:00:00"

  Duration get duration => watchDuration!.toDuration(); //for filter

  factory History.fromJson(Map<String, dynamic> json) => History(
        id: json["id"],
        roomId: json["roomId"],
        siteId: json["siteId"],
        userName: json["userName"],
        face: json["face"],
        updateTime: DateTime.parse(json["updateTime"]),
        watchDuration: json["watchDuration"] ?? "00:00:00",
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "roomId": roomId,
        "siteId": siteId,
        "userName": userName,
        "face": face,
        "updateTime": updateTime.toString(),
        "watchDuration": watchDuration ?? "00:00:00",
      };

  @override
  Map<String, dynamic> toMap() => toJson();
}
