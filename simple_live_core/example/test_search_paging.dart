import 'dart:convert';
import 'package:simple_live_core/simple_live_core.dart';

Future<void> main(List<String> args) async {
  final mode = args.isNotEmpty ? args[0] : "huya";
  CoreLog.enableLog = false;

  if (mode == "huya") {
    final keyword = args.length > 1 ? args[1] : "lol";
    final allIds = <String>[];
    for (var page = 1; page <= 6; page++) {
      final result = await HuyaSite().searchRooms(keyword, page: page);
      final ids = result.items.map((e) => e.roomId).toList();
      print("page $page count=${ids.length} hasMore=${result.hasMore}");
      print("  ids: ${ids.take(25).join(',')}");
      allIds.addAll(ids);
    }
    print("total=${allIds.length} unique=${allIds.toSet().length}");
  } else if (mode == "huya_anchor") {
    final keyword = args.length > 1 ? args[1] : "lol";
    final allIds = <String>[];
    for (var page = 1; page <= 6; page++) {
      final result = await HuyaSite().searchAnchors(keyword, page: page);
      final ids = result.items.map((e) => e.roomId).toList();
      print("anchor page $page count=${ids.length} hasMore=${result.hasMore}");
      print("  ids: ${ids.take(25).join(',')}");
      allIds.addAll(ids);
    }
    print("total=${allIds.length} unique=${allIds.toSet().length}");
  } else if (mode == "douyin") {
    final webRid = args.length > 1 ? args[1] : "";
    try {
      final detail = await DouyinSite().getRoomDetail(roomId: webRid);
      print(json.encode({
        "ok": true,
        "roomId": detail.roomId,
        "title": detail.title,
        "userName": detail.userName,
        "status": detail.status,
        "cover": detail.cover,
      }));
    } catch (e) {
      print(json.encode({"ok": false, "error": e.toString()}));
    }
  }
}
