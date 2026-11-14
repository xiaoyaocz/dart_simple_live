import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_core/simple_live_core.dart';

class ParseController extends GetxController {
  ParseController({Dio? redirectClient})
      : _redirectClient = redirectClient ?? Dio();

  static const int _maxRedirects = 5;

  /// 短链解析的最大递归次数，防止短链之间互相跳转导致无限递归。
  static const int _maxParseDepth = 3;
  final Dio _redirectClient;
  final TextEditingController roomJumpToController = TextEditingController();
  final TextEditingController getUrlController = TextEditingController();

  void jumpToRoom(String e) async {
    if (e.isEmpty) {
      SmartDialog.showToast("链接不能为空");
      return;
    }
    // 隐藏键盘
    FocusManager.instance.primaryFocus?.unfocus();

    var parseResult = await parse(e);
    if (parseResult.isEmpty || parseResult.first.toString().isEmpty) {
      SmartDialog.showToast("无法解析此链接");
      return;
    }

    // 延迟200ms跳转，等待键盘隐藏
    Future.delayed(const Duration(milliseconds: 200), () {
      Site site = parseResult[1];
      AppNavigator.toLiveRoomDetail(site: site, roomId: parseResult.first);
    });
  }

  void getPlayUrl(String e) async {
    if (e.isEmpty) {
      SmartDialog.showToast("链接不能为空");
      return;
    }
    var parseResult = await parse(e);
    if (parseResult.isEmpty || parseResult.first.toString().isEmpty) {
      SmartDialog.showToast("无法解析此链接");
      return;
    }
    Site site = parseResult[1];
    try {
      SmartDialog.showLoading(msg: "");
      var detail = await site.liveSite.getRoomDetail(roomId: parseResult.first);
      var qualites = await site.liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);
      if (qualites.isEmpty) {
        SmartDialog.showToast("读取直链失败,无法读取清晰度");

        return;
      }
      var result = await Get.dialog(SimpleDialog(
        title: const Text("选择清晰度"),
        children: qualites
            .map(
              (e) => ListTile(
                title: Text(
                  e.quality,
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  Get.back(result: e);
                },
              ),
            )
            .toList(),
      ));
      if (result == null) {
        return;
      }
      SmartDialog.showLoading(msg: "");
      var playUrl =
          await site.liveSite.getPlayUrls(detail: detail, quality: result);
      SmartDialog.dismiss(status: SmartStatus.loading);
      await Get.dialog(SimpleDialog(
        title: const Text("选择线路"),
        children: playUrl.urls
            .map(
              (e) => ListTile(
                title: Text(
                  "线路${playUrl.urls.indexOf(e) + 1}",
                ),
                subtitle: Text(
                  e,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: e));
                  Get.back();
                  SmartDialog.showToast("已复制直链");
                },
              ),
            )
            .toList(),
      ));
    } catch (e) {
      SmartDialog.showToast("读取直链失败");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  Future<List> parse(String url, {int depth = 0}) {
    return resolveRoomUrl(
      url,
      redirectClient: _redirectClient,
      depth: depth,
    );
  }

  /// 解析直播间链接（支持分享口令提取与短链重定向），返回 `[roomId, Site]` 或空列表。
  static Future<List> resolveRoomUrl(
    String url, {
    Dio? redirectClient,
    int depth = 0,
  }) async {
    final extractedUrl = extractHttpUrl(url);
    if (extractedUrl.isNotEmpty) {
      url = extractedUrl;
    }

    final parsed = LiveUrlParser.parse(url);
    if (parsed == null) {
      return [];
    }

    final client = redirectClient ?? Dio();
    try {
      // 快手短链沿用原有流程，其重定向目标需通过受信域名校验。
      if (parsed.isShortLink && parsed.siteId == LiveUrlParser.siteKuaishou) {
        final roomId = await _resolveKuaishouRoomIdWith(client, url);
        if (roomId.isEmpty) {
          return [];
        }
        return [roomId, Sites.allSites[LiveUrlParser.siteKuaishou]!];
      }

      // 短链需要先跟随重定向，再对最终地址重新解析。
      if (parsed.isShortLink) {
        if (depth >= _maxParseDepth) {
          return [];
        }
        final location = await _getLocationWith(client, parsed.uri.toString());
        if (location.isEmpty) {
          return [];
        }
        return resolveRoomUrl(
          location,
          redirectClient: client,
          depth: depth + 1,
        );
      }

      if (parsed.roomId.isEmpty) {
        return [];
      }
      final site = Sites.allSites[parsed.siteId];
      if (site == null) {
        return [];
      }
      return [parsed.roomId, site];
    } finally {
      if (redirectClient == null) {
        client.close();
      }
    }
  }

  /// Resolves only known Kuaishou live-room links without account cookies.
  Future<String> resolveKuaishouRoomId(String value) =>
      _resolveKuaishouRoomIdWith(_redirectClient, value);

  static Future<String> _resolveKuaishouRoomIdWith(
    Dio client,
    String value,
  ) async {
    final initial = KuaishouLiveLink.parseHttpUrl(value);
    if (initial == null) {
      return "";
    }

    final directRoomId = KuaishouLiveLink.roomIdFromUri(initial);
    if (directRoomId != null) {
      return directRoomId;
    }
    if (!KuaishouLiveLink.isShortLink(initial)) {
      return "";
    }

    var current = initial;
    final visited = <String>{};
    try {
      for (var redirectCount = 0;
          redirectCount < _maxRedirects;
          redirectCount++) {
        if (!visited.add(current.toString())) {
          return "";
        }
        final response = await client.getUri<dynamic>(
          current,
          options: Options(
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
            headers: const <String, dynamic>{},
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
          ),
        );
        final statusCode = response.statusCode ?? 0;
        if (statusCode < 300 || statusCode >= 400) {
          return "";
        }
        final location = response.headers.value("location");
        if (location == null || location.trim().isEmpty) {
          return "";
        }

        final next = current.resolve(location.trim());
        if (!KuaishouLiveLink.isTrustedRedirectTarget(next)) {
          return "";
        }
        final roomId = KuaishouLiveLink.roomIdFromUri(next);
        if (roomId != null) {
          return roomId;
        }
        current = next;
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return "";
  }

  Future<String> getLocation(String url) =>
      _getLocationWith(_redirectClient, url);

  static Future<String> _getLocationWith(Dio client, String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) {
      return "";
    }
    var current = parsed;
    try {
      for (var redirectCount = 0;
          redirectCount < _maxRedirects;
          redirectCount++) {
        final response = await client.getUri<dynamic>(
          current,
          options: Options(
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
            // Short-link resolution must remain independent from login state.
            headers: const <String, dynamic>{},
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
          ),
        );
        final statusCode = response.statusCode ?? 0;
        if (statusCode < 300 || statusCode >= 400) {
          return current.toString();
        }
        final location = response.headers.value("location");
        if (location == null || location.trim().isEmpty) {
          return "";
        }
        current = current.resolve(location.trim());
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return "";
  }

  static String extractHttpUrl(String text) {
    // 正则排除常见的中文标点符号作为URL边界
    // 但不再进行二次清理，因为标点符号可能是用户名的合法部分
    // 例如：Cc_2365. 或 user!!! 等
    return RegExp(
          r"https?://[^\s<>\u3000，。！？、；：]+",
          caseSensitive: false,
        )
            .firstMatch(text)
            ?.group(0) ??
        "";
  }
}
