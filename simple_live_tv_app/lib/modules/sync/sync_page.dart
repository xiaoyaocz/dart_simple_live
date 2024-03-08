import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/sync/sync_controller.dart';
import 'package:simple_live_tv_app/services/tv_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class SyncPage extends GetView<SyncController> {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap24,
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
                "数据同步",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
          AppStyle.vGap24,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () => Visibility(
                    visible: TVService.instance.httpRunning.value,
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: QrImageView(
                        data: TVService.instance.ipAddress.value,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        padding: AppStyle.edgeInsetsA24,
                        size: 420.0.w,
                      ),
                    ),
                  ),
                ),
                AppStyle.vGap24,
                Obx(
                  () => Visibility(
                    visible: TVService.instance.httpRunning.value,
                    child: Text(
                      '服务已启动：${TVService.instance.ipAddress.value.split(';').map((e) => '$e:${TVService.httpPort}').join('；')}',
                      style: AppStyle.textStyleWhite,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: !TVService.instance.httpRunning.value,
                    child: Text(
                      'HTTP服务未启动：${TVService.instance.httpErrorMsg}，请尝试重启应用',
                      style: AppStyle.textStyleWhite,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                AppStyle.vGap12,
                Obx(
                  () => Visibility(
                    visible: TVService.instance.httpRunning.value,
                    child: Text(
                      "请使用Simple Live App扫描上方二维码\n建立连接后可在APP端选择需要同步至TV端的数据",
                      style: AppStyle.textStyleWhite,
                      textAlign: TextAlign.center,
                    ),
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
