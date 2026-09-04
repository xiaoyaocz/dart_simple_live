import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class CategoryController extends BasePageController<AppLiveCategory> {
  var siteId = Constant.kBiliBili.obs;
  var site = Sites.allSites[Constant.kBiliBili]!;
  int _siteSwitchGeneration = 0;

  @override
  void onInit() {
    refreshData();
    super.onInit();
  }

  Future<void> setSite(String id) async {
    if (siteId.value == id) return;

    final nextSite = Sites.allSites[id]!;
    final generation = ++_siteSwitchGeneration;
    try {
      loadding.value = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      pageLoadding.value = true;

      final result = await nextSite.liveSite.getCategores();
      if (generation != _siteSwitchGeneration) {
        return;
      }
      final categories = result
          .map((e) => AppLiveCategory.fromLiveCategory(e, nextSite))
          .toList();

      site = nextSite;
      siteId.value = id;
      currentPage = 2;
      canLoadMore.value = false;
      pageEmpty.value = categories.isEmpty;
      list.value = categories;
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    } catch (e) {
      if (generation != _siteSwitchGeneration) {
        return;
      }
      handleError(e);
    } finally {
      if (generation == _siteSwitchGeneration) {
        loadding.value = false;
        pageLoadding.value = false;
      }
    }
  }

  @override
  Future<List<AppLiveCategory>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getCategores();

    return result
        .map((e) => AppLiveCategory.fromLiveCategory(e, site))
        .toList();
  }
}

class AppLiveCategory extends LiveCategory {
  var showAll = false.obs;
  final Site site;
  final List<LiveSubCategoryExt> childrenExt;
  AppLiveCategory({
    required super.id,
    required super.name,
    required super.children,
    required this.site,
  }) : childrenExt = children
            .map((e) => LiveSubCategoryExt.fromLiveSubCategory(e, site))
            .toList() {
    showAll.value = children.length < 19;
  }

  List<LiveSubCategoryExt> get take15 => childrenExt.take(15).toList();

  AppFocusNode moreFocusNode = AppFocusNode();

  factory AppLiveCategory.fromLiveCategory(LiveCategory item, Site site) {
    return AppLiveCategory(
      children: item.children,
      id: item.id,
      name: item.name,
      site: site,
    );
  }
}

class LiveSubCategoryExt extends LiveSubCategory {
  LiveSubCategoryExt({
    required String id,
    required String name,
    required String parentId,
    required this.site,
    String? pic,
    List<LiveSubCategoryExt> children = const [],
  })  : childrenExt = children,
        super(
          id: id,
          name: name,
          parentId: parentId,
          pic: pic,
          children: children,
        );

  factory LiveSubCategoryExt.fromLiveSubCategory(
    LiveSubCategory item,
    Site site,
  ) {
    return LiveSubCategoryExt(
      id: item.id,
      name: item.name,
      parentId: item.parentId,
      pic: item.pic,
      site: site,
      children: item.children
          .map((child) => LiveSubCategoryExt.fromLiveSubCategory(child, site))
          .toList(),
    );
  }

  final Site site;
  final List<LiveSubCategoryExt> childrenExt;
  AppFocusNode focusNode = AppFocusNode();
}
