import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';

class SyncScanQRControlelr extends BaseController {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  StreamSubscription<Barcode>? barcodeStreamSubscription;
  bool pause = false;
  void onQRViewCreated(QRViewController controller) {
    qrController = controller;
    barcodeStreamSubscription =
        qrController!.scannedDataStream.listen((scanData) async {
      Log.d(scanData.toString());
      if (pause) {
        return;
      }
      pause = true;
      // 扫码成功后暂停摄像头
      await controller.pauseCamera();
      var code = scanData.code ?? "";
      // 处理扫码结果
      if (code.isEmpty) {
        pause = false;
        await controller.resumeCamera();
        return;
      }

      // 如果是5位字符串，为房间号
      if (code.length == 5) {
        Get.offAndToNamed(RoutePath.kRemoteSyncRoom, arguments: code);
        return;
      } else {
        var addressList = code.split(";");
        if (addressList.length >= 2) {
          //弹窗选择
          showPickerAddress(addressList);
        } else {
          Get.back(result: code);
        }
      }
    });
  }

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
    barcodeStreamSubscription?.cancel();
    qrController?.dispose();

    super.onClose();
  }
}
