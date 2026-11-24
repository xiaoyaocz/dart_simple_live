/// 自动换台轮播列表成员（#154）。
/// 跨平台房间快照，独立于关注生命周期存储：
/// 取关不影响轮播成员，后续也可从搜索等入口直接添加。
class AutoSwitchListItem {
  String siteId;
  String roomId;
  String userName;

  AutoSwitchListItem({
    required this.siteId,
    required this.roomId,
    required this.userName,
  });

  /// 稳定唯一标识，与关注项的 "siteId_roomId" 形态一致
  String get id => "${siteId}_$roomId";

  Map<String, dynamic> toJson() => {
        "siteId": siteId,
        "roomId": roomId,
        "userName": userName,
      };

  factory AutoSwitchListItem.fromJson(Map<String, dynamic> json) {
    return AutoSwitchListItem(
      siteId: json["siteId"]?.toString() ?? "",
      roomId: json["roomId"]?.toString() ?? "",
      userName: json["userName"]?.toString() ?? "",
    );
  }
}
