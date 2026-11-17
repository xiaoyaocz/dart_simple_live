import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/services/official_danmaku_layout.dart';
import 'package:simple_live_app/services/official_danmaku_session.dart';

// Read-only native WebView2 probe. Does not type, click or send public chat.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox());
  final log = File(args.first);
  void record(Object value) =>
      log.writeAsStringSync('$value\n', mode: FileMode.append);
  record('START read-only room layout probe');
  Timer(const Duration(seconds: 150), () {
    record('TIMEOUT');
    exit(1);
  });
  final support = args.length > 1
      ? Directory(args[1])
      : await getApplicationSupportDirectory();
  final snapshot =
      await Directory.systemTemp.createTemp('simplelive-profile-settings-');
  await File('${support.path}/localstorage.hive')
      .copy('${snapshot.path}/probe-settings.hive');
  final settings =
      await Hive.openBox<dynamic>('probe-settings', path: snapshot.path);
  record('PROFILE_SETTINGS_LOADED');
  for (final (site, host, room) in [
    ('douyin', 'live.douyin.com', args.length > 2 ? args[2] : '6096197105'),
  ]) {
    WebViewEnvironment? environment;
    InAppWebView? browser;
    try {
      final direct =
          settings.get('SearchWebProfile_$site', defaultValue: false) == true;
      environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
              userDataFolder:
                  '${support.path}/${direct ? 'search_webview_direct' : 'search_webview'}',
              additionalBrowserArguments: direct ? '--no-proxy-server' : null))
          .timeout(const Duration(seconds:15));
      record('$site ENVIRONMENT_READY');
      final created = Completer<InAppWebViewController>();
      browser = InAppWebView(
          webViewEnvironment: environment,
          initialUrlRequest: URLRequest(url: WebUri('https://$host/$room')),
          initialSettings:
              InAppWebViewSettings(mediaPlaybackRequiresUserGesture: true),
          initialUserScripts: UnmodifiableListView([
            UserScript(
                source:
                    '(function(site,expectedRoomIds){${OfficialDanmakuSession.install}})(${jsonEncode(site)},${jsonEncode([
                      room.split('/').last
                    ])});',
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
            UserScript(
                source:
                    '(function(site,expectedRoomIds,install){${OfficialDanmakuLayout.bootstrap}})(${jsonEncode(site)},${jsonEncode([
                      room.split('/').last
                    ])},function(site,expectedRoomIds){${OfficialDanmakuLayout.install}});',
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
          ]),
          onWebViewCreated: (view) => created.complete(view));
      runApp(Directionality(textDirection:TextDirection.ltr,
        child:Center(child:SizedBox(width:400,height:400,child:browser))));
      final view = await created.future.timeout(const Duration(seconds:10));
      await Future<void>.delayed(const Duration(seconds: 15));
      final status = await view.callAsyncJavaScript(functionBody: r'''
const input=document.querySelector('[data-sl-official-input]');
const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height,display:getComputedStyle(e).display,visibility:getComputedStyle(e).visibility};};
return {url:location.origin+location.pathname,ready:document.readyState,title:document.title,
 layout:window.__simpleLiveOfficialEditor?.inspect(), viewport:[innerWidth,innerHeight],
 input:input?{tag:input.tagName,cls:input.className,...rect(input)}:null,
 controls:[...document.querySelectorAll('[data-sl-official-control]')].map(e=>({role:e.getAttribute('data-sl-official-control'),...rect(e)})),
 scripts:document.scripts.length,bodyTextSize:document.body?.textContent?.length};
''');
      record('$site ${jsonEncode(status?.value)}');
      final image = await view.takeScreenshot();
      if (image != null) {
        await File('${log.path}.$site.png').writeAsBytes(image);
      }
    } catch (error) {
      record('$site ERROR ${error.runtimeType}');
    } finally {
      runApp(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds:100));
      await environment?.dispose();
    }
  }
  await settings.close();
  record('DONE read-only, no chat submitted');
  exit(0);
}
