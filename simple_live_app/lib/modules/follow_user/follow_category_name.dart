/// 合并明确的游戏别名，不根据主播昵称或直播标题猜测分类。
String normalizeFollowCategory(String? value) {
  var name = value?.trim() ?? '';
  if (name.isEmpty ||
      {'null', 'undefined', '0', '未知', '未分类', '其他'}.contains(name.toLowerCase())) {
    return '其他';
  }
  name = name.replaceFirst(RegExp(r'\s*专区$'), '').trim();
  if (name.isEmpty) return '其他';
  const aliases = {
    'lol': '英雄联盟',
    'league of legends': '英雄联盟',
    '英雄联盟（lol）': '英雄联盟',
    'valorant': '无畏契约',
    'pubg': '绝地求生',
    'minecraft': '我的世界',
    'naraka: bladepoint': '永劫无间',
    'cs2': 'CS2',
    'counter-strike 2': 'CS2',
    'dota2': 'DOTA2',
    'dota 2': 'DOTA2',
  };
  return aliases[name.toLowerCase()] ?? name.toLowerCase();
}
