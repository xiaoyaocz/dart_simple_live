class LiveAnchorItem {
  /// 房间ID
  final String roomId;

  /// 封面
  final String avatar;

  /// 用户名
  final String userName;

  /// 直播中
  final bool liveStatus;

  LiveAnchorItem({
    required this.roomId,
    required this.avatar,
    required this.userName,
    required this.liveStatus,
  });
}
