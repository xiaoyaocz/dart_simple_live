import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/web_login_controller.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';

class BiliBiliWebLoginPage extends GetView<BiliBiliWebLoginController> {
  const BiliBiliWebLoginPage({Key? key}) : super(key: key);

  static const String mobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Mobile Safari/537.36';

  static InAppWebViewSettings buildWebViewSettings() {
    return InAppWebViewSettings(
      userAgent: mobileChromeUserAgent,
      useShouldOverrideUrlLoading: true,
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      thirdPartyCookiesEnabled: true,
      safeBrowsingEnabled: false,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
      useHybridComposition: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("哔哩哔哩账号登录"),
        actions: [
          TextButton.icon(
            onPressed: controller.toQRLogin,
            icon: const Icon(Icons.qr_code),
            label: const Text("二维码登录"),
          ),
        ],
      ),
      body: InAppWebView(
        onWebViewCreated: controller.onWebViewCreated,
        onLoadStop: controller.onLoadStop,
        initialSettings: buildWebViewSettings(),
        shouldOverrideUrlLoading: (webController, navigationAction) async {
          var uri = navigationAction.request.url;
          if (uri == null) {
            return NavigationActionPolicy.ALLOW;
          }
          if (SearchRoomUrl.isBlockedExternalScheme(uri)) {
            return NavigationActionPolicy.CANCEL;
          }
          if (BiliBiliWebLoginController.isPostLoginHost(uri.host)) {
            final completed = await controller.logined();
            if (completed) {
              return NavigationActionPolicy.CANCEL;
            }
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
