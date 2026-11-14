import 'dart:convert';

import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/custom_category_item.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CustomCategoryService extends GetxService {
  static CustomCategoryService get instance =>
      Get.find<CustomCategoryService>();

  final RxList<CustomCategoryItem> items = <CustomCategoryItem>[].obs;
  final RxInt revision = 0.obs;

  @override
  void onInit() {
    super.onInit();
    reloadFromStorage(notifyControllers: false);
  }

  void reloadFromStorage({bool notifyControllers = true}) {
    if (!Get.isRegistered<LocalStorageService>()) {
      return;
    }
    final raw = LocalStorageService.instance
        .getValue(LocalStorageService.kCustomCategories, '[]');
    items.assignAll(decodeList(raw));
    revision.value++;
    if (notifyControllers) {
      _notifyCategoryControllers();
    }
  }

  static List<CustomCategoryItem> decodeList(dynamic raw) {
    dynamic decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return <CustomCategoryItem>[];
      }
      try {
        decoded = jsonDecode(trimmed);
      } catch (e) {
        Log.w('解析自定义分区 JSON 失败: $e');
        return <CustomCategoryItem>[];
      }
    }
    List<dynamic>? rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      if (decoded['items'] is List) {
        rawList = decoded['items'] as List;
      } else if (decoded['categories'] is List) {
        rawList = decoded['categories'] as List;
      }
    }
    if (rawList == null) {
      return <CustomCategoryItem>[];
    }

    final result = <CustomCategoryItem>[];
    final seen = <String>{};
    for (final entry in rawList) {
      final item = CustomCategoryItem.fromJson(entry);
      if (item == null || !seen.add(item.uniqueKey)) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  static String encodeList(List<CustomCategoryItem> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  List<CustomCategoryItem> itemsForSite(String siteId) {
    return items.where((item) => item.siteId == siteId).toList();
  }

  List<LiveSubCategory> subCategoriesForSite(String siteId) {
    return itemsForSite(siteId).map((e) => e.toLiveSubCategory()).toList();
  }

  bool contains(String siteId, String id) {
    return findItem(siteId, id) != null;
  }

  CustomCategoryItem? findItem(String siteId, String id) {
    final normalized = CustomCategoryItem.normalized(
      siteId: siteId,
      id: id,
      name: '_',
    );
    if (normalized.id.isEmpty) {
      return null;
    }
    for (final item in items) {
      if (item.uniqueKey == normalized.uniqueKey) {
        return item;
      }
    }
    return null;
  }

  Future<bool> upsert(
    CustomCategoryItem rawItem, {
    CustomCategoryItem? editingOriginal,
  }) async {
    final item = CustomCategoryItem.normalized(
      siteId: rawItem.siteId,
      id: rawItem.id,
      parentId: rawItem.parentId,
      name: rawItem.name,
      pic: rawItem.pic,
    );
    if (item.siteId.isEmpty || item.id.isEmpty || item.name.isEmpty) {
      return false;
    }

    final next = items.toList();
    if (editingOriginal != null &&
        editingOriginal.uniqueKey != item.uniqueKey) {
      next.removeWhere((e) => e.uniqueKey == editingOriginal.uniqueKey);
    }
    final existingIndex = next.indexWhere((e) => e.uniqueKey == item.uniqueKey);
    if (existingIndex >= 0) {
      next[existingIndex] = item;
    } else {
      next.insert(0, item);
    }
    items.assignAll(next);
    await _persistAndNotify();
    return true;
  }

  Future<bool> togglePin(CustomCategoryItem rawItem) async {
    if (contains(rawItem.siteId, rawItem.id)) {
      await remove(rawItem.siteId, rawItem.id);
      return false;
    }
    await upsert(rawItem);
    return true;
  }

  Future<void> remove(String siteId, String id) async {
    final targetKey = CustomCategoryItem.normalized(
      siteId: siteId,
      id: id,
      name: '_',
    ).uniqueKey;
    final before = items.length;
    items.removeWhere((e) => e.uniqueKey == targetKey);
    if (items.length != before) {
      await _persistAndNotify();
    }
  }

  Future<void> moveToTop(String siteId, String id) async {
    final targetKey = CustomCategoryItem.normalized(
      siteId: siteId,
      id: id,
      name: '_',
    ).uniqueKey;
    final index = items.indexWhere((e) => e.uniqueKey == targetKey);
    if (index <= 0) {
      return;
    }
    final target = items.removeAt(index);
    items.insert(0, target);
    await _persistAndNotify();
  }

  String exportJson({String? siteId}) {
    final target = siteId == null ? items.toList() : itemsForSite(siteId);
    return const JsonEncoder.withIndent('  ')
        .convert(target.map((e) => e.toJson()).toList());
  }

  Future<int> importJson(String content, {bool overwrite = false}) async {
    final incoming = decodeList(content);
    if (incoming.isEmpty) {
      return 0;
    }
    return applySyncData(incoming.map((e) => e.toJson()).toList(),
        overwrite: overwrite);
  }

  /// 应用备份/WebDAV/局域网同步传来的自定义分区数据。
  Future<int> applySyncData(
    dynamic raw, {
    required bool overwrite,
  }) async {
    final incoming = decodeList(raw)
        .where((item) => Sites.allSites.containsKey(item.siteId))
        .toList();
    if (overwrite) {
      items.assignAll(incoming);
      await _persistAndNotify();
      return incoming.length;
    }
    if (incoming.isEmpty) {
      return 0;
    }
    final merged = items.toList();
    var touched = 0;
    for (final item in incoming) {
      final idx = merged.indexWhere((e) => e.uniqueKey == item.uniqueKey);
      if (idx >= 0) {
        merged[idx] = item;
      } else {
        merged.add(item);
      }
      touched++;
    }
    items.assignAll(merged);
    await _persistAndNotify();
    return touched;
  }

  Future<void> _persistAndNotify() async {
    revision.value++;
    if (Get.isRegistered<LocalStorageService>()) {
      await LocalStorageService.instance.setValue(
        LocalStorageService.kCustomCategories,
        encodeList(items),
      );
    }
    _notifyCategoryControllers();
  }

  void _notifyCategoryControllers() {
    for (final siteId in Sites.allSites.keys) {
      if (Get.isRegistered<CategoryListController>(tag: siteId)) {
        Get.find<CategoryListController>(tag: siteId).syncCustomCategories();
      }
    }
  }
}
