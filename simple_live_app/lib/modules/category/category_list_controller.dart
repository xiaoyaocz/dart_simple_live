import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/custom_category_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryListController extends BasePageController<AppLiveCategory> {
  static const String kCustomGroupId = '_custom_categories';

  final Site site;
  List<LiveCategory> _remoteCategories = const [];

  CategoryListController(this.site);

  @override
  Future<List<AppLiveCategory>> getData(int page, int pageSize) async {
    try {
      final result = await site.liveSite.getCategores();
      _remoteCategories = result;
    } catch (e) {
      if (_customSubCategories().isEmpty) {
        rethrow;
      }
      Log.w('${site.name} 分类拉取失败，仅展示自定义分区: $e');
      SmartDialog.showToast('${site.name} 在线分类拉取失败，已保留自定义分区');
    }
    return _mergeCategories(_remoteCategories);
  }

  void syncCustomCategories() {
    final merged = _mergeCategories(_remoteCategories);
    list.assignAll(merged);
    pageEmpty.value = merged.isEmpty;
    if (merged.isNotEmpty) {
      pageError.value = false;
    }
  }

  List<LiveSubCategory> _customSubCategories() {
    if (!Get.isRegistered<CustomCategoryService>()) {
      return const [];
    }
    return CustomCategoryService.instance.subCategoriesForSite(site.id);
  }

  List<AppLiveCategory> _mergeCategories(List<LiveCategory> remote) {
    final customChildren = _customSubCategories();
    final merged = <AppLiveCategory>[
      if (customChildren.isNotEmpty)
        AppLiveCategory(
          id: kCustomGroupId,
          name: '自定义分区',
          children: customChildren,
        ),
      ...remote.map((e) => AppLiveCategory.fromLiveCategory(e)),
    ];
    return merged;
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
