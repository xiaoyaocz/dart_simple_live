import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';

class _WebView implements InAppWebViewController {
  @override
  JavaScriptHandlerCallback? removeJavaScriptHandler(
          {required String handlerName}) =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('网页晚到的成功应清除之前的超时提示', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.failLoading('网页加载超时');
    controller.finishLoading();
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isFalse);
  });

  testWidgets('系统代理加载超时应自动重建网页而非直接报错', (tester) async {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    controller.webViewController = _WebView();
    final revision = controller.webViewRevision.value;
    await tester.pump(const Duration(seconds: 21));
    expect(controller.webViewRevision.value, revision + 1);
    controller.webViewController = _WebView();
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isTrue);
    await tester.pump(const Duration(seconds: 21));
    expect(controller.webViewLoading.value, isFalse);
    expect(controller.webViewError.value, isNotNull);
    expect(controller.webViewRevision.value, revision + 1);
  });

  testWidgets('主文档已可操作时，慢资源不应导致加载超时', (tester) async {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    controller.webViewController = _WebView();
    final revision = controller.webViewRevision.value;
    controller.updateLoadProgress(66);
    await tester.pump(const Duration(seconds: 25));
    expect(controller.webViewLoading.value, isFalse);
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewRevision.value, revision);
  });

  test('失败也发送的100进度不能当作成功', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.startLoading();
    controller.updateLoadProgress(100);
    expect(controller.webViewLoading.value, isTrue);
    controller.failLoading('连接失败');
    controller.updateLoadProgress(100);
    expect(controller.webViewError.value, isNotNull);
  });

  test('WebView2代理连接失败返回UNKNOWN时也应尝试直连', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kDouyin]!);
    final revision = controller.webViewRevision.value;
    controller.handleLoadError(
      WebResourceRequest(
          url: WebUri(controller.webViewUrl.toString()), isForMainFrame: true),
      WebResourceError(
          type: WebResourceErrorType.UNKNOWN, description: '代理连接失败'),
    );
    expect(controller.webViewRevision.value, revision + 1);
    expect(controller.webViewError.value, isNull);
  });

  testWidgets('抖音网页隐藏进入播放器后，超时不得重建导致返回空白', (tester) async {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kDouyin]!);
    controller.webViewController = _WebView();
    final revision = controller.webViewRevision.value;
    controller.webViewVisible.value = false;
    await tester.pump(const Duration(seconds: 21));
    expect(controller.webViewRevision.value, revision);
    expect(controller.webViewController, isNotNull);
    controller.webViewVisible.value = true;
    expect(controller.webViewVisible.value, isTrue);
  });

  test('快速导航取消旧请求不应误报失败或切换网络', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    final revision = controller.webViewRevision.value;
    controller.handleLoadError(
      WebResourceRequest(
          url: WebUri('https://www.huya.com/'), isForMainFrame: true),
      WebResourceError(
          type: WebResourceErrorType.CANCELLED, description: '旧导航取消'),
    );
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isTrue);
    expect(controller.webViewRevision.value, revision);
  });

  test('四个平台网络错误只自动恢复一次，重建保留当前搜索地址', () {
    for (final siteId in [
      Constant.kHuya,
      Constant.kDouyin,
      Constant.kDouyu,
      Constant.kBiliBili
    ]) {
      final controller = AppSearchController();
      controller.selectSite(Sites.allSites[siteId]!);
      final search =
          Uri.https(controller.webViewUrl.host, '/search', {'keyword': '测试'});
      controller.updateUrl(search);
      final revision = controller.webViewRevision.value;
      final request = WebResourceRequest(
          url: WebUri(search.toString()), isForMainFrame: true);
      final error = WebResourceError(
          type: WebResourceErrorType.RESET, description: '连接重置');
      controller.handleLoadError(request, error);
      expect(controller.webViewRevision.value, revision + 1);
      expect(controller.webViewUrl, search);
      expect(controller.webViewLoading.value, isTrue);
      expect(controller.webViewError.value, isNull);
      controller.handleLoadError(request, error);
      expect(controller.webViewRevision.value, revision + 1);
      expect(controller.webViewLoading.value, isFalse);
      expect(controller.webViewError.value, contains('RESET'));
      controller.onClose();
    }
  });

  test('子资源失败不应覆盖主页面状态或触发直连', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kDouyu]!);
    final revision = controller.webViewRevision.value;
    final request = WebResourceRequest(
        url: WebUri('https://example.com/ad.png'), isForMainFrame: false);
    controller.handleLoadError(
        request,
        WebResourceError(
            type: WebResourceErrorType.RESET, description: '广告加载失败'));
    controller.handleHttpError(request, WebResourceResponse(statusCode: 500));
    expect(controller.webViewRevision.value, revision);
    expect(controller.webViewError.value, isNull);
  });

  testWidgets('主页面HTTP错误及时结束等待，不自动绕过网站拒绝', (tester) async {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kDouyu]!);
    final revision = controller.webViewRevision.value;
    controller.handleHttpError(
      WebResourceRequest(
          url: WebUri(controller.webViewUrl.toString()), isForMainFrame: true),
      WebResourceResponse(statusCode: 403),
    );
    await tester.pump(const Duration(seconds: 25));
    expect(controller.webViewLoading.value, isFalse);
    expect(controller.webViewError.value, contains('403'));
    expect(controller.webViewRevision.value, revision);
  });

  test('重建保留当前地址，但更换平台从该平台首页开始', () async {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kDouyu]!);
    final search = Uri.parse('https://www.douyu.com/search/?kw=test');
    controller.updateUrl(search);
    controller.failLoading('失败');
    await controller.reloadWebView();
    expect(controller.webViewUrl, search);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    expect(controller.webViewUrl.toString(), 'https://www.huya.com/');
  });
}
