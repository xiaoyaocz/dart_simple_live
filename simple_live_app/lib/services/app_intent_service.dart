import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/deep_link_service.dart';

class AppIntentService extends GetxService {
  static const MethodChannel _channel =
      MethodChannel("com.xycz.simple-live/app_intents");

  @override
  void onInit() {
    super.onInit();
    if (!Platform.isIOS) {
      return;
    }
    _channel.setMethodCallHandler(_handleMethodCall);
    _notifyDartReady();
  }

  Future<void> _notifyDartReady() async {
    try {
      await _channel.invokeMethod("dartReady");
    } catch (e, stackTrace) {
      Log.e("AppIntentService 通知 dartReady 失败: $e", stackTrace);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != "onIntent") {
      return;
    }

    final payload = _toPayload(call.arguments);
    if (payload == null) {
      SmartDialog.showToast("无法解析此链接");
      return;
    }

    final uri = _buildDeepLinkUri(payload);
    if (uri == null) {
      SmartDialog.showToast("无法解析此链接");
      return;
    }

    await DeepLinkService.instance.handleDeepLinkFromIntent(uri);
  }

  Map<String, dynamic>? _toPayload(dynamic value) {
    if (value is! Map) {
      return null;
    }
    try {
      return value.map((key, val) => MapEntry("$key", val));
    } catch (_) {
      return null;
    }
  }

  Uri? _buildDeepLinkUri(Map<String, dynamic> payload) {
    final action = (payload["action"] ?? "").toString().trim().toLowerCase();
    if (action == "open") {
      final url = (payload["url"] ?? "").toString().trim();
      if (url.isEmpty) {
        return null;
      }
      return Uri(
        scheme: "simplelive",
        host: "open",
        queryParameters: {
          "url": url,
        },
      );
    }
    if (action == "room") {
      final site = (payload["site"] ?? "").toString().trim().toLowerCase();
      final roomId = (payload["roomId"] ?? "").toString().trim();
      if (site.isEmpty || roomId.isEmpty) {
        return null;
      }
      return Uri(
        scheme: "simplelive",
        host: "room",
        queryParameters: {
          "site": site,
          "roomId": roomId,
        },
      );
    }
    return null;
  }
}
