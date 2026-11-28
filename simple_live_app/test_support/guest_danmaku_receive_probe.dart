import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/danmaku/proto/douyin.pb.dart' as dy;
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'dart:typed_data';

class _Huya extends HuyaDanmaku {
  final frames = <int, int>{};
  @override
  void decodeMessage(List<int> data) {
    final type=TarsInputStream(Uint8List.fromList(data)).read(0,0,false);
    frames[type]=(frames[type]??0)+1;
    super.decodeMessage(data);
  }
}
class _Douyin extends DouyinDanmaku {
  final frames=<String,int>{};
  final errors=<String,int>{};
  @override
  void decodeMessage(dynamic data) {
    final frame=dy.PushFrame.fromBuffer(data);
    frames[frame.payloadType]=(frames[frame.payloadType]??0)+1;
    try { super.decodeMessage(data); }
    catch(error) { final type=error.runtimeType.toString();errors[type]=(errors[type]??0)+1; }
  }
}

// Anonymous receive-only check. Does not load a login profile or submit chat.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();runApp(const SizedBox());
  if(args.length != 3) exit(2);
  final log=File(args[0]);
  void record(String s)=>log.writeAsStringSync('$s\n',mode:FileMode.append);
  final timeout=Timer(const Duration(seconds:100),(){record('TIMEOUT');exit(1);});
  for(final (id,room,site) in [('huya',args[1],HuyaSite()),('douyin',args[2],DouyinSite())]) {
    final LiveDanmaku receiver=id=='huya'?_Huya():_Douyin();
    var chat=0,online=0,closed=0;
    try {
      final detail=await site.getRoomDetail(roomId:room).timeout(const Duration(seconds:15));
      record('$id canonical=${detail.roomId} live=${detail.status}');
      if(detail.danmakuData is HuyaDanmakuArgs) {
        final a=detail.danmakuData as HuyaDanmakuArgs;
        record('$id channels=${a.topSid}/${a.subSid}');
      }
      if(detail.danmakuData is DouyinDanmakuArgs) {
        final a=detail.danmakuData as DouyinDanmakuArgs;
        record('$id webRid=${a.webRid} room=${a.roomId}');
      }
      receiver.onReady=()=>record('$id SOCKET_OPEN not subscription confirmation');
      receiver.onClose=(_){closed++;};
      receiver.onMessage=(m){if(m.type==LiveMessageType.chat)chat++;if(m.type==LiveMessageType.online)online++;};
      await receiver.start(detail.danmakuData);
      await Future<void>.delayed(const Duration(seconds:25));
      record('$id chat=$chat online=$online closed=$closed');
      if(receiver is _Huya)record('$id frames=${receiver.frames}');
      if(receiver is _Douyin)record('$id frames=${receiver.frames} decodeErrors=${receiver.errors}');
    } catch(error) {record('$id ERROR ${error.runtimeType}');}
    finally {await receiver.stop();}
  }
  timeout.cancel();record('DONE no messages sent');exit(0);
}
