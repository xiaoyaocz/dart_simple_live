import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/sync/sync_controller.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';
import 'package:simple_live_tv_app/services/sync_service.dart';
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "远程同步",
                        style: AppStyle.titleStyleWhite.copyWith(
                          fontSize: 32.w,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppStyle.vGap16,
                      Obx(
                        () => Visibility(
                          visible: SyncService.instance.httpRunning.value,
                          child: GestureDetector(
                            onTap: () {
                              Get.back();
                            },
                            child: QrImageView(
                              data: controller.currentRoomId.value,
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
                          visible: controller.state.value ==
                              SignalRConnectionState.connected,
                          child: Text.rich(
                            TextSpan(
                              text: '房间号：',
                              children: [
                                TextSpan(
                                  text: controller.currentRoomId.value,
                                  style: AppStyle.textStyleWhite
                                      .copyWith(fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Obx(
                        () => Visibility(
                          visible: controller.state.value ==
                              SignalRConnectionState.disconnected,
                          child: Text(
                            '连接已断开，请尝试重进此页面',
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Obx(
                        () => Visibility(
                          visible: controller.state.value ==
                              SignalRConnectionState.connecting,
                          child: Text(
                            '正在创建房间...',
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      AppStyle.vGap12,
                      Obx(
                        () => Visibility(
                          visible: controller.state.value ==
                              SignalRConnectionState.connected,
                          child: Text(
                            "${controller.countDown}秒后将自动关闭服务\n请扫描二维码或输入房间号进行连接",
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  color: Colors.white.withAlpha(50),
                  thickness: 2.w,
                  endIndent: 120.w,
                  indent: 120.w,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "局域网同步",
                        style: AppStyle.titleStyleWhite.copyWith(
                          fontSize: 32.w,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppStyle.vGap16,
                      Obx(
                        () => Visibility(
                          visible: SyncService.instance.httpRunning.value,
                          child: GestureDetector(
                            onTap: () {
                              Get.back();
                            },
                            child: QrImageView(
                              data: SyncService.instance.ipAddress.value,
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
                          visible: SyncService.instance.httpRunning.value,
                          child: Text(
                            '服务已启动：${SyncService.instance.ipAddress.value.split(';').map((e) => '$e:${SyncService.httpPort}').join('；')}',
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Obx(
                        () => Visibility(
                          visible: !SyncService.instance.httpRunning.value,
                          child: Text(
                            'HTTP服务未启动：${SyncService.instance.httpErrorMsg}，请尝试重启应用',
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      AppStyle.vGap12,
                      Obx(
                        () => Visibility(
                          visible: SyncService.instance.httpRunning.value,
                          child: Text(
                            "请扫描二维码或输入IP地址进行连接\n建立连接后可在APP端选择需要同步至TV端的数据",
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
          ),
        ],
      ),
    );
  }
}
