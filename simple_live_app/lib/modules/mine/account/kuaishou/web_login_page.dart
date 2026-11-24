import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/kuaishou/web_login_controller.dart';

class KuaishouWebLoginPage extends GetView<KuaishouWebLoginController> {
  const KuaishouWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("快手网页登录"),
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
          child: Obx(() {
            final progress = controller.progress.value;
            if (progress >= 1) {
              return const SizedBox(height: 3);
            }
            return LinearProgressIndicator(minHeight: 3, value: progress);
          }),
        ),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.cookie_outlined),
              title: Text("登录快手网页后点右上角保存；保存后的 Cookie 会用于快手搜索和弹幕。"),
            ),
          ),
          Obx(() {
            final error = controller.errorMessage.value;
            if (error.isEmpty) {
              return const SizedBox.shrink();
            }
            return Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text("快手网页加载失败"),
                subtitle: Text("$error\n请重试；仍无法打开时返回并选择 Cookie 登录。"),
                trailing: TextButton(
                  onPressed: controller.reload,
                  child: const Text("重试"),
                ),
              ),
            );
          }),
          Expanded(
            child: InAppWebView(
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStart: controller.onLoadStart,
              onLoadStop: controller.onLoadStop,
              onProgressChanged: controller.onProgressChanged,
              onReceivedError: controller.onReceivedError,
              onReceivedHttpError: controller.onReceivedHttpError,
              initialSettings: InAppWebViewSettings(
                userAgent: controller.userAgent,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                sharedCookiesEnabled: true,
                thirdPartyCookiesEnabled: true,
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
