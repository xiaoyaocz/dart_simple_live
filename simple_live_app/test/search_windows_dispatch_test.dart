import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// Exercise the real Windows plugin dispatcher, not a fake WebView controller.
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_page.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _RealSearchController extends AppSearchController {
  @override
  Future<WebViewEnvironment?> get webViewEnvironment async => null;
}

class _SearchController extends AppSearchController {
  String? openedRoom;
  @override
  Future<void> openRoom({String? detectedRoomId}) async {
    openedRoom = detectedRoomId ?? roomId.value;
  }

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
      } catch (e, st) {
        result.completeError(e, st);
      }
    },
  );
  return result.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manager =
      MethodChannel('com.pichillilorenzo/flutter_inappwebview_manager');
  final channels = <MethodChannel>[];
  var nextId = 800;
  late int id;
  var webBacks = 0;
  var canGoBack = true;
  String? currentUrl;
  late Site originalDouyin;
  setUp(() {
    originalDouyin = Sites.allSites['douyin']!;
    Sites.allSites['douyin'] = Site(id: originalDouyin.id, name: originalDouyin.name,
        logo: originalDouyin.logo, liveSite: LiveSite());
    currentUrl = null;
    webBacks = 0;
    canGoBack = true;
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
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canGoBack') return canGoBack;
          if (call.method == 'getUrl') return currentUrl;
          if (call.method == 'goBack') webBacks++;
          return null;
        });
      }
      return id;
    });
  });
  tearDown(() async {
    Sites.allSites['douyin'] = originalDouyin;
    Get.reset();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(manager, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  testWidgets('双击后侧键回首页，不先退网页，也不遗留延迟返回', (tester) async {
    final search = _SearchController();
    Get.put<AppSearchController>(search);
    search.selectSite(Sites.allSites['douyin']!);
    await tester
        .pumpWidget(GetMaterialApp(initialRoute: RoutePath.kIndex, getPages: [
      GetPage(
          name: RoutePath.kIndex, page: () => const Scaffold(body: Text('首页'))),
      GetPage(name: RoutePath.kSearch, page: () => const SearchPage()),
    ]));
    await tester.pumpAndSettle();
    Get.toNamed(RoutePath.kSearch);
    await tester.pump();
    await tester.pump();
    await nativeCall(id, 'onLoadStop', {'url': search.webViewUrl.toString()});
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(200, 200),
          kind: PointerDeviceKind.mouse, buttons: kBackMouseButton);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    expect(Get.currentRoute, RoutePath.kIndex);
    expect(find.text('首页'), findsOneWidget);
    expect(webBacks, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(Get.currentRoute, RoutePath.kIndex);
  });
  testWidgets('抖音关注直播页前侧键走真实暂停和路由，返回后恢复原网页', (tester) async {
    final search = _RealSearchController();
    Get.put<AppSearchController>(search);
    search.selectSite(Sites.allSites['douyin']!);
    await tester.pumpWidget(GetMaterialApp(home: const SearchPage(), getPages: [
      GetPage(
          name: RoutePath.kLiveRoomDetail,
          page: () => Scaffold(body: Text('播放器：${Get.parameters['roomId']}'))),
    ]));
    await tester.pump();
    await tester.pump();
    await nativeCall(id, 'onLoadStop', {'url': search.webViewUrl.toString()});
    await tester.pump();
    currentUrl = 'https://www.douyin.com/follow/live/46912316249?anchor_id=1';
    await tester.tapAt(const Offset(200, 200),
        kind: PointerDeviceKind.mouse, buttons: kForwardMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('播放器：46912316249'), findsOneWidget);
    expect(search.webViewVisible.value, isFalse);
    Get.back();
    await tester.pumpAndSettle();
    expect(search.webViewVisible.value, isTrue);
    expect(search.roomId.value, '46912316249');
    search.onClose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('网页内鼠标后侧键只后退一次，无历史时留在网页，不触发全局返回', (tester) async {
    final search = _SearchController();
    Get.put<AppSearchController>(search);
    search.selectSite(Sites.allSites['douyin']!);
    var appBacks = 0;
    await tester.pumpWidget(GetMaterialApp(
        home: RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        FourthButtonTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            FourthButtonTapGestureRecognizer>(
          FourthButtonTapGestureRecognizer.new,
          (recognizer) => recognizer.onTap = () => appBacks++,
        ),
      },
      child: const SearchPage(),
    )));
    await tester.pump();
    await tester.pump();
    await nativeCall(id, 'onLoadStop', {'url': search.webViewUrl.toString()});
    await tester.pump();
    for (final buttons in [
      kPrimaryButton,
      kSecondaryButton,
      kForwardMouseButton
    ]) {
      await tester.tapAt(const Offset(200, 200),
          kind: PointerDeviceKind.mouse, buttons: buttons);
      await tester.pump();
    }
    expect(webBacks, 0);
    final back = await tester.startGesture(const Offset(200, 200),
        kind: PointerDeviceKind.mouse, buttons: kBackMouseButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect([webBacks, appBacks], [0, 0], reason: '按住侧键不能在手势胜负确定前同时触发网页和全局后退');
    await back.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(webBacks, 1);
    expect(appBacks, 0);
    canGoBack = false;
    await tester.tapAt(const Offset(200, 200),
        kind: PointerDeviceKind.mouse, buttons: kBackMouseButton);
    await tester.pump(const Duration(milliseconds: 350));
    expect(webBacks, 1);
    expect(appBacks, 0);
    expect(search.selectedSite.value!.id, 'douyin');
    search.onClose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('鼠标前侧键松开时打开当前房间，不弹确认框', (tester) async {
    final search = _SearchController();
    Get.put<AppSearchController>(search);
    search.selectSite(Sites.allSites['huya']!);
    await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
    await tester.pump();
    await tester.pump();
    await nativeCall(id, 'onLoadStart', {'url': 'https://www.huya.com/12345'});
    await nativeCall(id, 'onLoadStop', {'url': 'https://www.huya.com/12345'});
    await tester.pump();
    final forward = await tester.startGesture(const Offset(200, 200),
        kind: PointerDeviceKind.mouse, buttons: kForwardMouseButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(search.openedRoom, isNull);
    await forward.up();
    await tester.pump();
    expect(search.openedRoom, '12345');
    expect(find.byType(Dialog), findsNothing);
    search.onClose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('未收到房间识别回调时，前侧键从实际网页地址识别房间再打开', (tester) async {
    final search = _SearchController();
    Get.put<AppSearchController>(search);
    search.selectSite(Sites.allSites['huya']!);
    await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
    await tester.pump();
    await tester.pump();
    currentUrl = 'https://www.huya.com/67890';
    expect(search.roomId.value, isNull);
    await tester.tapAt(const Offset(200, 200),
        kind: PointerDeviceKind.mouse, buttons: kForwardMouseButton);
    await tester.pump();
    expect(search.openedRoom, '67890');
    expect(search.roomId.value, '67890');
    search.onClose();
    await tester.pumpWidget(const SizedBox());
  });
  for (final entry in {
    'bilibili': 'https://live.bilibili.com/',
    'huya': 'https://www.huya.com/',
    'douyu': 'https://www.douyu.com/',
    'douyin': 'https://live.douyin.com/',
  }.entries) {
    testWidgets('${entry.key}进入房间默认继续浏览，仅顶部快捷按钮打开当前房间', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final search = _SearchController();
      Get.put<AppSearchController>(search);
      search.selectSite(Sites.allSites[entry.key]!);
      await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
      await tester.pump();
      await tester.pump();
      expect(find.text('打开播放器'), findsNothing);
      for (final room in ['12345', '67890']) {
        await nativeCall(id, 'onLoadStart', {'url': '${entry.value}$room'});
        await nativeCall(id, 'onLoadStop', {'url': '${entry.value}$room'});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(search.roomId.value, room);
        expect(search.webViewVisible.value, isTrue);
        expect(search.openedRoom, isNull);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('在 Simple Live 中打开'), findsNothing);
      }
      final shortcut = find.descendant(
          of: find.byType(AppBar), matching: find.text('打开播放器'));
      expect(shortcut, findsOneWidget);
      await tester.tap(shortcut);
      await tester.pump();
      expect(search.openedRoom, '67890');
      await nativeCall(id, 'onLoadStart', {'url': entry.value});
      await nativeCall(id, 'onLoadStop', {'url': entry.value});
      await tester.pump();
      expect(find.text('打开播放器'), findsNothing);
      search.onClose();
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final site in Sites.allSites.values) {
    testWidgets('${site.name}：真实Windows回调包装不同也必须允许网页导航', (tester) async {
      final search = _SearchController();
      Get.put<AppSearchController>(search);
      search.selectSite(site);
      await tester.pumpWidget(const GetMaterialApp(home: SearchPage()));
      await tester.pump();
      await tester.pump();
      expect(search.webViewController, isNotNull);
      final action = NavigationAction(
        request: URLRequest(url: WebUri(search.webViewUrl.toString())),
        isForMainFrame: true,
      );
      final policy =
          await nativeCall(id, 'shouldOverrideUrlLoading', action.toMap());
      expect(policy, NavigationActionPolicy.ALLOW.toNativeValue(),
          reason: '插件onWebViewCreated和事件回调用不同Dart包装，不能将正常导航CANCEL');
      await nativeCall(id, 'onLoadStop', {'url': search.webViewUrl.toString()});
      await tester.pump();
      expect(search.webViewError.value, isNull);
      expect(search.webViewLoading.value, isFalse);
      // A real platform controller match must not bypass the revision guard.
      // This is still the old native channel before the next Flutter frame.
      search.selectSite(site);
      final latePolicy =
          await nativeCall(id, 'shouldOverrideUrlLoading', action.toMap());
      expect(latePolicy, NavigationActionPolicy.CANCEL.toNativeValue());
      search.onClose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
