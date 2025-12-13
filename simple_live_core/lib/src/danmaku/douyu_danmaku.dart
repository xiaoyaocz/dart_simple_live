import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';

import '../common/binary_writer.dart';

class DouyuDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 45 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://danmuproxy.douyu.com:8506";

  WebScoketUtils? webScoketUtils;

  @override
  Future start(dynamic args) async {
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void joinRoom(String roomId) {
    webScoketUtils
        ?.sendMessage(serializeDouyu("type@=loginreq/roomid@=$roomId/"));
    webScoketUtils?.sendMessage(
        serializeDouyu("type@=joingroup/rid@=$roomId/gid@=-9999/"));
  }

  @override
  void heartbeat() {
    var data = serializeDouyu("type@=mrkl/");
    webScoketUtils?.sendMessage(data);
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessage(List<int> data) {
    try {
      String? result = deserializeDouyu(data);
      if (result == null) {
        return;
      }
      var jsonData = sttToJObject(result);

      var type = jsonData["type"]?.toString();
      var fans = jsonData["if"] ?? '0'.toString();
      //斗鱼好像不会返回人气值
      //有些直播间存在阴间弹幕，不知道什么情况
      //只显示粉丝发言
      if (type == "chatmsg" && fans == '1') {
        var col = int.tryParse(jsonData["col"].toString()) ?? 0;
        var liveMsg = LiveMessage(
          type: LiveMessageType.chat,
          userName: jsonData["nn"].toString(),
          message: jsonData["txt"].toString(),
          color: getColor(col),
        );

        onMessage?.call(liveMsg);
      } else if (type == "comm_chatmsg") {
        // {
        //   "type": "comm_chatmsg",
        //   "tick": null,
        //   "res": null,
        //   "cmdEnum": null,
        //   "cmd": "comm_chatmsg",
        //   "vrid": "1856171486511906816",
        //   "btype": "voiceDanmu",
        //   "chatmsg": {
        //     "nn": "King彡吖西",
        //     "level": "14",
        //     "type": "chatmsg",
        //     "rid": "1126960",
        //     "gag": "0",
        //     "uid": "16751345",
        //     "txt": "c桑又在赞elo了，上分给你玩明白了",
        //     "hidenick": "0",
        //     "nc": "0",
        //     "ic": ["avatar", "016", "75", "13", "45_avatar"],
        //     "nl": "0",
        //     "tbid": "0",
        //     "tbl": "0",
        //     "tbvip": "0"
        //   },
        //   "range": "2",
        //   "cprice": "3000",
        //   "cmgType": "1",
        //   "rid": "1126960",
        //   "gbtemp": "2",
        //   "uid": "16751345",
        //   "crealPrice": "3000",
        //   "cet": "60",
        //   "now": "1731380814042",
        //   "csuperScreen": "0",
        //   "danmucr": "1"
        // }
        DateTime curTimestamp = DateTime.fromMillisecondsSinceEpoch(
          int.parse(jsonData["now"]),
        );
        //
        var face = "";
        try{
          // 疑似换接口了
          face = (jsonData["chatmsg"]["ic"] as List<dynamic>).cast<String>().join("/");
        }catch(e){
          CoreLog.error("DouyuSuperChat-face:$e");
        }
        LiveSuperChatMessage sc = LiveSuperChatMessage(
          // 斗鱼没有颜色 调整配色方案-偏紫色系
          backgroundBottomColor: "#292a60",
          backgroundColor: "#c1c1ff",
          endTime:
              curTimestamp.add(Duration(seconds: int.parse(jsonData["cet"]))),
          face:
              "https://apic.douyucdn.cn/upload/${face}_small.jpg",
          message: jsonData["chatmsg"]["txt"].toString(),
          price: int.parse(jsonData["cprice"]) ~/ 100,
          startTime: curTimestamp,
          userName: jsonData["chatmsg"]["nn"].toString(),
        );
        var liveMsg = LiveMessage(
          type: LiveMessageType.superChat,
          userName: "SUPER_CHAT_MESSAGE",
          message: "SUPER_CHAT_MESSAGE",
          color: LiveMessageColor.white,
          data: sc,
        );
        onMessage?.call(liveMsg);
      }
    } catch (e) {
      CoreLog.error("DouyuSuperChat:$e");
    }
  }

  List<int> serializeDouyu(String body) {
    try {
      const int clientSendToServer = 689;
      const int encrypted = 0;
      const int reserved = 0;

      List<int> buffer = utf8.encode(body);

      var writer = BinaryWriter([]);
      writer.writeInt(4 + 4 + body.length + 1, 4, endian: Endian.little);
      writer.writeInt(4 + 4 + body.length + 1, 4, endian: Endian.little);
      writer.writeInt(clientSendToServer, 2, endian: Endian.little);
      writer.writeInt(encrypted, 1, endian: Endian.little);
      writer.writeInt(reserved, 1, endian: Endian.little);
      writer.writeBytes(buffer);
      writer.writeInt(0, 1, endian: Endian.little);
      return writer.buffer;
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }

  String? deserializeDouyu(List<int> buffer) {
    try {
      var reader = BinaryReader(Uint8List.fromList(buffer));
      int fullMsgLength =
          reader.readInt32(endian: Endian.little); //fullMsgLength
      reader.readInt32(endian: Endian.little); //fullMsgLength2
      int bodyLength = fullMsgLength - 9;
      reader.readShort(endian: Endian.little); //packType
      reader.readByte(endian: Endian.little); //encrypted
      reader.readByte(endian: Endian.little); //reserved

      var bytes = reader.readBytes(bodyLength);

      reader.readByte(endian: Endian.little); //固定为0
      return utf8.decode(bytes);
    } catch (e) {
      CoreLog.error(e);
      return null;
    }
  }

  //辣鸡STT
  dynamic sttToJObject(String str) {
    if (str.contains("//")) {
      var result = [];
      for (var field in str.split("//")) {
        if (field.isEmpty) {
          continue;
        }
        result.add(sttToJObject(field));
      }
      return result;
    }
    if (str.contains("@=")) {
      var result = {};
      for (var field in str.split('/')) {
        if (field.isEmpty) {
          continue;
        }
        var tokens = field.split("@=");
        var k = tokens[0];
        var v = unscapeSlashAt(tokens[1]);
        result[k] = sttToJObject(v);
      }
      return result;
    } else if (str.contains("@A=")) {
      return sttToJObject(unscapeSlashAt(str));
    } else {
      return unscapeSlashAt(str);
    }
  }

  String unscapeSlashAt(String str) {
    return str.replaceAll("@S", "/").replaceAll("@A", "@");
  }

  LiveMessageColor getColor(int type) {
    switch (type) {
      case 1:
        return LiveMessageColor(255, 0, 0);
      case 2:
        return LiveMessageColor(30, 135, 240);
      case 3:
        return LiveMessageColor(122, 200, 75);
      case 4:
        return LiveMessageColor(255, 127, 0);
      case 5:
        return LiveMessageColor(155, 57, 244);
      case 6:
        return LiveMessageColor(255, 105, 180);
      default:
        return LiveMessageColor.white;
    }
  }
}
