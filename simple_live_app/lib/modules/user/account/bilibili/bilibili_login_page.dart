import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/user/account/bilibili/bilibili_login_controller.dart';

class BiliBiliLoginPage extends GetView<BiliBiliLoginController> {
  const BiliBiliLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("哔哩哔哩账号登录"),
      ),
      body: InAppWebView(
        onWebViewCreated: controller.onWebViewCreated,
        onLoadStop: controller.onLoadStop,
      ),
    );
  }
}
