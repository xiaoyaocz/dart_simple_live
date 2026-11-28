import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';

enum QRStatus {
  loading,
  unscanned,
  scanned,
  expired,
  failed,
}

class BiliBiliQRLoginController extends GetxController {
  static const Map<String, String> passportHeaders = {
    'User-Agent': SearchRoomUrl.desktopUserAgent,
    'Referer': 'https://www.bilibili.com/',
  };

  static const _fallbackCookieKeys = {
    'DedeUserID',
    'DedeUserID__ckMd5',
    'SESSDATA',
    'bili_jct',
    'sid',
  };

  /// 从 Set-Cookie 响应头提取登录凭证；若头缺失则回退解析回调 URL 参数。
  static String extractCookies(
    List<String>? setCookies, {
    String? callbackUrl,
  }) {
    final merged = <String, String>{};
    if (setCookies != null) {
      for (final raw in setCookies) {
        final pair = raw.split(';').first.trim();
        final eq = pair.indexOf('=');
        if (eq > 0) {
          final key = pair.substring(0, eq).trim();
          final value = pair.substring(eq + 1).trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            merged[key] = value;
          }
        }
      }
    }
    if ((merged['SESSDATA'] ?? '').isEmpty &&
        callbackUrl != null &&
        callbackUrl.isNotEmpty) {
      final uri = Uri.tryParse(callbackUrl);
      if (uri != null) {
        for (final entry in uri.queryParameters.entries) {
          if (_fallbackCookieKeys.contains(entry.key) &&
              entry.value.isNotEmpty) {
            merged.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }
    }
    return merged.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  @override
  void onInit() {
    loadQRCode();
    super.onInit();
  }

  Timer? timer;
  bool _polling = false;

  var qrcodeUrl = "".obs;
  var qrcodeKey = "";

  /// 二维码状态
  /// - [0] 加载中
  /// - [1] 未扫描
  /// - [2] 已扫描，待确认
  /// - [3] 二维码已经失效
  /// - [4] 登录失败
  Rx<QRStatus> qrStatus = QRStatus.loading.obs;

  void loadQRCode() async {
    timer?.cancel();
    timer = null;
    try {
      qrStatus.value = QRStatus.loading;

      var result = await HttpClient.instance.getJson(
        "https://passport.bilibili.com/x/passport-login/web/qrcode/generate",
        header: passportHeaders,
      );
      if (isClosed) return;
      if (result["code"] != 0) {
        throw result["message"];
      }
      qrcodeKey = result["data"]["qrcode_key"];
      qrcodeUrl.value = result["data"]["url"];
      qrStatus.value = QRStatus.unscanned;
      startPoll();
    } catch (e) {
      if (isClosed) return;
      Log.logPrint(e);
      SmartDialog.showToast(e.toString());
      qrStatus.value = QRStatus.failed;
    }
  }

  void startPoll() {
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        pollQRStatus();
      },
    );
  }

  void pollQRStatus() async {
    if (_polling || isClosed || qrcodeKey.isEmpty) return;
    _polling = true;
    try {
      var response = await HttpClient.instance.get(
        "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
        queryParameters: {
          "qrcode_key": qrcodeKey,
        },
        header: passportHeaders,
      );
      if (isClosed) return;
      if (response.data["code"] != 0) {
        throw response.data["message"];
      }
      var data = response.data["data"];
      var code = data["code"];
      if (code == 0) {
        timer?.cancel();
        timer = null;
        var cookieStr = extractCookies(
          response.headers["set-cookie"],
          callbackUrl: data["url"]?.toString(),
        );
        if (cookieStr.isNotEmpty) {
          Log.i(cookieStr);
          BiliBiliAccountService.instance.setCookie(cookieStr);
          await BiliBiliAccountService.instance.loadUserInfo();
          if (!isClosed) {
            Get.back();
          }
        }
      } else if (code == 86038) {
        qrStatus.value = QRStatus.expired;
        qrcodeKey = "";
        timer?.cancel();
        timer = null;
      } else if (code == 86090) {
        qrStatus.value = QRStatus.scanned;
      }
    } catch (e) {
      if (isClosed) return;
      Log.logPrint(e);
      SmartDialog.showToast(e.toString());
    } finally {
      _polling = false;
    }
  }

  @override
  void onClose() {
    timer?.cancel();
    super.onClose();
  }
}
