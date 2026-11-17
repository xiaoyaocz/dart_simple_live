// Real network diagnostic. Uses temporary browser data, never sends chat.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/windows_direct_network.dart';
import 'package:simple_live_app/services/search_web_session.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class Paths extends PathProviderPlatform {
  Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<void> main(List<String> args) async {
  WindowsDirectNetwork.initialize();
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final log = File(args[0]);
  void record(String s) => log.writeAsStringSync('$s\n', mode: FileMode.append);
  Timer(const Duration(seconds: 180), () {
    record('TIMEOUT');
    exit(1);
  });
  record('PID $pid');
  record(
      'PROXY_ENV_PRESENT ${Platform.environment.keys.any((k) => RegExp(r"^(https?|all|socks5?|ftp|no)_proxy$", caseSensitive: false).hasMatch(k))}');
  final temp =
      await Directory.systemTemp.createTemp('simplelive-direct-probe-');
  PathProviderPlatform.instance = Paths(temp.path);
  runApp(const MaterialApp(home: Scaffold(body: SizedBox())));
  final site = HuyaSite();
  LiveRoomDetail? detail;
  try {
    final result =
        await site.getRecommendRooms().timeout(const Duration(seconds: 25));
    record('HOME_API items=${result.items.length}');
  } catch (e) {
    record('HOME_API ERROR ${e.runtimeType}');
  }
  try {
    final result =
        await site.searchRooms('英雄联盟').timeout(const Duration(seconds: 25));
    record('SEARCH_API items=${result.items.length}');
  } catch (e) {
    record('SEARCH_API ERROR ${e.runtimeType}');
  }
  try {
    detail = await site
        .getRoomDetail(roomId: '546540')
        .timeout(const Duration(seconds: 25));
    record('ROOM live=${detail.status}');
  } catch (e) {
    record('ROOM ERROR ${e.runtimeType}');
  }
  if (detail != null && detail.status) {
    final receiver = site.getDanmaku();
    var chat = 0, online = 0;
    receiver.onMessage = (m) {
      if (m.type == LiveMessageType.chat) chat++;
      if (m.type == LiveMessageType.online) online++;
    };
    try {
      receiver.onReady = () => record('DANMAKU_SOCKET_OPEN');
      receiver.onClose = (_) => record('DANMAKU_CONNECTION_CLOSED');
      await receiver.start(detail.danmakuData);
      await Future<void>.delayed(const Duration(seconds: 25));
      record('DANMAKU_RECEIVE chat=$chat online=$online');
    } catch (e) {
      record('DANMAKU_RECEIVE ERROR ${e.runtimeType}');
    } finally {
      await receiver.stop();
    }
    Player? player;
    try {
      final qualities = await site.getPlayQualites(detail: detail);
      final streams = await site
          .getPlayUrls(
              detail: detail,
              quality: qualities.lastWhere((q) => q.data['codec'] == 264,
                  orElse: () => qualities.last))
          .timeout(const Duration(seconds: 25));
      player = Player(
          configuration:
              const PlayerConfiguration(logLevel: MPVLogLevel.error));
      final native = player.platform as NativePlayer;
      await native.setProperty('http-proxy', '');
      await player.setVolume(0);
      final video = VideoController(player);
      runApp(MaterialApp(home: Scaffold(body: Video(controller: video))));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await player
          .open(Media(streams.urls.first, httpHeaders: streams.headers))
          .timeout(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(seconds: 10));
      record(
          'MPV videoWidth=${await native.getProperty('video-params/w')} http-proxy-empty=${(await native.getProperty('http-proxy')).isEmpty} positionMs=${player.state.position.inMilliseconds} width=${player.state.width}');
    } catch (e) {
      record('MPV ERROR ${e.runtimeType}');
    } finally {
      await player?.dispose();
    }
  }
  for (final entry in [
    ('search', 'https://www.huya.com/', false),
    ('login-default', 'https://passport.bilibili.com/login', true)
  ]) {
    WebViewEnvironment? env;
    final ready = Completer<void>();
    try {
      if (!entry.$3)
        env = await SearchWebSession.create(siteId: 'probe', direct: false);
      runApp(MaterialApp(
          home: Scaffold(
              body: InAppWebView(
                  key: ValueKey(entry.$1),
                  webViewEnvironment: env,
                  initialUrlRequest: URLRequest(url: WebUri(entry.$2)),
                  onProgressChanged: (view, p) async {
                    if (p == 66 && !ready.isCompleted) {
                      final url = await view.getUrl();
                      final title = await view.getTitle();
                      record(
                          'WEBVIEW ${entry.$1} host=${url?.host} titlePresent=${title?.isNotEmpty}');
                      ready.complete();
                    }
                  },
                  onReceivedError: (_, r, e) {
                    if (r.isForMainFrame == true && !ready.isCompleted) {
                      record('WEBVIEW ${entry.$1} ERROR ${e.type}');
                      ready.complete();
                    }
                  }))));
      await ready.future.timeout(const Duration(seconds: 35));
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (e) {
      record('WEBVIEW ${entry.$1} ERROR ${e.runtimeType}');
    } finally {
      runApp(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await env?.dispose();
    }
  }
  record('ACCOUNT_LOGIN unverified: temporary profile, no credentials entered');
  record('PUBLIC_CHAT_SEND unverified: no messages sent');
  record('HOLD_FOR_CONNECTION_OBSERVATION');
  await Future<void>.delayed(const Duration(seconds: 5));
  record('DONE');
  exit(0);
}
