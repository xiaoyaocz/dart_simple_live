import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/qr_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/qr_login_page.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/web_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/web_login_page.dart';
import 'package:simple_live_app/modules/search/search_page.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';
import 'package:simple_live_app/modules/search/search_web_navigation.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';

class _StubQRLoginController extends BiliBiliQRLoginController {
  @override
  // ignore: must_call_super
  void onInit() {
    // 测试不发起真实网络请求，由用例直接控制 qrStatus。
  }
}

void main() {
  test('移动端搜索页向登录与验证码 iframe 注入全帧桌面指纹脚本', () {
    final mobileScripts = SearchPage.buildUserScripts(
      preferDesktopWeb: true,
      viewWidth: 390,
    );
    expect(mobileScripts.length, 3);
    final allFrameScripts =
        mobileScripts.where((script) => !script.forMainFrameOnly).toList();
    expect(allFrameScripts.length, 1);
    expect(
      allFrameScripts.single.source,
      SearchWebNavigation.androidDesktopFingerprintScript,
    );
    expect(
      allFrameScripts.single.injectionTime,
      UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    final desktopScripts = SearchPage.buildUserScripts(
      preferDesktopWeb: false,
      viewWidth: 1280,
    );
    expect(desktopScripts.length, 1);
    expect(desktopScripts.single.forMainFrameOnly, isTrue);
  });

  test('独立 iframe 指纹脚本生效且用户双指放大登录/滑块验证时不会被重置缩放', () async {
    final dir = await Directory.systemTemp.createTemp('login-verify-');
    final fpFile = File('${dir.path}/fp.js');
    final mainFile = File('${dir.path}/main.js');
    addTearDown(() async {
      if (await fpFile.exists()) await fpFile.delete();
      if (await mainFile.exists()) await mainFile.delete();
      await dir.delete();
    });
    await fpFile
        .writeAsString(SearchWebNavigation.androidDesktopFingerprintScript);
    await mainFile
        .writeAsString(SearchWebNavigation.buildAndroidDesktopScript(390));

    final result = await Process.run('node', [
      '-e',
      r'''
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');

// 1. 模拟登录/验证码 iframe 单独运行指纹脚本
const iframeNav = {
  platform: 'Linux armv8l',
  vendor: '',
  userAgentData: { mobile: true, platform: 'Android', brands: [] }
};
const iframeCtx = { window: {}, navigator: iframeNav };
vm.runInNewContext(fs.readFileSync(process.argv[1], 'utf8'), iframeCtx);
assert.equal(iframeNav.platform, 'Win32');
assert.equal(iframeNav.vendor, 'Google Inc.');
assert.equal(iframeNav.userAgentData.mobile, false);
assert.equal(iframeNav.userAgentData.platform, 'Windows');

// 2. 模拟主页面用户双指放大操作滑块/输入框时，不被 onLoadStop 触发重置缩放
const viewportAttrs = { name: 'viewport', content: 'width=device-width, initial-scale=1' };
let setCount = 0;
const headNode = { appendChild(el) { el.parentNode = headNode; } };
const meta = {
  tagName: 'META',
  parentNode: headNode,
  getAttribute(k) { return viewportAttrs[k]; },
  setAttribute(k, v) { if (k === 'content') setCount++; viewportAttrs[k] = v; }
};
const visualViewport = { scale: 0.3047 };
const docEl = { scrollWidth: 1280, appendChild() {} };
const body = { scrollWidth: 1280 };
const win = {
  location: { href: 'https://live.douyin.com/' },
  navigator: { platform: 'Linux armv8l', vendor: '', userAgentData: { mobile: true, platform: 'Android', brands: [] } },
  visualViewport,
  addEventListener() {}
};
const ctx = {
  window: win,
  navigator: win.navigator,
  URL,
  setTimeout() { return 1; },
  setInterval() { return 1; },
  document: {
    documentElement: docEl,
    body,
    head: headNode,
    addEventListener() {},
    getElementById() { return null; },
    createElement(tag) { return { tagName: tag.toUpperCase(), setAttribute() {}, textContent: '' }; },
    querySelector(sel) { return sel.includes('viewport') ? meta : null; },
    querySelectorAll(sel) { return sel.includes('viewport') ? [meta] : []; }
  }
};
vm.runInNewContext(fs.readFileSync(process.argv[2], 'utf8'), ctx);
const afterInitCount = setCount;
assert.ok(viewportAttrs.content.includes('width=1280'));

// 用户双指放大登录框/滑块，此时页面 scrollWidth 稍微变化也不应重置 viewport
visualViewport.scale = 1.0;
docEl.scrollWidth = 1360;
win.__simpleLiveApplyDesktopViewport(390);
assert.equal(setCount, afterInitCount);

// 若横屏导致视口宽度变化，则正常重新适配
win.__simpleLiveApplyDesktopViewport(800);
assert.equal(setCount, afterInitCount + 1);
assert.ok(viewportAttrs.content.includes('initial-scale=0.5882'), viewportAttrs.content);

// 若网站强行改回 device-width，即便处于放大态也恢复桌面视口
viewportAttrs.content = 'width=device-width, initial-scale=1';
win.__simpleLiveApplyDesktopViewport(800);
assert.ok(viewportAttrs.content.includes('width=1360'), viewportAttrs.content);

console.log(JSON.stringify({ ok: true }));
''',
      fpFile.path,
      mainFile.path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(jsonDecode(result.stdout as String)['ok'], isTrue);
  });

  test('四平台登录、风控验证与第三方授权地址不被误拦或误判为直播间', () {
    const loginCases = [
      (Constant.kDouyin, 'https://live.douyin.com/'),
      (Constant.kDouyin, 'https://sso.douyin.com/login/'),
      (Constant.kDouyin, 'https://verify.snssdk.com/captcha/verify'),
      (Constant.kHuya, 'https://udblgn.huya.com/web/login'),
      (Constant.kHuya, 'https://www.huya.com/login'),
      (Constant.kHuya, 'https://www.huya.com/udb'),
      (Constant.kHuya, 'https://graph.qq.com/oauth2.0/authorize'),
      (Constant.kDouyu, 'https://passport.douyu.com/member/login'),
      (Constant.kDouyu, 'https://www.douyu.com/auth'),
      (Constant.kBiliBili, 'https://passport.bilibili.com/login'),
      (Constant.kBiliBili, 'https://account.bilibili.com/h5/account-h5/auth/scan-web'),
    ];
    for (final (siteId, raw) in loginCases) {
      final uri = Uri.parse(raw);
      expect(SearchRoomUrl.isBlockedExternalScheme(uri), isFalse, reason: raw);
      expect(SearchRoomUrl.roomIdFor(siteId, uri), isNull, reason: raw);
      expect(SearchRoomUrl.desktopUriFor(siteId, uri), isNull, reason: raw);
    }
  });

  test('B站扫码登录凭证提取支持 Set-Cookie 与回调 URL 双重回退并携带浏览器请求头', () {
    expect(
      BiliBiliQRLoginController.passportHeaders['User-Agent'],
      SearchRoomUrl.desktopUserAgent,
    );
    expect(
      BiliBiliQRLoginController.passportHeaders['Referer'],
      'https://www.bilibili.com/',
    );

    final fromHeaders = BiliBiliQRLoginController.extractCookies([
      'SESSDATA=abc123; Path=/; HttpOnly',
      'bili_jct=csrf456; Path=/',
      'DedeUserID=9988; Path=/',
    ]);
    expect(fromHeaders, contains('SESSDATA=abc123'));
    expect(fromHeaders, contains('bili_jct=csrf456'));
    expect(fromHeaders, contains('DedeUserID=9988'));

    final fromUrl = BiliBiliQRLoginController.extractCookies(
      const [],
      callbackUrl:
          'https://passport.biligame.com/x/passport-login/web/crossDomain?DedeUserID=1001&SESSDATA=url_sess&bili_jct=url_jct&gourl=https://www.bilibili.com',
    );
    expect(fromUrl, contains('DedeUserID=1001'));
    expect(fromUrl, contains('SESSDATA=url_sess'));
    expect(fromUrl, contains('bili_jct=url_jct'));
    expect(fromUrl, isNot(contains('gourl=')));
  });

  test('B站 Web 登录配置启用第三方 Cookie/存储且仅在存在 SESSDATA 时判定登录成功', () {
    final settings = BiliBiliWebLoginPage.buildWebViewSettings();
    expect(settings.thirdPartyCookiesEnabled, isTrue);
    expect(settings.domStorageEnabled, isTrue);
    expect(settings.databaseEnabled, isTrue);
    expect(settings.useShouldOverrideUrlLoading, isTrue);
    expect(settings.userAgent, contains('Chrome/131'));

    expect(BiliBiliWebLoginController.isPostLoginHost('m.bilibili.com'), isTrue);
    expect(
        BiliBiliWebLoginController.isPostLoginHost('www.bilibili.com'), isTrue);
    expect(BiliBiliWebLoginController.isPostLoginHost('live.bilibili.com'),
        isTrue);
    expect(BiliBiliWebLoginController.isPostLoginHost('space.bilibili.com'),
        isTrue);
    expect(BiliBiliWebLoginController.isPostLoginHost('passport.bilibili.com'),
        isFalse);

    expect(
      BiliBiliWebLoginController.buildAuthenticatedCookie([
        Cookie(name: 'buvid3', value: 'anon-123'),
      ]),
      isNull,
    );
    final cookie = BiliBiliWebLoginController.buildAuthenticatedCookie([
      Cookie(name: 'buvid3', value: 'anon-123'),
      Cookie(name: 'SESSDATA', value: 'valid-token'),
      Cookie(name: 'bili_jct', value: 'csrf-token'),
    ]);
    expect(cookie, contains('SESSDATA=valid-token'));
    expect(cookie, contains('bili_jct=csrf-token'));
  });

  test('B站退出登录清理范围仅限 B 站域名，不误删抖音/虎牙/斗鱼登录态', () {
    expect(BiliBiliAccountService.bilibiliCookieOrigins, isNotEmpty);
    for (final origin in BiliBiliAccountService.bilibiliCookieOrigins) {
      expect(Uri.parse(origin).host, endsWith('bilibili.com'));
    }
  });

  testWidgets('B站扫码登录页在二维码失效时正确展示失效提示与刷新按钮', (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    final controller = _StubQRLoginController();
    Get.put<BiliBiliQRLoginController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: BiliBiliQRLoginPage()));

    controller.qrStatus.value = QRStatus.expired;
    await tester.pump();
    expect(find.text('二维码已失效'), findsOneWidget);
    expect(find.text('刷新二维码'), findsOneWidget);

    controller.qrStatus.value = QRStatus.failed;
    await tester.pump();
    expect(find.text('二维码加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
