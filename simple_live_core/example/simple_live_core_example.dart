import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/douyin_site.dart';

void main() async {
  CoreLog.enableLog = true;
  LiveSite site = DouyinSite();
  // var categores = await site.getCategores();

  // var categoryRooms =
  //     await site.getCategoryRooms(categores.first.children.first);
  var recommendRooms = await site.getRecommendRooms();
  var roomDetail =
      await site.getRoomDetail(roomId: recommendRooms.items.first.roomId);
  var qutalities = await site.getPlayQualites(detail: roomDetail);
  return;
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
  var detail = await site.getRoomDetail(roomId: "660679");
  var playQualites = await site.getPlayQualites(detail: detail);
  var playUrls =
      await site.getPlayUrls(detail: detail, quality: playQualites.first);
  for (var element in playUrls) {
    print(element);
  }
  danmaku.start(detail.danmakuData);
  await Future.wait({});
}
