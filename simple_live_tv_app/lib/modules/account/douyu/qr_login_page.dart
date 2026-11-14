import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/account/douyu/qr_login_controller.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class DouyuQRLoginPage extends GetView<DouyuQRLoginController> {
  const DouyuQRLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                autofocus: true,
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "登录斗鱼账号",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
            ],
          ),
          AppStyle.vGap48,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Obx(
                    () {
                      if (controller.qrStatus.value == DouyuQRStatus.loading) {
                        return SizedBox(
                          width: 64.w,
                          height: 64.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 8.w,
                            color: Colors.white,
                          ),
                        );
                      }
                      if (controller.qrStatus.value == DouyuQRStatus.failed) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "二维码加载失败",
                              style: AppStyle.textStyleWhite,
                            ),
                            HighlightButton(
                              focusNode: AppFocusNode(),
                              iconData: Icons.refresh,
                              text: "重试",
                              onTap: controller.loadQrCode,
                            ),
                          ],
                        );
                      }
                      if (controller.qrStatus.value == DouyuQRStatus.expired) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "二维码已失效",
                              style: AppStyle.textStyleWhite,
                            ),
                            HighlightButton(
                              focusNode: AppFocusNode(),
                              iconData: Icons.refresh,
                              text: "刷新",
                              onTap: controller.loadQrCode,
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
                              size: 360.w,
                              padding: AppStyle.edgeInsetsA12,
                            ),
                          ),
                          AppStyle.vGap8,
                          Visibility(
                            visible: controller.qrStatus.value ==
                                DouyuQRStatus.scanned,
                            child: Text(
                              "已扫描，请在斗鱼APP内确认登录",
                              style: AppStyle.textStyleWhite,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: AppStyle.edgeInsetsA24,
                  child: Text(
                    "请使用斗鱼APP扫描二维码，并在APP内确认登录\n登录后自动续期，无需定期重新配置 Cookie\n扫码确认在斗鱼APP内完成，登录凭证由斗鱼下发\n介意设备/位置信息记录的话，可改用手动粘贴 Cookie",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32.w),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
