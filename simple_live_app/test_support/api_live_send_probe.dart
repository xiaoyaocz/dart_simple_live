import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/bilibili_danmaku_sender.dart';
import 'package:simple_live_app/services/douyu_native_sender.dart';
import 'package:simple_live_app/services/danmaku_sender.dart';

// Explicit live acceptance probe. Requires --send and a supplied profile root.
// Sends at most one message per user-specified room. No retries, no cookie logs.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox());
  if (args.length != 5 || args.first != '--send') exit(2);
  final log=File(args[1]);
  final support=Directory(args[2]);
  void record(Object message)=>log.writeAsStringSync('$message\n',mode:FileMode.append);
  Timer(const Duration(seconds:120),(){record('TIMEOUT no automatic retry');exit(1);});
  final snapshot=await Directory.systemTemp.createTemp('simplelive-live-check-');
  await File('${support.path}/localstorage.hive').copy('${snapshot.path}/probe-settings.hive');
  final settings=await Hive.openBox<dynamic>('probe-settings',path:snapshot.path);
  for(final (id,room,site) in [
    ('bilibili',args[3],BiliBiliSite()),
    ('douyu',args[4],DouyuSite()),
  ]) {
    WebViewEnvironment? env;
    DanmakuSender? sender;
    LiveDanmaku? receiver;
    try {
      final direct=settings.get('SearchWebProfile_$id',defaultValue:false)==true;
      env=await WebViewEnvironment.create(settings:WebViewEnvironmentSettings(
        userDataFolder:'${support.path}/${direct?'search_webview_direct':'search_webview'}',
        additionalBrowserArguments:direct?'--no-proxy-server':null));
      final manager=CookieManager.instance(webViewEnvironment:env);
      Future<Map<String,String>> credentials(Uri uri)async=>{
        for(final cookie in await manager.getCookies(url:WebUri(uri.toString()))) cookie.name:'${cookie.value}'
      };
      final detail=await site.getRoomDetail(roomId:room).timeout(const Duration(seconds:15));
      if(detail.danmakuData==null){record('$id NO_RECEIVER_ARGS not sent');continue;}
      receiver=site.getDanmaku();
      final ready=Completer<void>();
      final visible=Completer<void>();
      final suffix=DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final text='SimpleLive测试$suffix';
      receiver.onReady=(){if(!ready.isCompleted)ready.complete();};
      receiver.onMessage=(message){if(message.message==text&&!visible.isCompleted)visible.complete();};
      await receiver.start(detail.danmakuData);
      await ready.future.timeout(const Duration(seconds:15));
      record('$id INDEPENDENT_GUEST_RECEIVER_READY room=${detail.roomId}');
      sender=id=='bilibili'
        ? BilibiliDanmakuSender(roomId:detail.roomId,credentials:credentials)
        : DouyuNativeSender(roomId:detail.roomId,credentials:credentials);
      final result=await sender.send(text).timeout(const Duration(seconds:40));
      record('$id SEND_RESULT ${result.status} ${result.message}');
      if(result.status=='login'||result.status=='not_ready'||result.status=='rejected')continue;
      try {
        await visible.future.timeout(const Duration(seconds:15));
        record('$id INDEPENDENT_GUEST_RECEIVED true');
      }on TimeoutException {record('$id INDEPENDENT_GUEST_RECEIVED false delivery not verified');}
    }catch(error){record('$id ERROR ${error.runtimeType} no automatic retry');}
    finally {await sender?.dispose();await receiver?.stop();await env?.dispose();}
  }
  await settings.close();
  record('DONE');exit(0);
}
