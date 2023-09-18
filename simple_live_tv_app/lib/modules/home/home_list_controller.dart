import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class HomeListController extends BasePageController<LiveRoomItemExt> {
  final Site site;
  HomeListController(this.site);

  @override
  Future<List<LiveRoomItemExt>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getRecommendRooms(page: page);

    return result.items
        .map((e) => LiveRoomItemExt(
              roomId: e.roomId,
              title: e.title,
              cover: e.cover,
              userName: e.userName,
            ))
        .toList();
  }
}

class LiveRoomItemExt extends LiveRoomItem {
  LiveRoomItemExt({
    required super.roomId,
    required super.title,
    required super.cover,
    required super.userName,
  });

  AppFocusNode focusNode = AppFocusNode();
}
