import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// 用户自定义的直播分区条目。
class CustomCategoryItem {
  final String siteId;
  final String id;
  final String parentId;
  final String name;
  final String? pic;

  const CustomCategoryItem({
    required this.siteId,
    required this.id,
    this.parentId = '',
    required this.name,
    this.pic,
  });

  /// 构造并规范化字段（如抖音统一转为 `partitionId,partitionType`）。
  factory CustomCategoryItem.normalized({
    required String siteId,
    required String id,
    String parentId = '',
    required String name,
    String? pic,
  }) {
    final cleanSiteId = siteId.trim();
    var cleanId = id.trim();
    var cleanParentId = parentId.trim();
    if (cleanSiteId == Constant.kDouyin) {
      if (cleanId.isNotEmpty) {
        cleanId = DouyinSite.normalizeCategoryId(cleanId);
      }
      if (cleanParentId.isNotEmpty) {
        cleanParentId = DouyinSite.normalizeCategoryId(cleanParentId);
      }
    }
    if (cleanParentId.isEmpty) {
      cleanParentId = cleanId;
    }
    final cleanPic = pic?.trim();
    return CustomCategoryItem(
      siteId: cleanSiteId,
      id: cleanId,
      parentId: cleanParentId,
      name: name.trim(),
      pic: cleanPic == null || cleanPic.isEmpty ? null : cleanPic,
    );
  }

  /// 构造用于去重查找的规范化键值。
  String get uniqueKey => '$siteId::$id';

  LiveSubCategory toLiveSubCategory() {
    final resolvedPic = pic?.trim();
    return LiveSubCategory(
      id: id,
      name: name,
      parentId: parentId.isNotEmpty ? parentId : id,
      pic: resolvedPic != null && resolvedPic.isNotEmpty ? resolvedPic : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      'id': id,
      if (parentId.isNotEmpty && parentId != id) 'parentId': parentId,
      'name': name,
      if (pic != null && pic!.isNotEmpty) 'pic': pic,
    };
  }

  static CustomCategoryItem? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final siteId = raw['siteId']?.toString().trim() ?? '';
    final id = raw['id']?.toString().trim() ?? '';
    final name = raw['name']?.toString().trim() ?? '';
    if (siteId.isEmpty || id.isEmpty || name.isEmpty) {
      return null;
    }
    final parentId = raw['parentId']?.toString().trim() ?? '';
    final pic = raw['pic']?.toString().trim();
    return CustomCategoryItem.normalized(
      siteId: siteId,
      id: id,
      parentId: parentId,
      name: name,
      pic: pic,
    );
  }
}
