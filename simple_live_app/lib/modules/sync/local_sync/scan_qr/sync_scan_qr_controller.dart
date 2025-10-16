import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';

class SyncScanQRController extends BaseController {
  final MobileScannerController qrController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool pause = false;

  /// 当扫描到二维码时触发
  void onDetect(BarcodeCapture capture) async {
    if (pause) return;
    pause = true;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      pause = false;
      await qrController.start();
      return;
    }

    final code = barcodes.first.rawValue ?? "";
    Log.d("扫描结果: $code");

    if (code.isEmpty) {
      pause = false;
      await qrController.start();
      return;
    }

    // 5位字符串为房间号
    if (code.length == 5) {
      Get.offAndToNamed(RoutePath.kRemoteSyncRoom, arguments: code);
      return;
    }

    // 多个地址分号分隔
    final addressList = code.split(";");
    if (addressList.length >= 2) {
      showPickerAddress(addressList);
    } else {
      Get.back(result: code);
    }
  }

  /// 地址选择弹窗
  void showPickerAddress(List<String> addressList) async {
    SmartDialog.showToast("扫描到多个地址，请选择一个连接");
    var address = await Utils.showBottomSheet(
      title: '请选择地址',
      child: ListView.builder(
        itemBuilder: (_, i) {
          return ListTile(
            title: Text(addressList[i]),
            onTap: () {
              Get.back(result: addressList[i]);
            },
          );
        },
        itemCount: addressList.length,
      ),
    );
    if (address != null && address.isNotEmpty) {
      Get.back(result: address);
    }
  }

  @override
  void onClose() {
    qrController.dispose();
    super.onClose();
  }
}