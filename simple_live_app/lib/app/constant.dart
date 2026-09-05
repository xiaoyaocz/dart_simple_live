import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

class Constant {
  static const String kUpdateFollow = "UpdateFollow";
  static const String kUpdateHistory = "UpdateHistory";

  static final Map<String, HomePageItem> allHomePages = {
    "recommend": HomePageItem(
      iconData: Remix.home_smile_line,
      title: "首页",
      index: 0,
    ),
    "follow": HomePageItem(
      iconData: Remix.heart_line,
      title: "关注",
      index: 1,
    ),
    "category": HomePageItem(
      iconData: Remix.apps_line,
      title: "分类",
      index: 2,
    ),
    "user": HomePageItem(
      iconData: Remix.user_smile_line,
      title: "我的",
      index: 3,
    ),
  };

  static final Map<String, LiveRoomTabItem> allLiveRoomTabs = {
    "chat": LiveRoomTabItem(
      iconData: Remix.message_3_line,
      title: "聊天",
    ),
    "super_chat": LiveRoomTabItem(
      iconData: Remix.sparkling_line,
      title: "SC/头条",
    ),
    "follow": LiveRoomTabItem(
      iconData: Remix.heart_line,
      title: "关注",
    ),
    "contribution_rank": LiveRoomTabItem(
      iconData: Remix.bar_chart_grouped_line,
      title: "贡献榜/亲密榜",
      subtitle: "虎牙暂无贡献榜，直播间内会自动跳过",
    ),
    "event_flow": LiveRoomTabItem(
      iconData: Remix.pulse_line,
      title: "动态",
      subtitle: "展示短时间内重复较多的弹幕内容",
    ),
    "settings": LiveRoomTabItem(
      iconData: Remix.settings_3_line,
      title: "设置",
    ),
  };

  static final Map<String, LiveRoomQuickAccessItem> allLiveRoomQuickAccess = {
    "follow": LiveRoomQuickAccessItem(
      iconData: Remix.play_list_2_line,
      title: "关注列表",
      subtitle: "快速切到已关注的直播间",
    ),
    "history": LiveRoomQuickAccessItem(
      iconData: Remix.history_line,
      title: "观看历史",
      subtitle: "打开已经看过的直播间记录",
    ),
    "recommendation": LiveRoomQuickAccessItem(
      iconData: Remix.apps_2_line,
      title: "同类推荐",
      subtitle: "按当前分区查找相似直播间",
    ),
    "contribution_rank": LiveRoomQuickAccessItem(
      iconData: Remix.bar_chart_grouped_line,
      title: "贡献榜/亲密榜",
      subtitle: "虎牙暂无贡献榜，直播间内会自动跳过",
    ),
  };

  static const String kBiliBili = "bilibili";
  static const String kDouyu = "douyu";
  static const String kHuya = "huya";
  static const String kDouyin = "douyin";
  static const String kKuaishou = "kuaishou";
}

class HomePageItem {
  final IconData iconData;
  final String title;
  final int index;
  HomePageItem({
    required this.iconData,
    required this.title,
    required this.index,
  });
}

class LiveRoomTabItem {
  final IconData iconData;
  final String title;
  final String? subtitle;

  LiveRoomTabItem({
    required this.iconData,
    required this.title,
    this.subtitle,
  });
}

class LiveRoomQuickAccessItem {
  final IconData iconData;
  final String title;
  final String subtitle;

  LiveRoomQuickAccessItem({
    required this.iconData,
    required this.title,
    required this.subtitle,
  });
}
