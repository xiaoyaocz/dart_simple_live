import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/account/bilibili/qr_login_controller.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class BiliBiliQRLoginPage extends GetView<BiliBiliQRLoginController> {
  const BiliBiliQRLoginPage({Key? key}) : super(key: key);

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
                "登录哔哩哔哩",
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
                      if (controller.qrStatus.value == QRStatus.loading) {
                        return SizedBox(
                          width: 64.w,
                          height: 64.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 8.w,
                            color: Colors.white,
                          ),
                        );
                      }
                      if (controller.qrStatus.value == QRStatus.failed) {
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
                              onTap: controller.loadQRCode,
                            ),
                          ],
                        );
                      }
                      if (controller.qrStatus.value == QRStatus.failed) {
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
                              onTap: controller.loadQRCode,
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
                            visible:
                                controller.qrStatus.value == QRStatus.scanned,
                            child: Text(
                              "已扫描，请在手机上确认登录",
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
                    "请使用哔哩哔哩手机客户端扫描二维码登录\n必须登录后才能观看哔哩哔哩直播",
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
