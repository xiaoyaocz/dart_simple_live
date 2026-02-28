import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';

class DeepLinkService extends GetxService {
  static DeepLinkService get instance => Get.find<DeepLinkService>();

  final AppLinks _appLinks = AppLinks();
  final ParseController _parseController = ParseController();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void onInit() {
    _initDeepLinks();
    super.onInit();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e, stackTrace) {
      Log.e("读取初始 Deep Link 失败: $e", stackTrace);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (error, stackTrace) {
        Log.logPrint("Deep Link 监听异常: $error");
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != "simplelive") {
      return;
    }
    Log.i("接收到 Deep Link: $uri");
    switch (uri.host) {
      case "open":
        await _handleOpenLink(uri);
        return;
      case "room":
        _handleRoomLink(uri);
        return;
      default:
        Log.w("忽略不支持的 deep link host: ${uri.host}");
    }
  }

  /// 供 AppIntentService 从原生 App Intent 触发
  Future<void> handleDeepLinkFromIntent(Uri uri) async {
    await _handleDeepLink(uri);
  }

  Future<void> _handleOpenLink(Uri uri) async {
    final candidates = _collectOpenTargets(uri);
    if (candidates.isEmpty) {
      SmartDialog.showToast("链接不能为空");
      return;
    }

    for (final target in candidates) {
      final parseResult = await _parseController.parse(target);
      if (parseResult.isEmpty || parseResult.first == "") {
        continue;
      }
      final roomId = parseResult.first.toString();
      final site = parseResult[1];
      if (site is! Site) {
        continue;
      }
      AppNavigator.toLiveRoomDetail(site: site, roomId: roomId);
      return;
    }

    SmartDialog.showToast("无法解析此链接");
  }

  List<String> _collectOpenTargets(Uri uri) {
    final result = <String>{};

    void addTarget(String? value) {
      if (value == null) {
        return;
      }
      final text = value.trim();
      if (text.isEmpty) {
        return;
      }
      result.add(text);
      result.add(text.replaceAll("+", " "));
      try {
        result.add(Uri.decodeComponent(text));
      } catch (_) {}
      try {
        result.add(Uri.decodeComponent(text.replaceAll("+", " ")));
      } catch (_) {}
    }

    addTarget(uri.queryParameters["url"]);

    if (uri.query.isNotEmpty) {
      addTarget(uri.query);
      if (uri.query.startsWith("url=")) {
        addTarget(uri.query.substring(4));
      }
    }

    final rawUri = uri.toString();
    final markerIndex = rawUri.indexOf("?url=");
    if (markerIndex >= 0) {
      addTarget(rawUri.substring(markerIndex + 5));
    }

    if (uri.fragment.isNotEmpty) {
      addTarget(uri.fragment);
      final queryUrl = uri.queryParameters["url"] ?? "";
      if (queryUrl.isNotEmpty) {
        addTarget("$queryUrl#${uri.fragment}");
      }
    }

    final urlRegExp = RegExp(r"https?://[^\s'<>]+");
    for (final text in result.toList()) {
      final match = urlRegExp.firstMatch(text);
      if (match != null) {
        addTarget(match.group(0));
      }
    }

    return result.toList();
  }

  void _handleRoomLink(Uri uri) {
    final siteId = (uri.queryParameters["site"] ?? "").trim().toLowerCase();
    final roomId = (uri.queryParameters["roomId"] ?? "").trim();
    if (siteId.isEmpty || roomId.isEmpty) {
      SmartDialog.showToast("链接参数不完整");
      return;
    }

    final site = _resolveSite(siteId);
    if (site == null) {
      SmartDialog.showToast("不支持的平台: $siteId");
      return;
    }
    AppNavigator.toLiveRoomDetail(site: site, roomId: roomId);
  }

  Site? _resolveSite(String siteId) {
    switch (siteId) {
      case Constant.kBiliBili:
      case Constant.kDouyu:
      case Constant.kHuya:
      case Constant.kDouyin:
        return Sites.allSites[siteId];
      default:
        return null;
    }
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}
