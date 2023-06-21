import 'package:simple_live_core/simple_live_core.dart';

class Sites {
  static List<Site> supportSites = [
    Site(
      id: "bilibili",
      logo: "assets/images/bilibili_2.png",
      name: "哔哩哔哩",
      liveSite: BiliBiliSite(),
    ),
    Site(
      id: "douyu",
      logo: "assets/images/douyu.png",
      name: "斗鱼直播",
      liveSite: DouyuSite(),
    ),
    Site(
      id: "huya",
      logo: "assets/images/huya.png",
      name: "虎牙直播",
      liveSite: HuyaSite(),
    ),
    Site(
      id: "douyin",
      logo: "assets/images/douyin.png",
      name: "抖音直播",
      liveSite: DouyinSite(),
    ),
  ];
}

class Site {
  final String id;
  final String name;
  final String logo;
  final LiveSite liveSite;
  Site({
    required this.id,
    required this.liveSite,
    required this.logo,
    required this.name,
  });
}
