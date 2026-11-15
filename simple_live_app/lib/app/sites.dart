import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class Sites {
  /// 1.13.x 及更早版本认识的平台。
  /// 完整顺序写 SiteSortV2，旧键 SiteSort 只写这个子集，避免旧版本读到新平台时空断言。
  static const List<String> legacySiteIds = [
    Constant.kBiliBili,
    Constant.kDouyu,
    Constant.kHuya,
    Constant.kDouyin,
    Constant.kKuaishou,
  ];

  static final Map<String, Site> allSites = {
    Constant.kBiliBili: Site(
      id: Constant.kBiliBili,
      logo: "assets/images/bilibili_2.png",
      name: "哔哩哔哩",
      liveSite: BiliBiliSite(),
    ),
    Constant.kDouyu: Site(
      id: Constant.kDouyu,
      logo: "assets/images/douyu.png",
      name: "斗鱼直播",
      liveSite: DouyuSite(),
    ),
    Constant.kHuya: Site(
      id: Constant.kHuya,
      logo: "assets/images/huya.png",
      name: "虎牙直播",
      liveSite: HuyaSite(),
    ),
    Constant.kDouyin: Site(
      id: Constant.kDouyin,
      logo: "assets/images/douyin.png",
      name: "抖音直播",
      liveSite: DouyinSite(),
    ),
    Constant.kKuaishou: Site(
      id: Constant.kKuaishou,
      logo: "assets/images/kuaishou.png",
      name: "快手直播",
      liveSite: KuaishouSite(),
    ),
  };

  static List<Site> get supportSites {
    return AppSettingsController.instance.siteSort
        .map((key) => allSites[key])
        .whereType<Site>()
        .toList();
  }

  /// 分类页可见平台：只受「分类平台」显示开关影响，
  /// 首页/搜索/关注等其它入口仍使用完整列表
  static List<Site> get visibleSites {
    final settings = AppSettingsController.instance;
    final list =
        supportSites.where((site) => settings.isSiteVisible(site.id)).toList();
    // 防呆：配置异常导致全部隐藏时回退到完整列表
    return list.isEmpty ? supportSites : list;
  }
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
