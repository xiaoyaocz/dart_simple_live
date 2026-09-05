import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';

class KuaishouWebLoginController extends BaseController {
  static const _loginUrl = "https://live.kuaishou.com/";
  static const _desktopSafariUserAgent =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15";
  static const _desktopChromeUserAgent =
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  final progress = 0.0.obs;
  final checking = false.obs;
  final errorMessage = "".obs;

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(_loginUrl)));
  }

  void onProgressChanged(InAppWebViewController controller, int value) {
    progress.value = value / 100;
  }

  void onLoadStart(InAppWebViewController controller, Uri? uri) {
    progress.value = 0;
    errorMessage.value = "";
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) {
    progress.value = 1;
  }

  void onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame == true) {
      progress.value = 1;
      errorMessage.value = error.description;
    }
  }

  void onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame == true) {
      progress.value = 1;
      errorMessage.value = "HTTP ${response.statusCode ?? "-"}";
    }
  }

  Future<void> reload() async {
    errorMessage.value = "";
    await webViewController?.reload();
  }

  Future<void> saveCookie({
    bool silent = false,
    bool autoClose = true,
  }) async {
    if (checking.value) {
      return;
    }
    checking.value = true;
    try {
      final snapshot = await _readCookie();
      var cookie = snapshot.cookie;
      final localStorageKww = await _readKww();
      if (localStorageKww.isNotEmpty &&
          _readCookieValue(cookie, 'kwfv1').isEmpty) {
        final encodedKww = Uri.encodeComponent(localStorageKww);
        cookie =
            cookie.isEmpty ? 'kwfv1=$encodedKww' : '$cookie; kwfv1=$encodedKww';
      }
      final kww = localStorageKww.isNotEmpty
          ? localStorageKww
          : _readCookieValue(cookie, 'kwfv1');
      if (cookie.isEmpty) {
        if (!silent) {
          SmartDialog.showToast("未读取到快手 Cookie");
        }
        return;
      }
      KuaishouAccountService.instance.setCookie(
        cookie,
        kww: kww,
        expiresAt: snapshot.expiresAt,
      );
      if (kww.isEmpty) {
        if (!silent || autoClose) {
          SmartDialog.showToast("Cookie 已保存，但未获取到 kwfv1；请刷新页面或完成验证后再保存");
        }
        return;
      }
      if (!silent || autoClose) {
        SmartDialog.showToast("快手 Cookie 已保存，可用于搜索和弹幕");
      }
      if (autoClose) {
        Get.back();
      }
    } catch (e) {
      Log.e("保存快手 Cookie 失败：$e", StackTrace.current);
      if (!silent) {
        SmartDialog.showToast("保存失败：$e");
      }
    } finally {
      checking.value = false;
    }
  }

  Future<_KuaishouCookieSnapshot> _readCookie() async {
    const expiryCookieNames = [
      "kuaishou.live.web_st",
      "kuaishou.server.web_st",
      "kuaishou.live.web_at",
      "passToken",
    ];
    final values = <String, String>{};
    int? latestExpiresDate;
    for (final url in const [
      "https://live.kuaishou.com",
      "https://kuaishou.com",
      "https://www.kuaishou.com",
    ]) {
      final cookies = await cookieManager.getCookies(url: WebUri(url));
      for (final item in cookies) {
        final name = item.name.trim();
        final value = item.value.trim();
        if (name.isNotEmpty && value.isNotEmpty) {
          values.putIfAbsent(name, () => value);
        }
        final expiresDate = item.expiresDate;
        if (expiryCookieNames.contains(name) &&
            expiresDate != null &&
            expiresDate > 0) {
          if (latestExpiresDate == null || expiresDate > latestExpiresDate) {
            latestExpiresDate = expiresDate;
          }
        }
      }
    }
    final expiresAt = latestExpiresDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(latestExpiresDate);
    return _KuaishouCookieSnapshot(
      cookie: values.entries.map((e) => "${e.key}=${e.value}").join("; "),
      expiresAt: expiresAt,
    );
  }

  Future<String> _readKww() async {
    final value = await webViewController?.evaluateJavascript(
      source: "window.localStorage.getItem('kwfv1') || ''",
    );
    return value?.toString().trim() ?? '';
  }

  String get userAgent =>
      Platform.isIOS ? _desktopSafariUserAgent : _desktopChromeUserAgent;

  String _readCookieValue(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final item = part.trim();
      if (item.startsWith('$name=')) {
        return item.substring(name.length + 1).trim();
      }
    }
    return '';
  }
}

class _KuaishouCookieSnapshot {
  final String cookie;
  final DateTime? expiresAt;

  const _KuaishouCookieSnapshot({
    required this.cookie,
    required this.expiresAt,
  });
}
