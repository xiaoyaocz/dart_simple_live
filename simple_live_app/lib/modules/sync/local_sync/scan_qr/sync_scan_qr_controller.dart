import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/utils.dart';

String? parseSyncQrCode(String? raw) {
  final code = raw?.trim() ?? '';
  final roomId = code.split('|').first;
  if (RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(roomId) &&
      (code == roomId || code.startsWith('$roomId|'))) {
    return code;
  }
  final addresses = code.split(';');
  if (addresses.isNotEmpty &&
      addresses.every((address) =>
          InternetAddress.tryParse(address.trim())?.type ==
          InternetAddressType.IPv4)) {
    return code;
  }
  return null;
}

class SyncScanQRControlelr extends BaseController with WidgetsBindingObserver {
  final scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    cameraResolution: const Size(1280, 720),
    autoZoom: true,
  );
  final cameraReady = RxnBool();
  final hint = '将同步二维码放入框内，点击画面可对焦'.obs;
  bool pause = false;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
    requestCameraPermission();
  }

  Future<void> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      status = await Permission.camera.status;
    } else if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    cameraReady.value = status.isGranted;
  }

  Future<void> retryCamera() async {
    await requestCameraPermission();
    if (cameraReady.value == true) {
      try {
        await scannerController.start();
      } catch (_) {
        SmartDialog.showToast('相机启动失败，请检查是否被其他应用占用');
      }
    }
  }

  void toggleTorch() {
    if (scannerController.value.isInitialized) {
      unawaited(scannerController.toggleTorch());
    }
  }

  void switchCamera() {
    if (scannerController.value.isInitialized) {
      unawaited(scannerController.switchCamera());
    }
  }

  void onDetect(BarcodeCapture capture) {
    if (pause) return;
    for (final barcode in capture.barcodes) {
      final code = parseSyncQrCode(barcode.rawValue);
      if (code == null) {
        if (barcode.rawValue?.isNotEmpty == true) {
          hint.value = '请扫描 Simple Live 的同步二维码';
        }
        continue;
      }
      pause = true;
      unawaited(_finishScan(code));
      return;
    }
  }

  Future<void> _finishScan(String code) async {
    if (!code.contains(';') || code.contains('|')) {
      Get.back(result: code);
      return;
    }
    try {
      await scannerController.stop();
      final address = await showPickerAddress(code.split(';'));
      if (address != null) {
        Get.back(result: address);
        return;
      }
      pause = false;
      await scannerController.start();
    } catch (_) {
      pause = false;
      SmartDialog.showToast('扫描中断，请重试');
    }
  }

  Future<String?> showPickerAddress(List<String> addressList) async {
    SmartDialog.showToast('扫描到多个地址，请选择一个连接');
    final address = await Utils.showBottomSheet(
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
    return address is String && address.isNotEmpty ? address : null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!scannerController.value.hasCameraPermission || pause) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(scannerController.stop());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(scannerController.start());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(scannerController.dispose());
    super.onClose();
  }
}
