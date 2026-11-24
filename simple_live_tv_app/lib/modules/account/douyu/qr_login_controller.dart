import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/services/douyu_account_service.dart';

enum DouyuQRStatus {
  loading,
  unscanned,
  scanned,
  expired,
  failed,
}

/// 斗鱼扫码登录：展示二维码（斗鱼APP 扫码确认），
/// 确认后拿到续期凭据（LTP0/dy_did）并自动换取播放 Cookie
class DouyuQRLoginController extends GetxController {
  final DouyuPassport _passport = DouyuPassport();
  Timer? timer;

  var qrcodeUrl = "".obs;
  Rx<DouyuQRStatus> qrStatus = DouyuQRStatus.loading.obs;

  @override
  void onInit() {
    loadQrCode();
    super.onInit();
  }

  Future<void> loadQrCode() async {
    try {
      qrStatus.value = DouyuQRStatus.loading;
      timer?.cancel();
      qrcodeUrl.value = await _passport.generateQrCode();
      qrStatus.value = DouyuQRStatus.unscanned;
      startPoll();
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast(e.toString());
      qrStatus.value = DouyuQRStatus.failed;
    }
  }

  void startPoll() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => pollQrStatus());
  }

  Future<void> pollQrStatus() async {
    try {
      final status = await _passport.poll();
      switch (status) {
        case DouyuQrStatus.waiting:
          break;
        case DouyuQrStatus.scanned:
          qrStatus.value = DouyuQRStatus.scanned;
          break;
        case DouyuQrStatus.expired:
          timer?.cancel();
          qrStatus.value = DouyuQRStatus.expired;
          break;
        case DouyuQrStatus.authorized:
          timer?.cancel();
          await _applyCredentials();
          break;
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast(e.toString());
    }
  }

  Future<void> _applyCredentials() async {
    try {
      await DouyuAccountService.instance.applyQrCredentials(_passport);
      SmartDialog.showToast("斗鱼账号登录成功");
      Get.back();
    } catch (e, stackTrace) {
      Log.e("斗鱼扫码登录换取 Cookie 失败：$e", stackTrace);
      SmartDialog.showToast(e.toString());
    }
  }

  @override
  void onClose() {
    timer?.cancel();
    _passport.close();
    super.onClose();
  }
}
