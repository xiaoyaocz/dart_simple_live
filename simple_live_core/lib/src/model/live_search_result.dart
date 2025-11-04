import 'dart:convert';
import 'package:simple_live_core/src/model/live_anchor_item.dart';
import 'package:simple_live_core/src/model/live_room_item.dart';

class LiveSearchRoomResult {
  final bool hasMore;
  final List<LiveRoomItem> items;
  LiveSearchRoomResult({
    required this.hasMore,
    required this.items,
  });

  @override
  String toString() {
    return json.encode({
      "hasMore": hasMore,
      "items": items.map((e) => json.decode(e.toString())).toList(),
    });
  }
}

class LiveSearchAnchorResult {
  final bool hasMore;
  final List<LiveAnchorItem> items;
  LiveSearchAnchorResult({
    required this.hasMore,
    required this.items,
  });

  @override
  String toString() {
    return json.encode({
      "hasMore": hasMore,
      "items": items.map((e) => json.decode(e.toString())).toList(),
    });
  }
}
