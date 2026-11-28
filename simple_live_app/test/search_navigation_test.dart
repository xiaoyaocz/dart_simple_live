import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';

void main() {
  test('主页面导航提前识别房间，子资源不能覆盖跳转目标', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    final policy = controller.handleNavigation(NavigationAction(
      request: URLRequest(url: WebUri('https://m.huya.com/12345')),
      isForMainFrame: true,
    ));
    expect(policy, NavigationActionPolicy.ALLOW);
    controller.handleNavigation(NavigationAction(
      request: URLRequest(url: WebUri('https://example.com/ad')),
      isForMainFrame: false,
    ));
    expect(controller.roomId.value, '12345');
    expect(controller.webViewVisible.value, isTrue);
  });

  test('四个平台手机导航识别房间并保持网页浏览', () {
    const cases = [
      (Constant.kBiliBili, 'https://live.bilibili.com/h5/12345', '12345'),
      (Constant.kHuya, 'https://m.huya.com/abc123', 'abc123'),
      (Constant.kDouyu, 'https://m.douyu.com/67890', '67890'),
      (
        Constant.kDouyin,
        'https://www.douyin.com/root/live/921169302662',
        '921169302662'
      ),
    ];
    for (final (site, url, id) in cases) {
      final controller = AppSearchController();
      addTearDown(controller.onClose);
      controller.selectSite(Sites.allSites[site]!);
      controller.updateUrl(Uri.parse(url));
      controller.updateUrl(Uri.parse(url));
      expect(controller.roomId.value, id);
      expect(controller.webViewVisible.value, isTrue);
    }
  });

  test('离开房间清除目标，再次进入同一房间恢复快捷入口目标', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kDouyu]!);
    controller.updateUrl(Uri.parse('https://www.douyu.com/12345'));
    controller.updateUrl(Uri.parse('https://www.douyu.com/search/abc'));
    expect(controller.roomId.value, isNull);
    controller.updateUrl(Uri.parse('https://www.douyu.com/12345'));
    expect(controller.roomId.value, '12345');
    expect(controller.webViewVisible.value, isTrue);
  });

  test('切换四个平台后快捷入口始终指向当前平台房间', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    const rooms = [
      (Constant.kBiliBili, 'https://live.bilibili.com/12345', '12345'),
      (Constant.kHuya, 'https://www.huya.com/abc123', 'abc123'),
      (Constant.kDouyu, 'https://www.douyu.com/67890', '67890'),
      (
        Constant.kDouyin,
        'https://live.douyin.com/921169302662?enter_from_merge=web_live',
        '921169302662'
      ),
    ];
    for (final (siteId, url, roomId) in rooms) {
      controller.selectSite(Sites.allSites[siteId]!);
      controller.updateUrl(Uri.parse(url));
      controller.updateUrl(Uri.parse(url));
      expect(controller.roomId.value, roomId);
      expect(controller.selectedSite.value!.id, siteId);
    }
  });

  test('选择平台后，仅在当前平台直播间显示跳转目标', () {
    final controller = AppSearchController();
    final site = Sites.allSites[Constant.kDouyu]!;

    controller.selectSite(site);
    expect(controller.selectedSite.value, site);
    expect(controller.roomId.value, isNull);

    controller.updateUrl(Uri.parse('https://www.douyu.com/12345'));
    expect(controller.roomId.value, '12345');

    controller.updateUrl(Uri.parse('https://www.douyu.com/search/abc'));
    expect(controller.roomId.value, isNull);

    controller.reset();
    expect(controller.selectedSite.value, isNull);
  });
}
