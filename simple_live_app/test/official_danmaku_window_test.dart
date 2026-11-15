import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:simple_live_app/modules/live_room/official_danmaku_window.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      '${Directory.current.path}/build/official_window_test';
}

class _Environment extends PlatformWebViewEnvironment {
  _Environment(this.owner)
      : super.implementation(const PlatformWebViewEnvironmentCreationParams());
  final _Platform owner;
  int disposals = 0;
  @override
  String get id => 'fixture';
  @override
  Future<PlatformWebViewEnvironment> create(
      {WebViewEnvironmentSettings? settings}) async {
    if (owner.fail) throw StateError('Environment creation failed');
    final result = _Environment(owner);
    owner.created.add(result);
    await owner.gate?.future;
    return result;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _Controller extends PlatformInAppWebViewController {
  _Controller()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 'fixture'));
  int reloads = 0;
  @override
  Future<void> reload() async {
    reloads++;
  }
}

class _View extends PlatformInAppWebViewWidget {
  _View(super.params) : super.implementation();
  final controller = _Controller();
  bool initialized = false;
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;
  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        params.onWebViewCreated?.call(controllerFromPlatform(controller));
      });
    }
    return const ColoredBox(
        color: Colors.white,
        child: TextField(key: ValueKey('official-page-input')));
  }

  @override
  void dispose() {}
}

class _Platform extends InAppWebViewPlatform {
  final views = <_View>[];
  final created = <_Environment>[];
  Completer<void>? gate;
  bool fail = false;
  @override
  PlatformWebViewEnvironment createPlatformWebViewEnvironmentStatic() =>
      _Environment(this);
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
      PlatformInAppWebViewWidgetCreationParams params) {
    final view = _View(params);
    views.add(view);
    return view;
  }
}

Future<void> _settleIO(WidgetTester tester) async {
  // Directory creation uses real I/O, outside Flutter's fake clock.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  await tester.pumpAndSettle();
}

void main() {
  late _Platform platform;
  setUp(() {
    platform = _Platform();
    InAppWebViewPlatform.instance = platform;
    PathProviderPlatform.instance = _Paths();
  });

  testWidgets(
      'all platforms open visible original room UI with the exact search environment',
      (tester) async {
    for (final (site, host) in [
      ('huya', 'www.huya.com'),
      ('douyu', 'www.douyu.com'),
      ('bilibili', 'live.bilibili.com'),
      ('douyin', 'live.douyin.com')
    ]) {
      final borrowed = _Environment(platform);
      await tester.pumpWidget(MaterialApp(
          home: OfficialDanmakuWindow(
        key: ValueKey(site),
        siteId: site,
        siteName: site,
        roomUri: Uri.https(host, '/123'),
        searchEnvironment:
            Future.value(WebViewEnvironment.fromPlatform(platform: borrowed)),
      )));
      await tester.pumpAndSettle();
      final view = platform.views.last;
      expect(view.params.webViewEnvironment, same(borrowed));
      expect(
          view.params.initialUrlRequest!.url.toString(), 'https://$host/123');
      expect(view.params.initialSettings!.javaScriptCanOpenWindowsAutomatically,
          isTrue);
      expect(view.params.initialUserScripts, hasLength(1));
      final script = view.params.initialUserScripts!.single.source;
      expect(script, contains('HTMLMediaElement'));
      for (final forbidden in [
        'fetch(',
        'XMLHttpRequest',
        'WebSocket',
        '.click(',
        'insertText',
        'cookie'
      ]) {
        expect(script, isNot(contains(forbidden)));
      }
      await tester.tap(find.byTooltip('刷新官方网页'));
      await tester.pumpAndSettle();
      expect(view.controller.reloads, 1);
      await tester.tap(find.byTooltip('展开完整网页'));
      await tester.pumpAndSettle();
      expect(platform.views.last, same(view),
          reason: 'Expanding must not recreate the login/editor');
      expect(platform.created, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(borrowed.disposals, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'environment failure can retry; owned environment releases on close',
      (tester) async {
    platform.fail = true;
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuWindow(
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/1'),
    )));
    await _settleIO(tester);
    expect(find.text('网页组件启动失败，点击重试'), findsOneWidget);
    platform.fail = false;
    await tester.tap(find.text('网页组件启动失败，点击重试'));
    await _settleIO(tester);
    expect(platform.views, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.created.single.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed borrowed environment can retry using the remembered profile',
      (tester) async {
    final search = Completer<WebViewEnvironment?>();
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuWindow(
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/1'),
      searchEnvironment: search.future,
    )));
    search.completeError(StateError('Search environment failed'));
    await tester.pumpAndSettle();
    expect(find.text('网页组件启动失败，点击重试'), findsOneWidget);
    await tester.tap(find.text('网页组件启动失败，点击重试'));
    await _settleIO(tester);
    expect(platform.views, hasLength(1));
    expect(platform.created, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.created.single.disposals, 1);
  });

  testWidgets(
      'environment completing after close is released without creating a browser',
      (tester) async {
    platform.gate = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuWindow(
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/1'),
    )));
    await _settleIO(tester);
    expect(platform.created, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    platform.gate!.complete();
    await tester.pumpAndSettle();
    expect(platform.created.single.disposals, 1);
    expect(platform.views, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Enter opens once; typing in official window does not activate player shortcuts',
      (tester) async {
    var opens = 0;
    Route<void>? route;
    final borrowed = _Environment(platform);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => DesktopDanmakuShortcut(
                onCompose: () {
                  opens++;
                  unawaited(showOfficialDanmakuWindow(context,
                      siteId: 'douyu',
                      siteName: '斗鱼',
                      roomUri: Uri.https('www.douyu.com', '/1'),
                      searchEnvironment: Future.value(
                          WebViewEnvironment.fromPlatform(platform: borrowed)),
                      onRoute: (value) => route = value));
                },
                child: const Scaffold(body: Text('播放器'))))));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect((route as ModalRoute).barrierColor, Colors.transparent);
    await tester.enterText(
        find.byKey(const ValueKey('official-page-input')), 'dfrq');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(find.text('dfrq'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭官方弹幕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放器'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, 2);
    expect(tester.takeException(), isNull);
  });
}
