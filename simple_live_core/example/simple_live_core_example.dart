import 'dart:io';

import 'package:dio/dio.dart';
import 'package:simple_live_core/src/model/tars/get_cdn_token_req.dart';
import 'package:simple_live_core/src/model/tars/get_cdn_token_resp.dart';
import 'package:tars_dart/tars/net/base_tars_http.dart';
import 'package:tars_dart/tars/tup/uni_packet.dart';

void main() async {
  // CoreLog.enableLog = true;
  // CoreLog.requestLogType = RequestLogType.short;
  // LiveSite site = BiliBiliSite();
  // var danmaku = site.getDanmaku();
  // danmaku.onMessage = (event) {
  //   if (event.type == LiveMessageType.chat) {
  //     print("[${event.color}]${event.userName}：${event.message}");
  //   } else if (event.type == LiveMessageType.online) {
  //     print("-----人气：${event.data}-----");
  //   } else if (event.type == LiveMessageType.superChat) {
  //     var scMessage = event.data as LiveSuperChatMessage;
  //     print("[SC]${scMessage.userName}：${scMessage.message}");
  //   }
  // };
  // danmaku.onClose = (event) {
  //   print(event);
  // };

  // //var search = await site.searchRooms("东方");

  // //var categores = await site.getCategores();
  // //print(categores.length);
  // var detail = await site.getRoomDetail(roomId: '7734200');
  // // var playQualites = await site.getPlayQualites(detail: detail);
  // // print(playQualites);
  // // var playUrls =
  // //     await site.getPlayUrls(detail: detail, quality: playQualites.first);
  // // for (var element in playUrls) {
  // //   print(element);
  // // }
  // //print(detail);

  // danmaku.start(detail.danmakuData);

  // await Future.wait({});
  sendReq();
}

void testHuyaReq() async {
  var reqBytes = await File('demo/getCdnTokenInfoReq.bin').readAsBytes();
  // RequestPacket req = RequestPacket();
  // req.readFrom(TarsInputStream(reqBytes));
  // print(req.iVersion);

  UniPacket uniPacket = UniPacket();
  //uniPacket.readFrom(TarsInputStream(reqBytes));
  uniPacket.decode(reqBytes);
  var value = uniPacket.get<GetCdnTokenReq>('tReq', GetCdnTokenReq());
  // GetCdnTokenReq reqData = GetCdnTokenReq();
  // reqData.readFrom(TarsInputStream(req.sBuffer));
  print(value.toString());
}

void sendReq() async {
  var req = GetCdnTokenReq();
  req.cdnType = "HW";
  req.streamName =
      "1199637826638-1199637826638-5763635889762729984-2399275776732-10057-A-0-1";

  BaseTarsHttp http = BaseTarsHttp("http://wup.huya.com", "liveui");

  var data = await http.tupRequest("getCdnTokenInfo", req, GetCdnTokenResp());

  var url =
      'http://hw.flv.huya.com/src/${data.streamName}.flv?${data.flvAntiCode}&codec=264';
  print(url);
  await Dio().download(
    url,
    'live-stream.flv',
    options: Options(
      responseType: ResponseType.bytes,
      headers: {"user-agent": "HYSDK(Windows, 20000308)"},
    ),
    onReceiveProgress: (count, total) {
      var downBytes = count / 1024 / 1024;
      print('downloading: $downBytes MB');
    },
  );
}

void testHuyaResp() async {
  var respBytes = await File('demo/getCdnTokenInfoResp.bin').readAsBytes();
  UniPacket uniPacket = UniPacket();
  uniPacket.decode(respBytes);
  var value = uniPacket.get<GetCdnTokenResp>('tRsp', GetCdnTokenResp());
  print(value.toString());
}
