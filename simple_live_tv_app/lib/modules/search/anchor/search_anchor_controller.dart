import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class SearchAnchorController extends BasePageController<LiveAnchorItemExt> {
  final String keyword;
  SearchAnchorController(this.keyword);
  var siteId = Constant.kBiliBili.obs;
  var site = Sites.allSites[Constant.kBiliBili]!;

  @override
  void onInit() {
    scrollController.addListener(scrollListener);
    refreshData();
    super.onInit();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
        (scrollController.position.maxScrollExtent - 100.w)) {
      loadData();
    }
  }

  void setSite(String id) {
    siteId.value = id;
    site = Sites.allSites[id]!;
    refreshData();
  }

  @override
  Future<List<LiveAnchorItemExt>> getData(int page, int pageSize) async {
    var result = await site.liveSite.searchAnchors(keyword, page: page);

    return result.items
        .map((e) => LiveAnchorItemExt(
              roomId: e.roomId,
              avatar: e.avatar,
              liveStatus: e.liveStatus,
              userName: e.userName,
            ))
        .toList();
  }

  @override
  void onClose() {
    scrollController.removeListener(scrollListener);
    super.onClose();
  }
}

class LiveAnchorItemExt extends LiveAnchorItem {
  LiveAnchorItemExt({
    required super.roomId,
    required super.avatar,
    required super.liveStatus,
    required super.userName,
  });

  AppFocusNode focusNode = AppFocusNode();
}
