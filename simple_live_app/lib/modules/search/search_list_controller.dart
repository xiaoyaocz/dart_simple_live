import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SearchListController extends BasePageController<LiveRoomItem> {
  String keyword = "";
  final Site site;
  SearchListController(
    this.site,
  );

  @override
  Future refreshData() async {
    if (keyword.isEmpty) {
      return;
    }
    return await super.refreshData();
  }

  @override
  Future<List<LiveRoomItem>> getData(int page, int pageSize) async {
    var result = await site.liveSite.search(keyword, page: page);

    return result.items;
  }

  void clear() {
    pageEmpty.value = false;
    list.clear();
  }
}
