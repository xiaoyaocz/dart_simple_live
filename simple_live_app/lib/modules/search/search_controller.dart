import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/services/search_web_session.dart';
import 'package:simple_live_app/services/danmaku_web_scripts.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';
import 'package:simple_live_app/modules/search/search_web_navigation.dart';
import 'package:simple_live_app/routes/app_navigation.dart';

class AppSearchController extends GetxController {
  final selectedSite = Rxn<Site>();
  final roomId = RxnString();
  final webViewVisible = true.obs;
  final webViewLoading = false.obs;
  final webViewError = RxnString();
  final webViewRevision = 0.obs;
  InAppWebViewController? webViewController;
  Future<WebViewEnvironment?>? _webViewEnvironment;
  Timer? _loadTimer;
  bool _closing = false;
  bool _openingRoom = false;
  bool _directConnection = false;
  Uri? _navigationUrl;
  Uri? _loadingUrl;
  bool _httpErrorForNavigation = false;

  Uri get webViewUrl =>
      _navigationUrl ?? SearchRoomUrl.homeUriFor(selectedSite.value!.id);

  bool isCurrentWebView(InAppWebViewController? view, int revision) =>
      !_closing && !isClosed && webViewRevision.value == revision &&
      (identical(webViewController, view) ||
          (webViewController != null && view != null &&
              // Windows creates a fresh Dart wrapper for onWebViewCreated,
              // while navigation callbacks reuse another wrapper. Their
              // underlying platform controller identifies the actual WebView.
              identical(webViewController!.platform, view.platform)));

  bool _isCurrent(InAppWebViewController? view, int revision) =>
      isCurrentWebView(view, revision);

  Future<WebViewEnvironment?> get webViewEnvironment =>
      _webViewEnvironment ??= _createWebViewEnvironment();

  Future<WebViewEnvironment?> _createWebViewEnvironment() async {
    if (!Platform.isWindows) return null;
    final revision = webViewRevision.value;
    final directConnection = _directConnection;
    try {
      final creation = SearchWebSession.create(
        siteId: selectedSite.value?.id, direct: directConnection);
      try {
        return await creation.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        // 超时不能取消原生创建；迟到的环境创建成功后仍需释放。
        unawaited(creation
            .then((environment) => environment.dispose())
            .catchError((Object error, StackTrace stackTrace) {
          Log.e('释放超时网页环境失败：$error', stackTrace);
        }));
        rethrow;
      }
    } catch (error, stackTrace) {
      Log.e('搜索页 WebView2 环境启动失败：$error', stackTrace);
      if (!isClosed && webViewRevision.value == revision) {
        final code =
            error is PlatformException ? int.tryParse(error.code) : null;
        final detail = code == null
            ? ''
            : '（错误码 0x${code.toUnsigned(32).toRadixString(16).padLeft(8, '0')}）';
        failLoading('网页组件启动失败，请点击右上角刷新重试$detail');
      }
      rethrow;
    }
  }

  void selectSite(Site site) {
    if (_closing || isClosed) return;
    // Reopening search must not replace the profile that holds this site's login.
    final direct = SearchWebSession.usesDirect(site.id);
    if (direct != _directConnection) _disposeWebViewEnvironment();
    _directConnection = direct;
    webViewController = null;
    _navigationUrl = null;
    webViewRevision.value++;
    webViewVisible.value = true;
    startLoading(SearchRoomUrl.homeUriFor(site.id));
    roomId.value = null;
    selectedSite.value = site;
  }

  void updateUrl(Uri? uri) {
    if (_closing || isClosed || !webViewVisible.value) return;
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      _navigationUrl = uri;
    }
    final site = selectedSite.value;
    final detectedRoomId = site == null || uri == null
        ? null
        : SearchRoomUrl.roomIdFor(site.id, uri);
    roomId.value = detectedRoomId;
  }

  void reset() {
    webViewRevision.value++;
    webViewController?.removeJavaScriptHandler(handlerName: SearchWebNavigation.handlerName);
    _loadTimer?.cancel();
    webViewLoading.value = false;
    webViewError.value = null;
    webViewVisible.value = true;
    roomId.value = null;
    selectedSite.value = null;
    _navigationUrl = null;
    _loadingUrl = null;
    _httpErrorForNavigation = false;
    webViewController = null;
  }

  Future<void> goBackInWebView() async {
    final view = webViewController;
    final revision = webViewRevision.value;
    if (!_isCurrent(view, revision) || view == null) return;
    if (await view.canGoBack() && _isCurrent(view, revision)) {
      await view.goBack();
    }
  }

  Future<void> reloadWebView() async {
    if (_closing || isClosed) return;
    final recreate = Platform.isWindows &&
        (webViewController == null || webViewError.value != null);
    if (recreate) {
      webViewController = null;
      _disposeWebViewEnvironment();
      webViewRevision.value++;
    }
    startLoading();
    if (!recreate) await webViewController?.reload();
  }

  void _disposeWebViewEnvironment() {
    final pending = _webViewEnvironment;
    _webViewEnvironment = null;
    if (pending == null) return;
    unawaited(pending.then((environment) async {
      await environment?.dispose();
    }).catchError((Object error, StackTrace stackTrace) {
      Log.e('释放搜索网页环境失败：$error', stackTrace);
    }));
  }

  void startLoading([Uri? uri]) {
    if (_closing || isClosed) return;
    _loadingUrl = uri ?? _navigationUrl;
    _httpErrorForNavigation = false;
    webViewLoading.value = true;
    webViewError.value = null;
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 20), () {
      if (webViewLoading.value) {
        if (webViewController != null && _retryWithDirectConnection()) return;
        failLoading('网页加载超时，请检查网络后重新加载');
      }
    });
  }

  bool _retryWithDirectConnection() {
    // 抖音进入播放器时网页被隐藏；此时重建会使 openRoom 无法恢复旧视图。
    if (!Platform.isWindows || _directConnection || _closing || isClosed ||
        !webViewVisible.value || selectedSite.value == null) {
      return false;
    }
    Log.w('搜索网页网络连接失败，尝试直连：$_navigationUrl');
    _directConnection = true;
    webViewController = null;
    _disposeWebViewEnvironment();
    webViewRevision.value++;
    startLoading();
    return true;
  }

  void updateLoadProgress(int progress) {
    // Windows 插件的 66 对应 DOMContentLoaded；100 在失败时也会发送。
    // 页面已可操作后不再等待广告、图片等非必要资源，避免误报超时。
    if (Platform.isWindows && progress >= 66 && progress < 100) {
      finishLoading();
    }
  }

  void handleLoadError(WebResourceRequest request, WebResourceError error) {
    if (_closing || isClosed || request.isForMainFrame != true) return;
    // 快速跳转或刷新取消的是旧导航，不是新页面加载失败。
    if (error.type == WebResourceErrorType.CANCELLED) return;
    Log.w('搜索网页加载失败：${request.url} ${error.type} ${error.description}');
    final connectionError = {
      // WebView2 未映射部分 Chromium 网络错误（包括代理连接失败）。
      WebResourceErrorType.UNKNOWN,
      WebResourceErrorType.TIMEOUT,
      WebResourceErrorType.HOST_LOOKUP,
      WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
      WebResourceErrorType.SERVER_UNREACHABLE,
      WebResourceErrorType.CONNECTION_ABORTED,
      WebResourceErrorType.RESET,
      WebResourceErrorType.NETWORK_CONNECTION_LOST,
      WebResourceErrorType.IO,
      WebResourceErrorType.VALID_PROXY_AUTHENTICATION_REQUIRED,
    }.contains(error.type);
    if (connectionError && _retryWithDirectConnection()) return;
    failLoading('网页加载失败（${error.type}），请检查网络后重新加载');
  }

  void handleHttpError(WebResourceRequest request, WebResourceResponse response) {
    if (_closing || isClosed || request.isForMainFrame != true ||
        !_matchesLoadingUrl(request.url)) {
      return;
    }
    _httpErrorForNavigation = true;
    Log.w('搜索网页 HTTP 错误：${request.url} ${response.statusCode}');
    failLoading('网站返回错误（HTTP ${response.statusCode}），请稍后重新加载');
  }

  // Compare document URLs, not fragments: a hash change is not a new request.
  // A late old-URL callback must not settle or fail the newer navigation.
  bool _matchesLoadingUrl(Uri? uri) =>
      uri == null || _loadingUrl == null ||
      uri.removeFragment() == _loadingUrl!.removeFragment();

  bool finishLoading([Uri? uri]) {
    if (_closing || isClosed || !_matchesLoadingUrl(uri)) return false;
    _loadTimer?.cancel();
    webViewLoading.value = false;
    // Android also finishes documents served with HTTP 4xx/5xx. Only a new
    // navigation resets that failure; a late success may still clear a timeout.
    if (!_httpErrorForNavigation) webViewError.value = null;
    return true;
  }

  void failLoading(String message) {
    if (_closing || isClosed) return;
    _loadTimer?.cancel();
    webViewLoading.value = false;
    webViewError.value = message;
  }

  @override
  void onClose() {
    if (_closing) return;
    _closing = true;
    webViewRevision.value++;
    webViewController?.removeJavaScriptHandler(handlerName: SearchWebNavigation.handlerName);
    webViewController = null;
    _loadTimer?.cancel();
    _disposeWebViewEnvironment();
    super.onClose();
  }

  Future<bool> openPopup(CreateWindowAction action) async {
    final url = action.request.url;
    if (_closing || isClosed || url == null || webViewController == null) return false;
    updateUrl(url);
    // Windows 插件在返回 false 后执行默认导航，不能在两端重复 loadUrl。
    if (!Platform.isWindows) {
      await webViewController!.loadUrl(urlRequest: action.request);
    }
    return false;
  }

  NavigationActionPolicy handleNavigation(NavigationAction action) {
    if (action.isForMainFrame) updateUrl(action.request.url);
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> openCurrentRoom() async {
    final view = webViewController;
    final revision = webViewRevision.value;
    if (view == null || !webViewVisible.value || !_isCurrent(view, revision)) {
      return;
    }
    try {
      // 快捷键不依赖顶部按钮是否已出现：先读取真实地址，补上遗漏的导航回调。
      final uri = await view.getUrl();
      if (!_isCurrent(view, revision)) return;
      if (uri != null) updateUrl(uri);
      await openRoom();
    } catch (error, stack) {
      Log.e('打开当前网页直播间失败：$error', stack);
    }
  }

  Future<void> openRoom({String? detectedRoomId}) async {
    if (_closing || isClosed || _openingRoom) return;
    final site = selectedSite.value;
    final id = detectedRoomId ?? roomId.value;
    if (site == null || id == null) return;
    if (Platform.isWindows || site.id == Constant.kDouyin) {
      final webView = webViewController;
      final revision = webViewRevision.value;
      _openingRoom = true;
      try {
        if (Platform.isWindows) {
          await webView?.evaluateJavascript(source: DanmakuWebScripts.holdMedia);
        } else {
          await webView?.pause();
        }
        if (!_isCurrent(webView, revision)) return;
        webViewVisible.value = false;
        await WidgetsBinding.instance.endOfFrame;
        if (!_isCurrent(webView, revision)) return;
        await AppNavigator.toLiveRoomDetail(site: site, roomId: id);
      } finally {
        if (_isCurrent(webView, revision)) {
          webViewVisible.value = true;
          await WidgetsBinding.instance.endOfFrame;
          if (_isCurrent(webView, revision)) {
            if (Platform.isWindows) {
              await webView?.evaluateJavascript(source: DanmakuWebScripts.restoreMedia);
            } else {
              await webView?.resume();
            }
          }
        }
        _openingRoom = false;
      }
      return;
    }
    AppNavigator.toLiveRoomDetail(site: site, roomId: id);
  }
}
