import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:simple_live_app/services/search_web_session.dart';
import 'package:simple_live_app/services/search_danmaku_credentials.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      '${Directory.current.path}/build/credential_test';
}

class _Page implements InAppWebViewController {
  Map<String, String> cookies = {};
  @override
  Future<dynamic> callDevToolsProtocolMethod(
      {required String methodName, Map<String, dynamic>? parameters}) async {
    expect(methodName, 'Network.getCookies');
    return {
      'cookies': [
        for (final entry in cookies.entries)
          {'name': entry.key, 'value': entry.value}
      ]
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final profiles = <String, bool>{};
  final channels = <MethodChannel>[];
  var loggedIn = true;
  setUp(() {
    WindowsInAppWebViewPlatform.registerWith();
    PathProviderPlatform.instance = _Paths();
    SearchWebSession.remember('douyu', true);
    profiles.clear();
    loggedIn = true;
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.pichillilorenzo/flutter_webview_environment'),
        (call) async {
      final id = call.arguments['id'] as String;
      profiles[id] =
          (call.arguments['settings']['userDataFolder'] as String).endsWith('search_webview_direct');
      final channel =
          MethodChannel('com.pichillilorenzo/flutter_webview_environment_$id');
      channels.add(channel);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      return true;
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel(
            'com.pichillilorenzo/flutter_inappwebview_cookiemanager'),
        (call) async {
      expect(call.method, 'getCookies');
      final direct = profiles[call.arguments['webViewEnvironmentId']];
      return [
        {
          'name': 'dy_did',
          'value': direct == true ? 'visitor-device' : 'account-device'
        },
        if (direct == false && loggedIn) ...[
          {'name': 'acf_username', 'value': 'account'},
          {'name': 'acf_dmjwt_token', 'value': 'session'},
        ],
      ];
    });
  });
  tearDown(() {
    for (final c in [
      ...channels,
      const MethodChannel('com.pichillilorenzo/flutter_webview_environment'),
      const MethodChannel(
          'com.pichillilorenzo/flutter_inappwebview_cookiemanager')
    ]) {
      messenger.setMockMethodCallHandler(c, null);
    }
    channels.clear();
  });
  test(
      'network fallback profile must not hide the existing website login; never merge cookies',
      () async {
    final source = SearchDanmakuCredentials(siteId: 'douyu');
    final uri = Uri.parse('https://www.douyu.com/');
    final cookies = await source.read(uri);
    expect(cookies['acf_username'], 'account');
    expect(cookies['dy_did'], 'account-device');
    expect(profiles.length, 2);
    await source.read(uri);
    expect(profiles.length, 2,
        reason:
            'Reuse the bound login profile, not reload visitor profile each send');
    loggedIn = false;
    expect((await source.read(uri)).containsKey('acf_username'), isFalse);
    await source.dispose();
    await expectLater(source.read(uri), throwsStateError);
  });
  test(
      'an active search account is authoritative; do not replace its logout with another profile',
      () async {
    final source = SearchDanmakuCredentials(
        siteId: 'douyu',
        existingView: _Page(),
        isExistingViewCurrent: () => true);
    expect(await source.read(Uri.parse('https://www.douyu.com/')), isEmpty);
    expect(profiles, isEmpty);
    await expectLater(
        source.read(Uri.parse('https://example.com/')), throwsStateError);
    await source.dispose();
  });
  test(
      'after active view logout and close, never rebind an older alternate account',
      () async {
    final page = _Page();
    SearchLoginView? active;
    final source =
        SearchDanmakuCredentials(siteId: 'douyu', resolveView: () => active);
    final uri = Uri.parse('https://www.douyu.com/');
    expect((await source.read(uri))['acf_username'], 'account');
    active =
        (view: page, isCurrent: () => true); // Guest/logged-out direct profile.
    expect(await source.read(uri), isEmpty);
    active = null;
    expect((await source.read(uri)).containsKey('acf_username'), isFalse);
    await source.dispose();
  });
}
