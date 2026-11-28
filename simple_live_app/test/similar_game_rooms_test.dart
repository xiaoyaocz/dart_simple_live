import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/similar_game_rooms.dart';
import 'package:simple_live_app/widgets/similar_game_rooms_sheet.dart';

LiveRoomDetail detail(
        {String id = '1', String? category = '1732', String name = '我的世界'}) =>
    LiveRoomDetail(
        roomId: id,
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: true,
        url: '',
        categoryId: category,
        categoryName: name);

class _Site extends LiveSite {
  _Site(String platform) {
    id = platform;
  }
  int catalogs = 0, requests = 0;
  bool fail = false;
  LiveSubCategory? received;
  Completer<LiveCategoryResult>? gate;
  @override
  Future<List<LiveCategory>> getCategores() async {
    catalogs++;
    return [
      LiveCategory(id: 'parent', name: '游戏', children: [
        LiveSubCategory(id: '1732', name: '我的世界', parentId: 'parent'),
        LiveSubCategory(id: '999', name: '别的游戏', parentId: 'parent'),
      ])
    ];
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category,
      {int page = 1}) async {
    requests++;
    received = category;
    if (fail) throw StateError('temporary');
    if (gate != null) return gate!.future;
    return LiveCategoryResult(hasMore: false, items: [
      LiveRoomItem(roomId: 'other', title: '直播', cover: '', userName: '主播'),
    ]);
  }
}

class _Douyin extends DouyinSite {
  int html = 0, rooms = 0;
  @override
  Future<LiveSubCategory?> getRoomGameCategory(String roomId) async {
    html++;
    return LiveSubCategory(id: '1732,2', parentId: '1,1', name: '我的世界');
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category,
      {int page = 1}) async {
    rooms++;
    return LiveCategoryResult(hasMore: false, items: []);
  }
}

void main() {
  for (final platform in ['huya', 'douyu']) {
    test('$platform已有分类ID直取主播，不再读取分类目录', () async {
      final site = _Site(platform);
      final result = await SimilarGameRoomsLoader().load(site, detail());
      expect(result?.rooms, hasLength(1));
      expect(site.catalogs, 0);
      expect(site.requests, 1);
    });
  }
  test('抖音复用最深分区ID，不再获取房间网页', () async {
    final site = _Douyin();
    await SimilarGameRoomsLoader().load(site, detail(category: '1732,2'));
    expect(site.html, 0);
    expect(site.rooms, 1);
  });
  test('抖音缺分区ID时保留网页回退', () async {
    final site = _Douyin();
    await SimilarGameRoomsLoader().load(site, detail(category: null));
    expect(site.html, 1);
  });
  test('B站保留真实父分区，不虚构parentId，分类目录跨游戏复用', () async {
    final site = _Site('bilibili');
    final loader = SimilarGameRoomsLoader();
    await loader.load(site, detail());
    expect(site.received?.parentId, 'parent');
    await loader.load(site, detail(category: '999', name: '别的游戏'));
    expect(site.catalogs, 1);
    expect(site.received?.id, '999');
  });
  test('同平台同分类的并发、重复打开和另一个主播共用一次请求', () async {
    final site = _Site('huya')..gate = Completer<LiveCategoryResult>();
    final loader = SimilarGameRoomsLoader();
    final a = loader.load(site, detail());
    final b = loader.load(site, detail(id: '2'));
    await Future<void>.delayed(Duration.zero);
    expect(site.requests, 1);
    site.gate!.complete(LiveCategoryResult(hasMore: false, items: []));
    await Future.wait([a, b]);
    await loader.load(site, detail());
    expect(site.requests, 1);
  });
  test('30秒过期、主动刷新重新请求，失败不会污染缓存', () async {
    var now = DateTime(2026);
    final loader = SimilarGameRoomsLoader(now: () => now);
    final site = _Site('huya');
    await loader.load(site, detail());
    now = now.add(const Duration(seconds: 31));
    await loader.load(site, detail());
    expect(site.requests, 2);
    site.fail = true;
    await expectLater(
        loader.load(site, detail(), force: true), throwsStateError);
    site.fail = false;
    await loader.load(site, detail());
    expect(site.requests, 4);
  });
  test('ID优先于名称，只有名称时保留目录匹配', () async {
    final site = _Site('bilibili');
    final loader = SimilarGameRoomsLoader();
    await loader.load(site, detail(category: '999'));
    expect(site.received?.id, '999');
    await loader.load(site, detail(category: null));
    expect(site.received?.id, '1732');
  });
  test('缓存最多16类，淘汰后重新请求', () async {
    final site = _Site('huya');
    final loader = SimilarGameRoomsLoader();
    for (var i = 1; i <= 17; i++) {
      await loader.load(site, detail(category: '$i', name: '游戏$i'));
    }
    expect(site.requests, 17);
    await loader.load(site, detail(category: '1', name: '游戏1'));
    expect(site.requests, 18);
  });
  testWidgets('请求有超时，迟到结果不能锁死后续重试', (tester) async {
    final site = _Site('huya')..gate = Completer<LiveCategoryResult>();
    final loader = SimilarGameRoomsLoader();
    final future = loader.load(site, detail());
    final checked = expectLater(future, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 9));
    await checked;
    site.gate!.complete(LiveCategoryResult(hasMore: false, items: []));
    site.gate = null;
    await loader.load(site, detail());
    expect(site.requests, 2);
  });
  testWidgets('弹窗立即显示、请求不随重建重复、失败可在原窗重试', (tester) async {
    final site = _Site('huya')..fail = true;
    final loader = SimilarGameRoomsLoader();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SimilarGameRoomsSheet(
      site: site,
      detail: detail(),
      loader: loader,
      onRoomSelected: (_) {},
    ))));
    expect(find.text('同类游戏主播'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    expect(site.requests, 1);
    site.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('主播'), findsOneWidget);
    expect(site.requests, 2);
    await tester.tap(find.byTooltip('刷新同类主播'));
    await tester.pumpAndSettle();
    expect(site.requests, 3);
  });
  testWidgets('关闭加载弹窗后迟到结果不更新已销毁组件', (tester) async {
    final site = _Site('huya')..gate = Completer<LiveCategoryResult>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SimilarGameRoomsSheet(
      site: site,
      detail: detail(),
      loader: SimilarGameRoomsLoader(),
      onRoomSelected: (_) {},
    ))));
    await tester.pumpWidget(const SizedBox());
    site.gate!.complete(LiveCategoryResult(hasMore: false, items: []));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
