import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/mine/account/douyu/qr_login_controller.dart';
import 'package:simple_live_app/widgets/mobile_page_insets.dart';

class DouyuQRLoginPage extends GetView<DouyuQRLoginController> {
  const DouyuQRLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MobilePageInsets(child: Builder(builder: _buildContent));
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("斗鱼账号登录")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Obx(
              () {
                if (controller.qrStatus.value == DouyuQRStatus.loading) {
                  return const CircularProgressIndicator();
                }
                if (controller.qrStatus.value == DouyuQRStatus.failed) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("二维码加载失败"),
                      TextButton(
                        onPressed: controller.loadQrCode,
                        child: const Text("重试"),
                      ),
                    ],
                  );
                }
                if (controller.qrStatus.value == DouyuQRStatus.expired) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("二维码已失效"),
                      TextButton(
                        onPressed: controller.loadQrCode,
                        child: const Text("刷新二维码"),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: AppStyle.radius12,
                      child: QrImageView(
                        data: controller.qrcodeUrl.value,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        size: 200.0,
                        padding: AppStyle.edgeInsetsA12,
                      ),
                    ),
                    AppStyle.vGap8,
                    Visibility(
                      visible:
                          controller.qrStatus.value == DouyuQRStatus.scanned,
                      child: const Text("已扫描，请在斗鱼APP内确认登录"),
                    ),
                  ],
                );
              },
            ),
          ),
          const Padding(
            padding: AppStyle.edgeInsetsA24,
            child: Text(
              "请使用斗鱼APP扫描二维码，并在APP内确认登录\n登录后自动续期，无需定期重新配置 Cookie\n扫码确认在斗鱼APP内完成，登录凭证由斗鱼下发\n介意设备/位置信息记录的话，可改用手动粘贴 Cookie",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
