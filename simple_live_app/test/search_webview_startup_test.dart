import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// 直接模拟 Windows 插件和路径接口，不改生产依赖配置。
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/services/search_web_session.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory('${Directory.current.path}/build/search_webview_test')
          .absolute
          .path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel =
      MethodChannel('com.pichillilorenzo/flutter_webview_environment');
  final environmentChannels = <MethodChannel>[];
  final disposedEnvironments = <String>[];

  void mockEnvironment(MethodCall call) {
    final id = call.arguments['id'] as String;
    final instance =
        MethodChannel('com.pichillilorenzo/flutter_webview_environment_$id');
    environmentChannels.add(instance);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instance, (call) async {
      if (call.method == 'dispose') disposedEnvironments.add(id);
      return null;
    });
  }

  setUp(() {
    for (final site in Sites.allSites.values) {
      SearchWebSession.remember(site.id, false);
    }
    disposedEnvironments.clear();
    WindowsInAppWebViewPlatform.registerWith();
    PathProviderPlatform.instance = _Paths();
  });
  test('搜索重开和弹幕环境使用同一个已登录直连配置', () async {
    final settings = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      settings.add(Map<dynamic, dynamic>.from(call.arguments['settings']));
      mockEnvironment(call);
      return true;
    });
    SearchWebSession.remember(Constant.kHuya, true);
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    await controller.webViewEnvironment;
    final senderEnvironment = await SearchWebSession.create(siteId: Constant.kHuya);
    addTearDown(senderEnvironment.dispose);
    expect(settings.first['additionalBrowserArguments'], '--no-proxy-server');
    expect(settings.last['userDataFolder'], settings.first['userDataFolder']);
    expect(settings.last['additionalBrowserArguments'], settings.first['additionalBrowserArguments']);
    // Switching platform must replace the cached environment when its profile differs.
    controller.selectSite(Sites.allSites[Constant.kDouyu]!);
    await controller.webViewEnvironment;
    expect(settings.last['additionalBrowserArguments'], '--no-proxy-server');
    expect(settings.last['userDataFolder'], isNot(settings.first['userDataFolder']));
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    for (final instance in environmentChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(instance, null);
    }
    environmentChannels.clear();
  });

  test('网页环境启动失败应结束等待并保留错误', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: '0', message: '环境创建失败');
    });
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    await expectLater(
        controller.webViewEnvironment, throwsA(isA<PlatformException>()));
    expect(controller.webViewLoading.value, isFalse);
    expect(controller.webViewError.value, isNotNull);
  });

  test('网页环境失败提示保留原生错误码，区分权限与运行时问题', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: '-2147024891',
        message: 'Cannot create WebViewEnvironment: Access is denied.',
      );
    });
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    await expectLater(
        controller.webViewEnvironment, throwsA(isA<PlatformException>()));
    expect(controller.webViewError.value, contains('0x80070005'));
    expect(controller.webViewLoading.value, isFalse);
  });

  test('组件未创建成功时刷新会重新初始化而非重复等待旧环境', () async {
    var creations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (++creations == 1) {
        throw PlatformException(code: '0', message: '环境创建失败');
      }
      mockEnvironment(call);
      return true;
    });
    final controller = AppSearchController();
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    addTearDown(controller.onClose);
    try {
      await controller.webViewEnvironment;
    } catch (_) {}
    controller.failLoading('启动失败');
    await controller.reloadWebView();
    final environment = await controller.webViewEnvironment;
    expect(environment, isNotNull);
    expect(controller.selectedSite.value?.id, Constant.kHuya);
    expect(controller.webViewError.value, isNull);
    await controller.reloadWebView();
    await Future<void>.delayed(Duration.zero);
    expect(disposedEnvironments, [environment!.id]);
  });

  test('刷新后旧环境的迟到错误不能覆盖新页面状态', () async {
    final oldCreation = Completer<bool>();
    final started = Completer<void>();
    var creations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (++creations == 1) {
        started.complete();
        return oldCreation.future;
      }
      mockEnvironment(call);
      return true;
    });
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    final oldEnvironment = controller.webViewEnvironment;
    final oldFailure =
        expectLater(oldEnvironment, throwsA(isA<PlatformException>()));
    await started.future;
    await controller.reloadWebView();
    await controller.webViewEnvironment;
    oldCreation.completeError(PlatformException(code: '0', message: '旧环境失败'));
    await oldFailure;
    expect(controller.webViewError.value, isNull);
    expect(controller.webViewLoading.value, isTrue);
  });

  test('默认与重试均直连，并保留原登录数据目录', () async {
    final settings = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      settings.add(Map<dynamic, dynamic>.from(call.arguments['settings']));
      mockEnvironment(call);
      return true;
    });
    final controller = AppSearchController();
    addTearDown(controller.onClose);
    controller.selectSite(Sites.allSites[Constant.kHuya]!);
    final firstEnvironment = await controller.webViewEnvironment;
    expect(settings.single['additionalBrowserArguments'], '--no-proxy-server');
    controller.handleLoadError(
      WebResourceRequest(
          url: WebUri('https://www.huya.com/'), isForMainFrame: true),
      WebResourceError(
          type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
          description: '系统代理无法连接'),
    );
    await controller.webViewEnvironment;
    await Future<void>.delayed(Duration.zero);
    expect(settings.last['additionalBrowserArguments'], '--no-proxy-server');
    expect(settings.last['userDataFolder'],
        settings.first['userDataFolder']);
    expect(disposedEnvironments, contains(firstEnvironment!.id));
  });
}
