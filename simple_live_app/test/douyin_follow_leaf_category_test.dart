import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/model/room_category_name.dart';
import 'package:get/get.dart' hide Response;
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';

class _Douyin extends DouyinSite {
  int detailRequests = 0;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    detailRequests++;
    return LiveRoomDetail(roomId: roomId, title: '', cover: '', userName: '',
        userAvatar: '', online: 100, status: true, url: '',
        categoryName: '射击游戏', leafCategoryName: '三角洲行动');
  }
}

class _FollowService extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

String _page() {
  final categories = [{'partition': {'id_str': '1', 'type': 2, 'title': '游戏'},
    'sub_partition': [{'partition': {'id_str': '2', 'type': 1, 'title': '竞技游戏'},
      'sub_partition': [{'partition': {'id_str': '1010014', 'type': 1, 'title': '英雄联盟'}}]}]}];
  final encoded = jsonEncode(jsonEncode(categories));
  return r'\"categoryData\":' + encoded.substring(1, encoded.length - 1);
}

void main() {
  test('分类目录首次失败不永久缓存空结果，后续缺分类刷新可恢复三级游戏', () async {
    final original = HttpClient.instance.dio;
    final dio = Dio();
    HttpClient.instance.dio = dio;
    var requests = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      requests++;
      h.resolve(Response(requestOptions: o, statusCode: 200,
          data: requests == 1 ? '无分类目录' : _page()));
    }));
    try {
      final site = DouyinSite();
      final detail = LiveRoomDetail(roomId: '1', title: '', cover: '', userName: '',
          userAvatar: '', online: 100, status: true, url: '', categoryId: '1010014,1');
      expect(await site.getFollowCategoryName(detail), '其他');
      expect(await site.getFollowCategoryName(detail), '英雄联盟');
      expect(await site.getFollowCategoryName(detail), '英雄联盟');
      expect(requests, 2);
    } finally {
      dio.close();
      HttpClient.instance.dio = original;
    }
  });
  test('网页路径逐级到最深处，浅层路径和普通候选字段不能覆盖三级', () {
    final room = {'game_name': '竞技游戏', 'leafCategory': '错误的软件候选',
      'partition_road_map': {'partition': {'title': '游戏'},
        'sub_partition': {'partition': {'title': '射击游戏'},
          'sub_partition': {'partition': {'id_str': '9', 'type': 1, 'title': '三角洲行动'}}}}};
    final leaf = douyinWebPartition(room, {'partition_road_map': {
      'partition': {'title': '游戏'}, 'sub_partition': {'partition': {'title': '射击游戏'}}}});
    expect(leaf?['title'], '三角洲行动');
    expect(douyinWebPartitionId(leaf), '9,1');
  });
  test('关注刷新复用一次抖音详情，保存叶子分类并可从旧模型字段读取', () async {
    final directory = await Directory.systemTemp.createTemp('douyin-follow-leaf-');
    final original = Sites.allSites['douyin']!;
    Hive.init(directory.path);
    Hive.registerAdapter(FollowUserAdapter(), override: true);
    final db = Get.put(DBService());
    db.followBox = await Hive.openBox<FollowUser>('FollowUser');
    final site = _Douyin();
    Sites.allSites['douyin'] = Site(id: original.id, name: original.name,
        logo: original.logo, liveSite: site);
    try {
      final item = FollowUser(id: 'douyin_1', roomId: '1', siteId: 'douyin',
          userName: '测试主播', face: '', addTime: DateTime(2026), categoryName: '射击游戏');
      await db.addFollow(item);
      final service = _FollowService()..followList.add(item);
      await service.updateLiveStatus(item);
      expect(site.detailRequests, 1);
      expect(item.categoryName, '三角洲行动');
      expect(item.liveStatus.value, 2);
      await db.followBox.close();
      db.followBox = await Hive.openBox<FollowUser>('FollowUser');
      expect(db.followBox.get(item.id)!.categoryName, '三角洲行动');
    } finally {
      Sites.allSites['douyin'] = original;
      await Hive.close();
      Get.reset();
      await directory.delete(recursive: true);
    }
  });
  test('真实响应形状：叶子ID标题为空，通过官方三级树识别，并复用已加载目录', () async {
    final original = HttpClient.instance.dio;
    final dio = Dio();
    HttpClient.instance.dio = dio;
    var roomRequests = 0;
    var directoryRequests = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      dynamic data;
      if (o.uri.path == '/') {
        directoryRequests++;
        data = _page();
      } else {
        roomRequests++;
        data = {'data': {'data': [{'id_str': '123', 'status': 4,
          'title': '标题不能用于猜分类', 'game_name': '射击游戏', 'owner': {}}],
          'user': {'nickname': '名称不能用于猜分类', 'avatar_thumb': {'url_list': ['']}},
          'partition_road_map': {'partition': {'id_str': '2', 'type': 1, 'title': '竞技游戏'},
            'sub_partition': {'partition': {'id_str': '1010014', 'type': 1, 'title': ''}}}}};
      }
      h.resolve(Response(requestOptions: o, statusCode: 200, data: data));
    }));
    try {
      final site = DouyinSite();
      final categories = await site.getCategores();
      expect(categories.single.children.last.name, '竞技游戏');
      final detail = await site.getRoomDetailByWebRid('123');
      expect(detail.categoryId, '1010014,1');
      expect(detail.leafCategoryName, isNull);
      expect(detail.webParentCategoryName, '竞技游戏');
      expect(await site.getFollowCategoryName(detail), '英雄联盟');
      expect(roomRequests, 1);
      expect(directoryRequests, 1);
      final fresh = DouyinSite();
      expect(await Future.wait(List.generate(20, (_) => fresh.getFollowCategoryName(detail))),
          everyElement('英雄联盟'));
      expect(directoryRequests, 2);
      expect(roomRequests, 1);
    } finally {
      dio.close();
      HttpClient.instance.dio = original;
    }
  });

  test('网页叶子标题直接使用，无目录请求，缺失三级才回退', () async {
    final site = DouyinSite();
    LiveRoomDetail detail({String? leaf, String? id}) => LiveRoomDetail(
      roomId: '1', title: '无畏契约', cover: '', userName: '英雄联盟',
      userAvatar: '', online: 0, status: true, url: '',
      categoryName: '竞技游戏', categoryId: id, leafCategoryName: leaf);
    expect(await site.getFollowCategoryName(detail(leaf: '三角洲行动', id: '99,1')), '三角洲行动');
    expect(await site.getFollowCategoryName(detail()), '其他');
    expect(await site.getFollowCategoryName(detail(leaf: '游戏')), '其他');
  });
}
