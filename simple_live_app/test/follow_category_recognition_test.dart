import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_app/modules/follow_user/follow_category_name.dart';
import 'package:simple_live_core/src/model/room_category_name.dart';

void main() {
  test('叶子游戏字段优先于大类，分类对象也读取子级名称', () {
    expect(douyinCategoryName({
      'game_name': '竞技游戏',
      'leafCategory': {'name': '英雄联盟'},
      'subCategory': {'name': '射击游戏'},
    }), '英雄联盟');
    expect(douyinCategoryName({
      'game_name': '角色扮演',
      'sub_category': {'name': '角色扮演', 'subCategory': {'name': '鸣潮'}},
    }), '鸣潮');
    expect(douyinCategoryName({'game_name': '棋牌', 'partitionName': '三角洲行动'}), '三角洲行动');
    expect(firstCategoryName(['角色扮演', '棋牌', '穿越火线']), '穿越火线');
    expect(firstCategoryName(['射击游戏', '竞技游戏']), '射击游戏');
  });
  test('叶子分类优先于普通游戏字段，并保留缺失数据回退', () {
    expect(douyinCategoryName({'gameName': '游戏', 'subCategory': 'CS2'}), 'CS2');
    expect(douyinCategoryName({'game_name': '游戏'}, {
      'leafCategory': {'name': 'DOTA2'},
    }), 'DOTA2');
    expect(douyinCategoryName({'leafCategory': '无畏契约', 'game_name': '英雄联盟'}), '无畏契约');
    expect(douyinCategoryName({'game_name': '角色扮演'}), '角色扮演');
    expect(douyinCategoryName({'leafCategory': {'id': 123}}), isNull);
    expect(normalizeFollowCategory('Counter-Strike 2专区'), 'CS2');
    expect(normalizeFollowCategory('dota 2'), 'DOTA2');
    expect(normalizeFollowCategory('CSGO'), isNot('CS2'));
  });
  test('抖音现有详情响应保留具体游戏，不新增分类或网页请求', () async {
    final original = HttpClient.instance.dio;
    final requests = <String>[];
    final dio = Dio();
    HttpClient.instance.dio = dio;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options.path);
      handler.resolve(Response(requestOptions: options, statusCode: 200,
          data: {'data': {'data': [{
            'id_str': '123', 'status': 4, 'title': '测试直播',
            'game_name': '无畏契约', 'owner': {},
          }], 'user': {'nickname': '测试主播', 'avatar_thumb': {'url_list': ['']}},
          }}));
    }));
    try {
      final room = await DouyinSite().getRoomDetailByWebRid('123');
      expect(room.categoryName, '无畏契约');
      expect(requests.length, 1);
      expect(requests.single, contains('/webcast/room/web/enter/'));
    } finally {
      dio.close();
      HttpClient.instance.dio = original;
    }
  });
  test('抖音使用最深平台分区，缺失叶标题回退到有效上级', () {
    final info = {'partition_road_map': {'partition': {'title': '游戏'},
      'sub_partition': {'partition': {'title': '射击游戏'},
        'sub_partition': {'partition': {'title': '无畏契约'}}}}};
    expect(douyinCategoryName({}, info), '无畏契约');
    expect(douyinCategoryName({'game_name': '永劫无间'}, info), '无畏契约');
    expect(douyinCategoryName({}, {'partition_road_map': {
      'partition': {'title': '音乐'}, 'sub_partition': {'partition': {'title': ''}}}}), '音乐');
    expect(douyinCategoryName({'game_tag': 0}), isNull);
  });
  test('各平台具体分类优先，空值占位符和无效数据不能成为分类', () {
    expect(firstCategoryName(['', null, 123, 'null', '未知', '英雄联盟']), '英雄联盟');
    expect(firstCategoryName(['游戏', '无畏契约', '游戏']), '无畏契约');
    expect(firstCategoryName(['主机游戏']), '主机游戏');
    expect(firstCategoryName([{}, [], 'undefined', '0']), isNull);
  });
  test('轻量标准化合并明确别名，但不混淆手游或猜测游戏', () {
    expect(normalizeFollowCategory(' LOL '), '英雄联盟');
    expect(normalizeFollowCategory('valorant专区'), '无畏契约');
    expect(normalizeFollowCategory('英雄联盟手游'), '英雄联盟手游');
    expect(normalizeFollowCategory(' 某新游戏专区 '), '某新游戏');
    expect(normalizeFollowCategory(null), '其他');
    expect(normalizeFollowCategory('null'), '其他');
    expect(normalizeFollowCategory('专区'), '其他');
    expect(normalizeFollowCategory('CS2'), normalizeFollowCategory('cs2'));
  });
}
