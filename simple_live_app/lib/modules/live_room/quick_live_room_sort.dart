import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_category_name.dart';

List<FollowUser> sortQuickLiveRooms(
    List<FollowUser> items, List<String> siteOrder) {
  final indexed = items.asMap().entries.toList();
  final siteRanks = {
    for (var i = 0; i < siteOrder.length; i++) siteOrder[i]: i
  };
  final categories = <int, (String, String)>{};
  final categoryOrder = <(String, String), int>{};
  final liveCounts = <(String, String), int>{};
  const broadCategories = {
    '游戏',
    '竞技游戏',
    '射击游戏',
    '单机游戏',
    '角色扮演',
    '棋牌',
    '主机游戏',
  };
  for (final entry in indexed) {
    final item = entry.value;
    siteRanks.putIfAbsent(item.siteId, () => siteRanks.length);
    final name = normalizeFollowCategory(item.categoryName);
    final category =
        (item.siteId, broadCategories.contains(name) ? '其他' : name);
    categories[entry.key] = category;
    categoryOrder.putIfAbsent(category, () => entry.key);
    liveCounts[category] =
        (liveCounts[category] ?? 0) + (item.liveStatus.value == 2 ? 1 : 0);
  }
  indexed.sort((a, b) {
    final platform =
        siteRanks[a.value.siteId]!.compareTo(siteRanks[b.value.siteId]!);
    if (platform != 0) return platform;
    final aCategory = categories[a.key]!;
    final bCategory = categories[b.key]!;
    if (aCategory != bCategory) {
      if (aCategory.$2 == '其他') return 1;
      if (bCategory.$2 == '其他') return -1;
      final count = liveCounts[bCategory]!.compareTo(liveCounts[aCategory]!);
      return count != 0
          ? count
          : categoryOrder[aCategory]!.compareTo(categoryOrder[bCategory]!);
    }
    final aHeat = a.value.heat;
    final bHeat = b.value.heat;
    if (aHeat == null && bHeat != null) return 1;
    if (aHeat != null && bHeat == null) return -1;
    final heat = aHeat == null ? 0 : bHeat!.compareTo(aHeat);
    return heat != 0 ? heat : a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}
