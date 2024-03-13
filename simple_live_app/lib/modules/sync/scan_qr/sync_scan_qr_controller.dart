import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';

class SyncScanQRControlelr extends BaseController {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  StreamSubscription<Barcode>? barcodeStreamSubscription;
  void onQRViewCreated(QRViewController controller) {
    qrController = controller;
    barcodeStreamSubscription =
        qrController!.scannedDataStream.listen((scanData) async {
      Log.d(scanData.toString());
      // 扫码成功后暂停摄像头
      await controller.pauseCamera();
      var code = scanData.code ?? "";
      // 处理扫码结果
      if (code.isEmpty) {
        await controller.resumeCamera();
        return;
      }
      Get.back(result: code);
    });
  }

  @override
  void onClose() {
    barcodeStreamSubscription?.cancel();
    qrController?.dispose();

    super.onClose();
  }
}
