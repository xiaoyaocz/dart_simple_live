import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_page.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';
import 'package:simple_live_app/modules/search/search_web_navigation.dart';

class _FakeWebView implements InAppWebViewController {
  final loadedUrls = <String>[];
  String? currentUrl;

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    WebUri? allowingReadAccessTo,
    Uri? iosAllowingReadAccessTo,
  }) async {
    loadedUrls.add(urlRequest.url.toString());
  }

  @override
  Future<WebUri?> getUrl() async =>
      currentUrl == null ? null : WebUri(currentUrl!);

  @override
  JavaScriptHandlerCallback? removeJavaScriptHandler({
    required String handlerName,
  }) =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPromptController extends AppSearchController {
  _TestPromptController() : super(preferDesktopWeb: true);
  String? openedRoomId;

  @override
  Future<WebViewEnvironment?> get webViewEnvironment async => null;

  @override
  Future<void> openRoom({String? detectedRoomId}) async {
    openedRoomId = detectedRoomId ?? roomId.value;
  }
}

class _TestSettings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {
    siteSort.assignAll([
      Constant.kDouyin,
      Constant.kHuya,
      Constant.kBiliBili,
      Constant.kDouyu,
    ]);
  }
}

void main() {
  test('移动端 WebView 配置启用电脑版 UA、缩放、单窗导航与防卡顿参数', () {
    final mobile = SearchPage.buildWebViewSettings(preferDesktopWeb: true);
    expect(mobile.userAgent, SearchRoomUrl.desktopUserAgent);
    expect(mobile.preferredContentMode, UserPreferredContentMode.DESKTOP);
    expect(mobile.supportMultipleWindows, isFalse);
    expect(mobile.mediaPlaybackRequiresUserGesture, isTrue);
    expect(mobile.useWideViewPort, isTrue);
    expect(mobile.loadWithOverviewMode, isTrue);
    expect(mobile.layoutAlgorithm, LayoutAlgorithm.NORMAL);
    expect(mobile.textZoom, 100);
    expect(mobile.supportZoom, isTrue);
    expect(mobile.thirdPartyCookiesEnabled, isTrue);
    expect(mobile.safeBrowsingEnabled, isFalse);

    final desktop = SearchPage.buildWebViewSettings(preferDesktopWeb: false);
    expect(desktop.supportMultipleWindows, isTrue);
    expect(desktop.userAgent, isEmpty);
  });

  test('移动端桌面视口按容器宽度自适应缩放且支持用户双指缩放', () {
    final portrait = SearchWebNavigation.desktopViewportContent(390);
    expect(portrait, contains('width=1280'));
    expect(portrait, contains('initial-scale=0.3047'));
    expect(portrait, contains('user-scalable=yes'));

    final landscape = SearchWebNavigation.desktopViewportContent(800);
    expect(landscape, contains('width=1280'));
    expect(landscape, contains('initial-scale=0.6250'));

    final tablet = SearchWebNavigation.desktopViewportContent(1400);
    expect(tablet, contains('width=1400'));
    expect(tablet, contains('initial-scale=1.0000'));
  });

  test('外部 APP 唤起协议与下载引导链接被拦截，正常网页放行', () {
    const blocked = [
      'yykiwi://live/660000',
      'huya://room/660000',
      'douyutv://room/12345',
      'bilibili://live/12345',
      'snssdk1128://live/12345',
      'intent://live#Intent;scheme=huya;end',
      'https://a.app.qq.com/o/simple.jsp?pkgname=com.duowan.kiwi',
      'https://dl.example.com/huya.apk',
    ];
    for (final raw in blocked) {
      expect(SearchRoomUrl.isBlockedExternalScheme(Uri.parse(raw)), isTrue,
          reason: raw);
    }
    expect(
      SearchRoomUrl.isBlockedExternalScheme(
          Uri.parse('https://www.huya.com/660000')),
      isFalse,
    );
  });

  test('手机版域名地址规范化为对应平台电脑版地址', () {
    expect(
      SearchRoomUrl.desktopUriFor(
              Constant.kHuya, Uri.parse('https://m.huya.com/660000'))
          .toString(),
      'https://www.huya.com/660000',
    );
    expect(
      SearchRoomUrl.desktopUriFor(
              Constant.kDouyu, Uri.parse('https://m.douyu.com/98765'))
          .toString(),
      'https://www.douyu.com/98765',
    );
    expect(
      SearchRoomUrl.desktopUriFor(
              Constant.kBiliBili, Uri.parse('https://live.bilibili.com/h5/123'))
          .toString(),
      'https://live.bilibili.com/123',
    );
    expect(
      SearchRoomUrl.desktopUriFor(
              Constant.kBiliBili, Uri.parse('https://m.bilibili.com/live/456'))
          .toString(),
      'https://live.bilibili.com/456',
    );
    expect(
      SearchRoomUrl.desktopUriFor(Constant.kDouyin,
              Uri.parse('https://m.douyin.com/share/live/789012'))
          .toString(),
      'https://live.douyin.com/789012',
    );
  });

  test('移动端导航拦截外部 APP 唤起、将手机页转回桌面页且避免重定向死循环', () {
    final controller = AppSearchController(preferDesktopWeb: true);
    addTearDown(controller.onClose);
    final webView = _FakeWebView();
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    controller.webViewController = webView;

    // 外部唤起直接拦截
    expect(
      controller.handleNavigation(NavigationAction(
        request: URLRequest(url: WebUri('yykiwi://live/660000')),
        isForMainFrame: true,
      )),
      NavigationActionPolicy.CANCEL,
    );

    // 误跳手机虎牙页时自动转回桌面页并识别房间
    expect(
      controller.handleNavigation(NavigationAction(
        request: URLRequest(url: WebUri('https://m.huya.com/660000')),
        isForMainFrame: true,
      )),
      NavigationActionPolicy.CANCEL,
    );
    expect(webView.loadedUrls, ['https://www.huya.com/660000']);
    expect(controller.roomId.value, '660000');
    expect(controller.showRoomPrompt, isTrue);

    // 同一路径再次被服务端踢回时放行，避免死循环
    expect(
      controller.handleNavigation(NavigationAction(
        request: URLRequest(url: WebUri('https://m.huya.com/660000')),
        isForMainFrame: true,
      )),
      NavigationActionPolicy.ALLOW,
    );

    // 移动端进度达到 75 提前结束加载遮罩
    controller.startLoading();
    controller.updateLoadProgress(75);
    expect(controller.webViewLoading.value, isFalse);

    // 关闭弹窗后本房间不再重复弹，切新房间后重新弹出
    controller.dismissRoomPrompt();
    expect(controller.showRoomPrompt, isFalse);
    controller.updateUrl(Uri.parse('https://www.huya.com/888888'));
    expect(controller.showRoomPrompt, isTrue);
  });

  test('点击进入直播间时若页面尚未跳转完成，保留已捕获的房间号不误清空', () async {
    final controller = _TestPromptController();
    addTearDown(controller.onClose);
    final webView = _FakeWebView()
      ..currentUrl = 'https://www.huya.com/search?hsk=lol';
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    controller.webViewController = webView;
    controller.updateUrl(Uri.parse('https://www.huya.com/660000'));
    await controller.openCurrentRoom();
    expect(controller.openedRoomId, '660000');
  });

  test('Android 桌面脚本伪装桌面指纹、自适应视口、禁止视频自动播放并阻止外部协议点击', () async {
    final directory = await Directory.systemTemp.createTemp('search-android-');
    final source = File('${directory.path}/android_desktop.js');
    addTearDown(() async {
      if (await source.exists()) await source.delete();
      await directory.delete();
    });
    await source
        .writeAsString(SearchWebNavigation.buildAndroidDesktopScript(390));
    final result = await Process.run('node', [
      '-e',
      r'''
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const clicks = [];
const navigator = {
  platform: 'Linux armv8l',
  vendor: '',
  userAgentData: { mobile: true, platform: 'Android', brands: [] }
};
let pauseCalls = 0;
function HTMLMediaElement() {}
HTMLMediaElement.prototype.play = function () { throw new Error('should be intercepted'); };
HTMLMediaElement.prototype.pause = function () { pauseCalls++; };
const timers = [];
const headNode = {
  children: [],
  appendChild(el) { el.parentNode = headNode; headNode.children.push(el); appended.push(el); },
  removeChild(el) {
    const idx = metas.indexOf(el);
    if (idx !== -1) metas.splice(idx, 1);
  }
};
const docElNode = { scrollWidth: 1280, appendChild(el) { el.parentNode = docElNode; appended.push(el); } };
const viewportAttrs = { name: 'viewport', content: 'width=device-width, initial-scale=1.0, user-scalable=no' };
const viewportMeta = {
  tagName: 'META',
  parentNode: docElNode,
  getAttribute(k) { return viewportAttrs[k]; },
  setAttribute(k, v) { viewportAttrs[k] = v; }
};
const metas = [viewportMeta];
const observers = [];
function MutationObserver(cb) { this.cb = cb; observers.push(this); }
MutationObserver.prototype.observe = function () {};
const appended = [];
const window = {
  location: { href: 'https://www.huya.com/' },
  navigator,
  HTMLMediaElement,
  addEventListener() {}
};
const context = {
  window,
  navigator,
  URL,
  MutationObserver,
  setTimeout(fn) { timers.push(fn); return timers.length; },
  setInterval() { return 1; },
  document: {
    documentElement: docElNode,
    body: { scrollWidth: 1280 },
    head: headNode,
    addEventListener(name, cb) { if (name === 'click') clicks.push(cb); },
    getElementById() { return null; },
    createElement(tag) { return { tagName: tag.toUpperCase(), setAttribute() {}, textContent: '' }; },
    querySelector(sel) { return sel.includes('viewport') ? metas[0] || null : null; },
    querySelectorAll(sel) { return sel.includes('viewport') ? metas.slice() : []; }
  }
};
const script = fs.readFileSync(process.argv[1], 'utf8');
vm.runInNewContext(script, context);

assert.equal(navigator.platform, 'Win32');
assert.equal(navigator.vendor, 'Google Inc.');
assert.equal(navigator.userAgentData.mobile, false);
assert.equal(navigator.userAgentData.platform, 'Windows');

// 强制把原页面的 device-width 改写为 1280 宽自适应视口，并确保移入 document.head
assert.equal(viewportMeta.parentNode, headNode);
assert.ok(viewportAttrs.content.includes('width=1280'), viewportAttrs.content);
assert.ok(viewportAttrs.content.includes('initial-scale=0.3047'), viewportAttrs.content);
assert.ok(viewportAttrs.content.includes('user-scalable=yes'), viewportAttrs.content);

// 站点后续再插入第二个 device-width viewport meta 时自动移除，保留自适应视口
const dupMeta = {
  tagName: 'META',
  parentNode: headNode,
  getAttribute(k) { return k === 'content' ? 'width=device-width, initial-scale=1' : 'viewport'; },
  setAttribute() {}
};
metas.push(dupMeta);
observers[0].cb([{ type: 'childList', addedNodes: [dupMeta] }]);
assert.equal(metas.length, 1);
assert.equal(metas[0], viewportMeta);

// 模拟横屏宽度变化后重新自适应
window.__simpleLiveApplyDesktopViewport(800);
assert.ok(viewportAttrs.content.includes('initial-scale=0.6250'), viewportAttrs.content);

const video = new HTMLMediaElement();
video.autoplay = true;
video.muted = false;
video.play();
assert.equal(video.muted, true);
assert.equal(video.autoplay, false);
assert.equal(pauseCalls, 1);

let prevented = false, stopped = false;
clicks[0]({
  target: {
    nodeType: 1,
    closest: () => ({
      target: '_blank',
      getAttribute: () => 'yykiwi://live/123',
      removeAttribute() {}
    })
  },
  preventDefault() { prevented = true; },
  stopPropagation() { stopped = true; }
});
assert.equal(prevented, true);
assert.equal(stopped, true);

let removedTarget = false;
clicks[0]({
  target: {
    nodeType: 1,
    closest: () => ({
      target: '_blank',
      getAttribute: () => 'https://www.huya.com/660000',
      removeAttribute(attr) { if (attr === 'target') removedTarget = true; }
    })
  }
});
assert.equal(removedTarget, true);
console.log(JSON.stringify({ ok: true }));
''',
      source.path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(jsonDecode(result.stdout as String)['ok'], isTrue);
  });

  group('SearchPage 底部弹出跳转直播间选项', () {
    const manager =
        MethodChannel('com.pichillilorenzo/flutter_inappwebview_manager');
    final channels = <MethodChannel>[];
    var nextId = 2200;

    setUp(() {
      WindowsInAppWebViewPlatform.registerWith();
      Get.testMode = true;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(manager, (call) async {
        if (call.method != 'createInAppWebView') return null;
        final id = nextId++;
        for (final name in [
          'com.pichillilorenzo/custom_platform_view_$id',
          'com.pichillilorenzo/custom_platform_view_${id}_events',
          'com.pichillilorenzo/flutter_inappwebview_$id',
        ]) {
          final channel = MethodChannel(name);
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return id;
      });
    });

    tearDown(() {
      Get.reset();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(manager, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      channels.clear();
    });

    testWidgets('平台选择页与电脑版保持一致，无多余副标题提示', (tester) async {
      Get.put<AppSettingsController>(_TestSettings());
      final controller = _TestPromptController();
      Get.put<AppSearchController>(controller);

      await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
      await tester.pump();

      expect(find.text('选择平台，在网页中搜索并进入直播间'), findsOneWidget);
      expect(find.textContaining('已开启电脑版网页模式'), findsNothing);
    });

    testWidgets('识别直播间后底部弹出进入直播间卡片，点击可跳转或暂时收起', (tester) async {
      final controller = _TestPromptController();
      Get.put<AppSearchController>(controller);
      controller.selectSite(Sites.allSites[Constant.kHuya]!);
      controller.finishLoading();

      await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
      await tester.pump();
      await tester.pump();

      expect(find.text('进入直播间'), findsNothing);

      controller.updateUrl(Uri.parse('https://www.huya.com/660000'));
      await tester.pump();

      expect(find.text('检测到直播间 #660000'), findsOneWidget);
      expect(find.text('进入直播间'), findsOneWidget);
      expect(find.text('打开播放器'), findsOneWidget);

      await tester.tap(find.text('进入直播间'));
      await tester.pump();
      expect(controller.openedRoomId, '660000');

      await tester.tap(find.byTooltip('暂时收起'));
      await tester.pump();
      expect(find.text('进入直播间'), findsNothing);
      expect(find.text('打开播放器'), findsOneWidget);
    });
  });
}
