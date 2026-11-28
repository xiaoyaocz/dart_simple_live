import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';

class ParseController extends GetxController {
  final TextEditingController roomJumpToController = TextEditingController();
  final TextEditingController getUrlController = TextEditingController();
  Timer? _clipboardTimer;
  String? _lastClipboardText;
  bool _checkingClipboard = false;
  bool _showingPrompt = false;

  @override
  void onReady() {
    super.onReady();
    _checkClipboard();
    _clipboardTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkClipboard(),
    );
  }

  Future<void> _checkClipboard() async {
    if (_checkingClipboard ||
        _showingPrompt ||
        Get.currentRoute != RoutePath.kTools) {
      return;
    }
    _checkingClipboard = true;
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (text == null || text == _lastClipboardText) return;
      _lastClipboardText = text;
      String? link;
      for (final match
          in RegExp(r'https?://[^\s，。<>"\u0027]+').allMatches(text)) {
        final candidate =
            match.group(0)!.replaceFirst(RegExp(r'[)\]】；;]+$'), '');
        final host = Uri.tryParse(candidate)?.host;
        if ({
          'live.bilibili.com',
          'b23.tv',
          'www.huya.com',
          'huya.com',
          'www.douyu.com',
          'douyu.com',
          'live.douyin.com',
          'www.douyin.com',
          'v.douyin.com',
          'webcast.amemv.com',
        }.contains(host)) {
          link = candidate;
          break;
        }
      }
      if (link == null) return;
      final result = await parse(link);
      if (result.isEmpty ||
          result.first == '' ||
          isClosed ||
          Get.currentRoute != RoutePath.kTools) {
        return;
      }
      _showingPrompt = true;
      final open = await Utils.showAlertDialog(
        link,
        title: '检测到直播间链接',
        confirm: '打开直播间',
        cancel: '留在此页',
        selectable: true,
        constraints: const BoxConstraints(maxWidth: 520),
        maxContentHeight: 144,
        doubleTapConfirm: true,
      );
      if (open && !isClosed) {
        AppNavigator.toLiveRoomDetail(site: result[1], roomId: result.first);
      }
    } catch (e) {
      Log.logPrint(e);
    } finally {
      _showingPrompt = false;
      _checkingClipboard = false;
    }
  }

  @override
  void onClose() {
    _clipboardTimer?.cancel();
    roomJumpToController.dispose();
    getUrlController.dispose();
    super.onClose();
  }

  void jumpToRoom(String e) async {
    if (e.isEmpty) {
      SmartDialog.showToast("链接不能为空");
      return;
    }
    // 隐藏键盘
    FocusManager.instance.primaryFocus?.unfocus();

    var parseResult = await parse(e);
    if (parseResult.isEmpty || parseResult.first == "") {
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
    if (parseResult.isEmpty || parseResult.first == "") {
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

  Future<List> parse(String url) async {
    var id = "";
    if (url.contains("bilibili.com")) {
      var regExp = RegExp(r"bilibili\.com/([\d|\w]+)");
      id = regExp.firstMatch(url)?.group(1) ?? "";
      return [id, Sites.allSites[Constant.kBiliBili]!];
    }

    if (url.contains("b23.tv")) {
      var btvReg = RegExp(r"https?:\/\/b23.tv\/[0-9a-z-A-Z]+");
      var u = btvReg.firstMatch(url)?.group(0) ?? "";
      var location = await getLocation(u);

      return await parse(location);
    }

    if (url.contains("douyu.com")) {
      var regExp = RegExp(r"douyu\.com/([\d|\w]+)");
      // 适配 topic_url
      if (url.contains("topic")) {
        regExp = RegExp(r"[?&]rid=([\d]+)");
      }
      id = regExp.firstMatch(url)?.group(1) ?? "";

      return [id, Sites.allSites[Constant.kDouyu]!];
    }
    if (url.contains("huya.com")) {
      var regExp = RegExp(r"huya\.com/([\d|\w]+)");
      id = regExp.firstMatch(url)?.group(1) ?? "";

      return [id, Sites.allSites[Constant.kHuya]!];
    }
    if (url.contains("live.douyin.com")) {
      var regExp = RegExp(r"live\.douyin\.com/([\d|\w]+)");
      id = regExp.firstMatch(url)?.group(1) ?? "";

      return [id, Sites.allSites[Constant.kDouyin]!];
    }
    if (url.contains("www.douyin.com/root/live/")) {
      var regExp = RegExp(r"www\.douyin\.com/root/live/(\d+)");
      id = regExp.firstMatch(url)?.group(1) ?? "";
      return [id, Sites.allSites[Constant.kDouyin]!];
    }
    if (url.contains("webcast.amemv.com")) {
      var regExp = RegExp(r"reflow/(\d+)");
      id = regExp.firstMatch(url)?.group(1) ?? "";
      return [id, Sites.allSites[Constant.kDouyin]!];
    }
    if (url.contains("v.douyin.com")) {
      var regExp = RegExp(r"http.?://v.douyin.com/[\d\w]+/");
      var u = regExp.firstMatch(url)?.group(0) ?? "";
      var location = await getLocation(u);
      return await parse(location);
    }

    return [];
  }

  Future<String> getLocation(String url) async {
    try {
      if (url.isEmpty) return "";
      await Dio().get(
        url,
        options: Options(
          followRedirects: false,
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 300 && status < 400) {
        var redirectUrl = e.response?.headers.value("Location");
        if (redirectUrl != null) {
          return redirectUrl;
        }
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return "";
  }
}
