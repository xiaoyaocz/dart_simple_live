import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/modules/live_room/official_danmaku_panel.dart';
import 'package:simple_live_app/services/official_composer_transport.dart';

// Exercises the production hidden host. --check never submits; --send submits
// once per explicit room, only after an independent receiver is connected.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox());
  if (args.length < 5 ||
      args.length > 6 ||
      !['--check', '--send'].contains(args[0])) exit(2);
  final log = File(args[1]);
  void record(String value) =>
      log.writeAsStringSync('$value\n', mode: FileMode.append);
  final deadline = Timer(const Duration(seconds: 180), () {
    record('TIMEOUT no retry');
    exit(1);
  });
  final snapshot =
      await Directory.systemTemp.createTemp('simplelive-composer-check-');
  await File('${args[2]}/localstorage.hive')
      .copy('${snapshot.path}/settings.hive');
  final settings = await Hive.openBox<dynamic>('settings', path: snapshot.path);
  for (final (id, host, room, site, emoji) in [
    ('huya', 'www.huya.com', args[3], HuyaSite(), '/{66'),
    ('douyin', 'live.douyin.com', args[4], DouyinSite(), '[微笑]'),
  ]) {
    if (args.length == 6 && args[5] != id) continue;
    WebViewEnvironment? environment;
    LiveDanmaku? receiver;
    final transport = OfficialComposerTransport();
    try {
      final direct =
          settings.get('SearchWebProfile_$id', defaultValue: false) == true;
      environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
        userDataFolder:
            '${args[2]}/${direct ? 'search_webview_direct' : 'search_webview'}',
        additionalBrowserArguments: direct ? '--no-proxy-server' : null,
      ));
      final detail = await site
          .getRoomDetail(roomId: room)
          .timeout(const Duration(seconds: 15));
      record('$id ROOM canonical=${detail.roomId} live=${detail.status}');
      if(!detail.status || detail.danmakuData == null) {
        record('$id OFFLINE_OR_NO_RECEIVER not sent');
        continue;
      }
      final ready = Completer<void>();
      runApp(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
        width: 350,
        height: 400,
        child: ExcludeFocus(
            child: IgnorePointer(
                child: Opacity(
          opacity: 0,
          child: OfficialDanmakuPanel(
            key: ValueKey(id),
            siteId: id,
            siteName: id,
            roomUri: Uri.https(host, '/$room'),
            confirmationRoomIds: [
              detail.roomId,
              if (detail.danmakuData is DouyinDanmakuArgs)
                (detail.danmakuData as DouyinDanmakuArgs).roomId
            ],
            searchEnvironment: Future.value(environment),
            composerTransport: transport,
            expanded: false,
            focusRequest: 0,
            onExpandedChanged: (_) {},
            onFocusedChanged: (_) {},
            onConnectionMessage: (message) {
              record('$id CONNECTION $message');
              if (message == '平台发送区已就绪' && !ready.isCompleted) ready.complete();
            },
          ),
        ))),
      )))));
      await ready.future.timeout(const Duration(seconds: 60));
      record('$id PRODUCTION_HIDDEN_HOST_READY');
      if (args[0] != '--send') continue;
      if (detail.danmakuData == null) {
        record('$id NO_RECEIVER_ARGS not sent');
        continue;
      }
      final prefix =
          'SimpleLive测试${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final connected = Completer<void>(), visible = Completer<void>();
      final receiving = Completer<void>();
      var chatCount=0,onlineCount=0;
      receiver = site.getDanmaku();
      receiver.onReady = () {
        if (!connected.isCompleted) connected.complete();
      };
      receiver.onMessage = (message) {
        if(message.type == LiveMessageType.chat) chatCount++;
        if(message.type == LiveMessageType.online) onlineCount++;
        if((message.type == LiveMessageType.chat || message.type == LiveMessageType.online) && !receiving.isCompleted) receiving.complete();
        if (message.type == LiveMessageType.chat &&
            message.message.startsWith(prefix) &&
            !visible.isCompleted) visible.complete();
      };
      await receiver.start(detail.danmakuData);
      await connected.future.timeout(const Duration(seconds: 15));
      record('$id INDEPENDENT_GUEST_SOCKET_OPEN');
      // Socket-open fires before platform subscription. Require decoded room
      // traffic, otherwise a send can race the room join and invalidate the test.
      try { await receiving.future.timeout(const Duration(seconds:20)); }
      on TimeoutException {record('$id NO_ROOM_TRAFFIC not sent');continue;}
      record('$id INDEPENDENT_GUEST_RECEIVER_READY chat=$chatCount online=$onlineCount');
      final result = await transport
          .send('$prefix$emoji')
          .timeout(const Duration(seconds: 25));
      record('$id SEND_RESULT ${result.status} ${result.message}');
      if (result.sent || result.status == 'unknown') {
        try {
          await visible.future.timeout(const Duration(seconds: 15));
          record('$id INDEPENDENT_GUEST_RECEIVED true');
        } on TimeoutException {
          record('$id INDEPENDENT_GUEST_RECEIVED false chat=$chatCount online=$onlineCount');
        }
      }
    } catch (error) {
      record('$id ERROR ${error.runtimeType} no automatic retry');
    } finally {
      runApp(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await transport.dispose();
      await receiver?.stop();
      await environment?.dispose();
    }
  }
  await settings.close();
  deadline.cancel();
  record('DONE');
  exit(0);
}
