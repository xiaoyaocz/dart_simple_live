import 'dart:convert';

class LiveRoomItem {
  /// 房间ID
  final String roomId;

  /// 标题
  final String title;

  /// 封面
  final String cover;

  /// 用户名
  final String userName;

  /// 人气/在线人数
  final int online;
  LiveRoomItem({
    required this.roomId,
    required this.title,
    required this.cover,
    required this.userName,
    this.online = 0,
  });

  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "title": title,
      "cover": cover,
      "userName": userName,
      "online": online,
    });
  }
}
