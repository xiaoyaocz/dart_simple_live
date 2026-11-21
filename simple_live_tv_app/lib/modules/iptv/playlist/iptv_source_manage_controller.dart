import 'package:get/get.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';

/// IPTV 直播源管理控制器：委托 IptvService 完成源的启停与增删改，
/// 页面通过 Obx 直接读取 service 的 RxList 渲染。
class IptvSourceManageController extends GetxController {
  IptvService get service => IptvService.instance;

  /// 进入IPTV页自动刷新开关（与IptvService设置联动）
  final autoRefreshOnEnter = true.obs;

  @override
  void onInit() {
    super.onInit();
    autoRefreshOnEnter.value = IptvService.instance.autoRefreshOnEnter;
  }

  Future<void> setAutoRefreshOnEnter(bool value) async {
    autoRefreshOnEnter.value = value;
    await IptvService.instance.setAutoRefreshOnEnter(value);
  }

  /// 校验自定义源名称与地址：格式、查重；返回错误文案，null 表示通过
  String? validateInput(
    String name,
    String url, {
    IptvSourceMeta? ignore,
  }) {
    if (name.isEmpty || url.isEmpty) return "请填写源名称与 M3U 地址";
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != "http" && uri.scheme != "https")) {
      return "地址需以 http:// 或 https:// 开头";
    }
    final pool = service.sourcePool;
    if (pool.any((e) => e.name == name && e != ignore)) {
      return "源名称「$name」已存在";
    }
    for (final e in pool) {
      if (e == ignore) continue;
      if (e.urls.contains(url)) return "该地址已存在于「${e.name}」";
    }
    return null;
  }

  /// 校验源地址可达并解析，返回频道数；失败抛错
  Future<int> validateCustomSourceUrl(String url) =>
      service.validateCustomSourceUrl(url);

  Future<void> addCustomSource(String name, String url) =>
      service.addCustomSource(name: name, url: url);

  Future<void> updateCustomSource(IptvSourceMeta source, {required String name, required String url}) =>
      service.updateCustomSource(source, name: name, url: url);

  Future<void> deleteSource(IptvSourceMeta source) => service.deleteSource(source);

  Future<void> toggleSourceEnabled(IptvSourceMeta source) =>
      service.toggleSourceEnabled(source);

  Future<void> restoreDefaultSources() => service.restoreDefaultSources();
}
