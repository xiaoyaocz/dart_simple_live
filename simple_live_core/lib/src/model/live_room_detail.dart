import 'dart:convert';

class LiveRoomDetail {
  /// 房间ID
  final String roomId;

  /// 房间标题
  final String title;

  /// 封面
  final String cover;

  /// 用户名
  final String userName;

  /// 头像
  final String userAvatar;

  /// 在线
  final int online;

  /// 介绍
  final String? introduction;

  /// 公告
  final String? notice;

  /// 状态
  final bool status;

  /// 附加信息
  final dynamic data;

  /// 弹幕附加信息
  final dynamic danmakuData;

  /// 是否录播
  final bool isRecord;

  /// 链接
  final String url;

  /// 显示时间
  final String? showTime;

  /// 当前直播间所属的游戏分类 ID
  final String? categoryId;

  /// 当前直播间所属的游戏分类名称
  final String? categoryName;

  /// 网页原始分区路径的最深名称，供关注分类使用。
  final String? leafCategoryName;
  /// 网页路径中叶子标题缺失时可回退的上级名称。
  final String? webParentCategoryName;

  LiveRoomDetail({
    required this.roomId,
    required this.title,
    required this.cover,
    required this.userName,
    required this.userAvatar,
    required this.online,
    this.introduction,
    this.notice,
    required this.status,
    this.data,
    this.danmakuData,
    required this.url,
    this.isRecord = false,
    this.showTime,
    this.categoryId,
    this.categoryName,
    this.leafCategoryName,
    this.webParentCategoryName,
  });

  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "title": title,
      "cover": cover,
      "userName": userName,
      "userAvatar": userAvatar,
      "online": online,
      "introduction": introduction,
      "notice": notice,
      "status": status,
      "data": data.toString(),
      "danmakuData": danmakuData.toString(),
      "url": url,
      "isRecord": isRecord,
      "showTime": showTime,
    });
  }
}
