import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';

class _WebView implements InAppWebViewController {
  final backResult = Completer<bool>();
  final pauseResult = Completer<void>();
  int pauseCalls = 0;
  int mediaHoldCalls = 0;
  int backCalls = 0;
  int loadCalls = 0;
  @override
  JavaScriptHandlerCallback? removeJavaScriptHandler({required String handlerName}) => null;
  @override
  Future<bool> canGoBack() => backResult.future;
  @override
  Future<void> goBack() async { backCalls++; }
  @override
  Future<void> pause() { pauseCalls++; return pauseResult.future; }
  @override
  Future<dynamic> evaluateJavascript({required String source, ContentWorld? contentWorld}) {
    mediaHoldCalls++;
    return pauseResult.future;
  }
  @override
  Future<void> loadUrl({required URLRequest urlRequest,
      WebUri? allowingReadAccessTo, Uri? iosAllowingReadAccessTo}) async { loadCalls++; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('100次静音准备期间重复打开并退出，不挂起网页脚本且不进行迟到导航', () async {
    for (var i = 0; i < 100; i++) {
      final controller = AppSearchController();
      controller.selectSite(Sites.allSites[Constant.kDouyin]!);
      final web = _WebView();
      controller.webViewController = web;
      final opening = controller.openRoom(detectedRoomId: '123');
      await controller.openRoom(detectedRoomId: '456');
      controller.reset();
      web.pauseResult.complete();
      await opening;
      expect(web.pauseCalls, 0);
      expect(web.mediaHoldCalls, 1);
      expect(controller.webViewVisible.value, true);
      controller.onClose();
    }
  });
  test('100次退出重建后，旧网页后退结果不得导航新网页', () async {
    final controller = AppSearchController();
    for (var i = 0; i < 100; i++) {
      controller.selectSite(Sites.allSites[Constant.kDouyin]!);
      final old = _WebView();
      controller.webViewController = old;
      final navigation = controller.goBackInWebView();
      controller.reset();
      controller.selectSite(Sites.allSites[Constant.kDouyin]!);
      final current = _WebView();
      controller.webViewController = current;
      old.backResult.complete(true);
      await navigation;
      expect(old.backCalls, 0);
      expect(current.backCalls, 0);
    }
    controller.onClose();
  });

  test('弹窗交给原生默认导航，Dart不得再次loadUrl', () async {
    final controller = AppSearchController();
    controller.selectSite(Sites.allSites[Constant.kDouyin]!);
    final web = _WebView();
    controller.webViewController = web;
    expect(await controller.openPopup(CreateWindowAction(windowId: 1, isForMainFrame: true,
        request: URLRequest(url: WebUri('https://live.douyin.com/123')))), false);
    expect(web.loadCalls, 0);
    expect(controller.roomId.value, '123');
    controller.onClose();
  });
}
