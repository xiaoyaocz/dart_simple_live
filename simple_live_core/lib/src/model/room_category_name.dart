/// 仅选择现有响应中的有效名称，具体分区优先于平台大类。
String? firstCategoryName(Iterable<dynamic> values) {
  String? fallback;
  const broad = {
    '游戏', '手游', '网游', '主机游戏', '单机游戏', '射击游戏', '竞技游戏',
    '角色扮演', '角色扮演游戏', '棋牌', '棋牌游戏',
  };
  for (var value in values) {
    if (value is Map) {
      value = firstCategoryName([
        value['leafCategory'], value['leaf_category'],
        value['subCategory'], value['sub_category'],
        value['gameName'], value['game_name'], value['name'], value['title'],
      ]);
    }
    if (value is! String) continue;
    final name = value.trim();
    if (name.isEmpty ||
        {'null', 'undefined', '0', '未知', '未分类', '其他'}.contains(name.toLowerCase())) {
      continue;
    }
    fallback ??= name;
    if (!broad.contains(name)) return name;
  }
  return fallback;
}

/// 保留抖音网页路径的最深分区，即使它只返回 ID 而未返回标题。
List<Map> _douyinWebPartitions(Map room, Map? roomInfo) {
  var deepest = <Map>[];
  for (final source in [roomInfo, room]) {
    dynamic node = source?['partition_road_map'];
    final path = <Map>[];
    while (node is Map) {
      final partition = node['partition'];
      if (partition is Map) path.add(partition);
      node = node['sub_partition'];
    }
    if (path.length > deepest.length) deepest = path;
  }
  return deepest;
}

Map? douyinWebPartition(Map room, [Map? roomInfo]) {
  final path = _douyinWebPartitions(room, roomInfo);
  return path.isEmpty ? null : path.last;
}

String? douyinWebParentCategoryName(Map room, [Map? roomInfo]) {
  final path = _douyinWebPartitions(room, roomInfo);
  return firstCategoryName(path.reversed.skip(1)
      .map((partition) => partition['title'])
      .where((title) => title != '游戏'));
}

String? douyinWebPartitionId(Map? partition) {
  final id = partition?['id_str']?.toString();
  final type = partition?['type']?.toString();
  if (id == null || id.isEmpty || id == '0' || type == null) return null;
  return '$id,$type';
}

/// 抖音平台的分区路径可以有多级，按最深分区到主分区回退。
String? douyinCategoryName(Map room, [Map? roomInfo]) {
  final path = <dynamic>[];
  dynamic node = roomInfo?['partition_road_map'] ?? room['partition_road_map'];
  while (node is Map) {
    final partition = node['partition'];
    if (partition is Map) path.add(partition['title']);
    node = node['sub_partition'];
  }
  final game = room['game'];
  final gameTag = room['game_tag'];
  final subCategory = room['sub_category'];
  return firstCategoryName([
    room['leafCategory'], room['leaf_category'],
    roomInfo?['leafCategory'], roomInfo?['leaf_category'],
    ...path.reversed.take(path.length > 1 ? path.length - 1 : 0),
    room['game_name'],
    room['gameName'],
    game,
    gameTag,
    subCategory,
    room['subCategory'],
    roomInfo?['sub_category'], roomInfo?['subCategory'],
    room['category_name'],
    room['area_name'],
    room['areaName'], room['partition_name'], room['partitionName'],
    if (path.isNotEmpty) path.first,
  ]);
}
