import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_category_name.dart';

/// 按标准化后的分类名称对关注主播分组，保留原出现顺序。
Map<String, List<FollowUser>> groupFollowUsersByCategory(
    Iterable<FollowUser> users) {
  final groups = <String, List<FollowUser>>{};
  for (final item in users) {
    final name = normalizeFollowCategory(item.categoryName);
    groups.putIfAbsent(name, () => []).add(item);
  }
  return groups;
}

/// 同平台优先，其次按热度降序、原索引稳定排序。
List<FollowUser> sortFollowCategoryMembers(
    List<FollowUser> members, List<String> siteOrder) {
  final indexed = members.asMap().entries.toList();
  final ranks = {for (var i = 0; i < siteOrder.length; i++) siteOrder[i]: i};
  for (final item in members) {
    ranks.putIfAbsent(item.siteId, () => ranks.length);
  }
  indexed.sort((a, b) {
    final platform = ranks[a.value.siteId]!.compareTo(ranks[b.value.siteId]!);
    if (platform != 0) return platform;
    final aHeat = a.value.heat;
    final bHeat = b.value.heat;
    if (aHeat == null && bHeat != null) return 1;
    if (aHeat != null && bHeat == null) return -1;
    final heat = aHeat == null ? 0 : bHeat!.compareTo(aHeat);
    return heat != 0 ? heat : a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}

/// 按当前已开播人数降序排列分类；"其他"固定置底，同人数沿用上一轮顺序。
List<MapEntry<String, List<FollowUser>>> sortFollowCategoryGroups(
  Map<String, List<FollowUser>> groups, {
  List<String>? previousOrder,
}) {
  final entries = groups.entries.toList();
  final orderBase = previousOrder ?? const <String>[];
  final priorRanks = {
    for (var i = 0; i < orderBase.length; i++) orderBase[i]: i,
  };
  final order = {
    for (var i = 0; i < entries.length; i++)
      entries[i].key: priorRanks[entries[i].key] ?? orderBase.length + i,
  };
  final liveCounts = {
    for (final entry in entries)
      entry.key: entry.value.where((item) => item.liveStatus.value == 2).length,
  };
  entries.sort((a, b) {
    if (a.key == b.key) return 0;
    if (a.key == '其他') return 1;
    if (b.key == '其他') return -1;
    final difference = liveCounts[b.key]!.compareTo(liveCounts[a.key]!);
    return difference != 0
        ? difference
        : order[a.key]!.compareTo(order[b.key]!);
  });
  // 刷新暂时清空列表时保留顺序，避免同人数分类在重新加载后跳动。
  if (previousOrder != null && entries.isNotEmpty) {
    previousOrder
      ..clear()
      ..addAll(entries.map((entry) => entry.key));
  }
  return entries;
}
