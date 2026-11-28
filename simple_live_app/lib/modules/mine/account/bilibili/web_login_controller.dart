import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';

class BiliBiliWebLoginController extends BaseController {
  static const _postLoginHosts = {
    'm.bilibili.com',
    'www.bilibili.com',
    'live.bilibili.com',
    'space.bilibili.com',
    't.bilibili.com',
  };

  static bool isPostLoginHost(String host) =>
      _postLoginHosts.contains(host.toLowerCase());

  static String? buildAuthenticatedCookie(Iterable<Cookie> cookies) {
    final merged = <String, String>{};
    for (final c in cookies) {
      final value = '${c.value ?? ''}';
      if (c.name.isNotEmpty && value.isNotEmpty) {
        merged[c.name] = value;
      }
    }
    if ((merged['SESSDATA'] ?? '').isEmpty) {
      return null;
    }
    return merged.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  bool _completingLogin = false;

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(
      urlRequest: URLRequest(
        url: WebUri("https://passport.bilibili.com/login"),
      ),
    );
  }

  void toQRLogin() async {
    await Get.toNamed(RoutePath.kBiliBiliQRLogin);
    if (!isClosed) {
      Get.back();
    }
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) async {
    if (uri == null) {
      return;
    }
    if (isPostLoginHost(uri.host)) {
      await logined();
    }
  }

  Future<bool> logined() async {
    if (_completingLogin || isClosed) return false;
    _completingLogin = true;
    try {
      final collected = <Cookie>[];
      for (final url in const [
        'https://bilibili.com',
        'https://www.bilibili.com',
        'https://live.bilibili.com',
      ]) {
        collected.addAll(await cookieManager.getCookies(url: WebUri(url)));
      }
      final cookieStr = buildAuthenticatedCookie(collected);
      if (cookieStr == null) {
        return false;
      }
      Log.i(cookieStr);
      BiliBiliAccountService.instance.setCookie(cookieStr);
      await BiliBiliAccountService.instance.loadUserInfo();
      if (!isClosed) {
        Get.back();
      }
      return true;
    } catch (e) {
      Log.d('读取哔哩哔哩网页登录 Cookie 失败：$e');
      return false;
    } finally {
      _completingLogin = false;
    }
  }
}
