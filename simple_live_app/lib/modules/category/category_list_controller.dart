import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryListController extends BasePageController<AppLiveCategory> {
  final Site site;
  CategoryListController(this.site);

  @override
  Future<List<AppLiveCategory>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getCategores();

    return result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
  }
}

class AppLiveCategory extends LiveCategory {
  var showAll = false.obs;
  AppLiveCategory({
    required super.id,
    required super.name,
    required super.children,
  }) {
    showAll.value = children.length < 19;
  }

  List<LiveSubCategory> get take15 => children.take(15).toList();

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(
      children: item.children,
      id: item.id,
      name: item.name,
    );
  }
}
