import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_page.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';

WebResourceRequest mainRequest(String url) => WebResourceRequest(
      url: WebUri(url),
      isForMainFrame: true,
    );

class _SearchController extends AppSearchController {
  @override
  Future<WebViewEnvironment?> get webViewEnvironment async => null;
}

Future<dynamic> nativeCall(int id, String method, dynamic args) async {
  const codec = StandardMethodCodec();
  final result = Completer<dynamic>();
  // ignore: deprecated_member_use
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'com.pichillilorenzo/flutter_inappwebview_$id',
    codec.encodeMethodCall(MethodCall(method, args)),
    (bytes) {
      try {
        result.complete(bytes == null ? null : codec.decodeEnvelope(bytes));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    },
  );
  return result.future;
}

void main() {
  for (final status in [403, 500]) {
    test('HTTP $status 后同次导航完成仍保留错误和重试状态', () {
      final controller = AppSearchController();
      addTearDown(controller.onClose);
      controller.updateUrl(Uri.parse('https://www.douyu.com/'));
      controller.startLoading();
      controller.handleHttpError(mainRequest('https://www.douyu.com/'),
          WebResourceResponse(statusCode: status));
      expect(controller.webViewError.value, contains('$status'));

      // Android onPageFinished always dispatches onLoadStop, even for HTTP errors.
      controller.finishLoading();
      expect(controller.webViewError.value, contains('$status'));
      expect(controller.webViewLoading.value, isFalse);
      controller.updateLoadProgress(66);
      expect(controller.webViewError.value, contains('$status'));
    });
  }

  test('HTTP失败后同地址新导航真正完成应清错', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.updateUrl(Uri.parse('https://www.douyu.com/'));
    controller.startLoading();
    controller.handleHttpError(mainRequest('https://www.douyu.com/'),
        WebResourceResponse(statusCode: 403));
    controller.startLoading();
    controller.finishLoading();
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isFalse);
  });

  test('新导航忽略旧URL迟到的HTTP错误并可成功完成', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    const oldUrl = 'https://www.douyu.com/search/?kw=old';
    const newUrl = 'https://www.douyu.com/search/?kw=new';
    controller.updateUrl(Uri.parse(oldUrl));
    controller.startLoading();
    controller.handleHttpError(
        mainRequest(oldUrl), WebResourceResponse(statusCode: 403));
    controller.updateUrl(Uri.parse(newUrl));
    controller.startLoading();
    controller.handleHttpError(
        mainRequest(oldUrl), WebResourceResponse(statusCode: 500));
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isTrue);
    controller.finishLoading();
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isFalse);
  });

  test('HTTP失败不影响下一导航网络超时后晚到成功清错', () {
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.startLoading();
    controller.handleHttpError(mainRequest('https://www.douyu.com/'),
        WebResourceResponse(statusCode: 403));
    controller.startLoading();
    controller.failLoading('网页加载超时');
    controller.finishLoading();
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isFalse);
  });
  group('SearchPage真实插件事件分发', () {
    const manager =
        MethodChannel('com.pichillilorenzo/flutter_inappwebview_manager');
    final channels = <MethodChannel>[];
    var nextId = 1900;
    late int id;
    setUp(() {
      WindowsInAppWebViewPlatform.registerWith();
      Get.testMode = true;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(manager, (call) async {
        if (call.method != 'createInAppWebView') return null;
        id = nextId++;
        for (final name in [
          'com.pichillilorenzo/custom_platform_view_$id',
          'com.pichillilorenzo/custom_platform_view_${id}_events',
          'com.pichillilorenzo/flutter_inappwebview_$id',
        ]) {
          final channel = MethodChannel(name);
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return id;
      });
    });
    tearDown(() {
      Get.reset();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(manager, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      channels.clear();
    });

    testWidgets('HTTP403加onLoadStop保留重新加载，下一导航成功才消失', (tester) async {
      final controller = _SearchController();
      Get.put<AppSearchController>(controller);
      controller.selectSite(Sites.allSites[Constant.kDouyu]!);
      await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
      await tester.pump();
      await tester.pump();
      final oldUrl = controller.webViewUrl.toString();
      await nativeCall(id, 'onLoadStart', {'url': oldUrl});
      await nativeCall(id, 'onReceivedHttpError', {
        'request': mainRequest(oldUrl).toMap(),
        'errorResponse': WebResourceResponse(statusCode: 403).toMap(),
      });
      await nativeCall(id, 'onLoadStop', {'url': oldUrl});
      await tester.pump();
      expect(controller.webViewError.value, contains('403'));
      expect(find.text('重新加载'), findsOneWidget);

      const newUrl = 'https://www.douyu.com/search/?kw=new';
      await nativeCall(id, 'onLoadStart', {'url': newUrl});
      // A late completion/error from the old URL must neither stop the new
      // spinner nor overwrite its current navigation URL.
      await nativeCall(id, 'onReceivedHttpError', {
        'request': mainRequest(oldUrl).toMap(),
        'errorResponse': WebResourceResponse(statusCode: 500).toMap(),
      });
      await nativeCall(id, 'onLoadStop', {'url': oldUrl});
      expect(controller.webViewError.value, isNull);
      expect(controller.webViewLoading.value, isTrue);
      expect(controller.webViewUrl.toString(), newUrl);
      await nativeCall(id, 'onLoadStop', {'url': newUrl});
      await tester.pump();
      expect(controller.webViewError.value, isNull);
      expect(controller.webViewLoading.value, isFalse);
      expect(find.text('重新加载'), findsNothing);

      // Revision invalidation must still reject the old native callback channel.
      controller.selectSite(Sites.allSites[Constant.kHuya]!);
      await nativeCall(id, 'onReceivedHttpError', {
        'request': mainRequest(oldUrl).toMap(),
        'errorResponse': WebResourceResponse(statusCode: 403).toMap(),
      });
      await nativeCall(id, 'onLoadStop', {'url': oldUrl});
      expect(controller.webViewLoading.value, isTrue);
      expect(controller.webViewError.value, isNull);
      controller.onClose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
