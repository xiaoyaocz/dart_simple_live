import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class CategoryController extends BasePageController<AppLiveCategory> {
  var siteId = Constant.kBiliBili.obs;
  var site = Sites.allSites[Constant.kBiliBili]!;

  @override
  void onInit() {
    refreshData();
    super.onInit();
  }

  void setSite(String id) {
    siteId.value = id;
    site = Sites.allSites[id]!;
    refreshData();
  }

  @override
  Future<List<AppLiveCategory>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getCategores();

    return result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
  }
}

class AppLiveCategory extends LiveCategory {
  var showAll = false.obs;
  final List<LiveSubCategoryExt> childrenExt;
  AppLiveCategory({
    required super.id,
    required super.name,
    required super.children,
  }) : childrenExt = children
            .map((e) => LiveSubCategoryExt(
                  id: e.id,
                  name: e.name,
                  parentId: e.parentId,
                  pic: e.pic,
                ))
            .toList() {
    showAll.value = children.length < 19;
  }

  List<LiveSubCategoryExt> get take15 => childrenExt.take(15).toList();

  AppFocusNode moreFocusNode = AppFocusNode();

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(
      children: item.children,
      id: item.id,
      name: item.name,
    );
  }
}

class LiveSubCategoryExt extends LiveSubCategory {
  LiveSubCategoryExt({
    required super.id,
    required super.name,
    required super.parentId,
    super.pic,
  });

  AppFocusNode focusNode = AppFocusNode();
}
