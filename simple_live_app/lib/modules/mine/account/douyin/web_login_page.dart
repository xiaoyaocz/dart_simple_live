import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/douyin/web_login_controller.dart';

class DouyinWebLoginPage extends GetView<DouyinWebLoginController> {
  const DouyinWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("抖音网页登录"),
        actions: [
          IconButton(
            tooltip: "刷新",
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: () => controller.saveCookie(),
            icon: const Icon(Icons.save_outlined),
            label: const Text("保存"),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Obx(
            () => LinearProgressIndicator(
              minHeight: 3,
              value: controller.progress.value >= 1
                  ? null
                  : controller.progress.value,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.qr_code_scanner),
              title: Text("用抖音 App 扫码或验证码登录，登录成功后会自动保存，也可以点右上角保存。"),
            ),
          ),
          Expanded(
            child: InAppWebView(
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStop: controller.onLoadStop,
              onProgressChanged: controller.onProgressChanged,
              initialSettings: InAppWebViewSettings(
                userAgent: controller.userAgent,
                useShouldOverrideUrlLoading: true,
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: true,
              ),
              onCreateWindow: (webController, createWindowAction) async {
                final url = createWindowAction.request.url;
                if (url != null) {
                  await webController.loadUrl(urlRequest: URLRequest(url: url));
                }
                return false;
              },
            ),
          ),
        ],
      ),
    );
  }
}
