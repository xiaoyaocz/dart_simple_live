import 'package:simple_live_core/src/model/live_room_item.dart';

class LiveSearchResult {
  final bool hasMore;
  final List<LiveRoomItem> items;
  LiveSearchResult({
    required this.hasMore,
    required this.items,
  });
}
