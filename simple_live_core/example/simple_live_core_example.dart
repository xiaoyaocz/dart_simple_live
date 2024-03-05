import 'package:simple_live_core/simple_live_core.dart';

void main() async {
  CoreLog.enableLog = true;
  LiveSite site = BiliBiliSite();
  var danmaku = site.getDanmaku();
  danmaku.onMessage = (event) {
    if (event.type == LiveMessageType.chat) {
      print("[${event.color}]${event.userName}：${event.message}");
    } else if (event.type == LiveMessageType.online) {
      print("-----人气：${event.data}-----");
    } else if (event.type == LiveMessageType.superChat) {
      var scMessage = event.data as LiveSuperChatMessage;
      print("[SC]${scMessage.userName}：${scMessage.message}");
    }
  };
  danmaku.onClose = (event) {
    print(event);
  };
  //var categores = await site.getCategores();
  //print(categores.length);
  var detail = await site.getRoomDetail(roomId: "13");
  // var playQualites = await site.getPlayQualites(detail: detail);
  // var playUrls =
  //     await site.getPlayUrls(detail: detail, quality: playQualites.first);
  // for (var element in playUrls) {
  //   print(element);
  // }
  //print(detail);

  danmaku.start(detail.danmakuData);

  await Future.wait({});
}
