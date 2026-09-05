import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';

class MultiRoomItem {
  final Site site;
  final String roomId;
  final String userName;
  final String face;

  const MultiRoomItem({
    required this.site,
    required this.roomId,
    required this.userName,
    required this.face,
  });

  factory MultiRoomItem.fromFollow(FollowUser item) {
    return MultiRoomItem(
      site: Sites.allSites[item.siteId]!,
      roomId: item.roomId,
      userName: item.userName,
      face: item.face,
    );
  }

  String get key => "${site.id}_$roomId";
}
