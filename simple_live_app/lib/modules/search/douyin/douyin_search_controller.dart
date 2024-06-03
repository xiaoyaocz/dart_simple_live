import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DouyinSearchController extends BaseController {
  InAppWebViewController? webViewController;

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
  }

  RxList<LiveRoomItem> list = <LiveRoomItem>[].obs;

  String keyword = "";

  /// 搜索模式，0=直播间，1=主播
  var searchMode = 0.obs;
  final Site site;
  DouyinSearchController(
    this.site,
  );

  var searchUrl = "https://www.douyin.com/search/dnf?type=live";

  void reloadWebView() {
    if (keyword.isEmpty) {
      return;
    }
    searchUrl =
        "https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?type=live";
    if (Platform.isAndroid || Platform.isIOS) {
      webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: Uri.parse(searchUrl),
        ),
      );
    }
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) async {
    pageLoadding.value = false;
  }

  void onLoadStart(InAppWebViewController controller, Uri? uri) async {
    pageLoadding.value = true;
  }

  Future<bool?> onCreateWindow(InAppWebViewController controller,
      CreateWindowAction createWindowAction) async {
    if (createWindowAction.request.url?.host == "live.douyin.com") {
      {
        var regExp = RegExp(r"live\.douyin\.com/([\d|\w]+)");
        var id = regExp
                .firstMatch(createWindowAction.request.url.toString())
                ?.group(1) ??
            "";

        AppNavigator.toLiveRoomDetail(site: site, roomId: id);
        return false;
      }
    }

    return false;
  }

  void openBrowser() {
    launchUrlString(searchUrl);
    Get.offAndToNamed(RoutePath.kTools);
  }
}
