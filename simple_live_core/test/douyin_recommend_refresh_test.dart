import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:test/test.dart';

class TestDouyin extends DouyinSite {
  final checked = <String>[];
  bool fail = false;
  bool allOffline = false;
  int active = 0;
  int maxActive = 0;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    checked.add(roomId);
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(Duration.zero);
    active--;
    if (fail) throw StateError('network unavailable');
    return LiveRoomDetail(
      roomId: roomId,
      title: 'fresh',
      cover: 'fresh-cover',
      userName: roomId,
      userAvatar: '',
      online: 123,
      status: !allOffline && roomId != 'offline',
      url: '',
    );
  }
}

class RotatingVisitorDouyin extends TestDouyin {
  String visitor = 'ttwid=original-visitor';
  @override
  Future<Map<String, dynamic>> getRequestHeaders() async => {
    ...await super.getRequestHeaders(),
    'cookie': cookie.isEmpty ? visitor : cookie,
  };
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    final room = await super.getRoomDetail(roomId: roomId);
    visitor = 'ttwid=renewed-by-room-validation';
    return room;
  }
}

void main() {
  late Dio original;
  final requests = <RequestOptions>[];
  var ids = <String>[];
  var statusCode = 0;
  var sessionPagination = false;
  setUp(() {
    CoreLog.enableLog = false;
    requests.clear();
    ids = ['online', 'offline', 'online'];
    statusCode = 0;
    sessionPagination = false;
    original = HttpClient.instance.dio;
    HttpClient.instance.dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o);
            final responseIds = sessionPagination
                ? (o.uri.queryParameters['offset'] == '15' &&
                          o.headers['cookie'] == 'ttwid=original-visitor'
                      ? ['third', 'fourth']
                      : ['first', 'second'])
                : ids;
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'status_code': statusCode,
                  'data': {
                    'data': [
                      for (final id in responseIds)
                        {
                          'web_rid': id,
                          'room': {
                            'status': 0,
                            'title': 'stale',
                            'cover': {
                              'url_list': ['old'],
                            },
                            'owner': {'nickname': id},
                            'room_view_stats': {'display_value': '1'},
                          },
                        },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );
  });
  tearDown(() {
    HttpClient.instance.dio.close();
    HttpClient.instance.dio = original;
  });
  test('每次重新获取推荐并核验状态，过滤关播和重复房间，更新标题', () async {
    final site = TestDouyin();
    final first = await site.getRecommendRooms();
    await site.getRecommendRooms();
    expect(first.items.map((e) => e.roomId), ['online']);
    expect(first.items.single.title, 'fresh');
    expect(site.checked, ['online', 'offline', 'online', 'offline']);
    expect(requests[0].uri.queryParameters['_'], isNotEmpty);
    expect(
      requests[0].uri.queryParameters['_'],
      isNot(requests[1].uri.queryParameters['_']),
    );
    expect(requests[0].headers['Cache-Control'], 'no-cache');
  });
  test('全关播返回空列表，不保留旧推荐', () async {
    final site = TestDouyin()..allOffline = true;
    expect((await site.getRecommendRooms()).items, isEmpty);
  });
  test('房间核验续期访客会话不重置推荐分页，主动刷新才更新会话', () async {
    sessionPagination = true;
    final site = RotatingVisitorDouyin();
    final first = await site.getRecommendRooms();
    final second = await site.getRecommendRooms(page: 2);
    expect([...first.items, ...second.items].map((room) => room.roomId), [
      'first',
      'second',
      'third',
      'fourth',
    ]);
    await site.getRecommendRooms();
    expect(requests.last.headers['cookie'], 'ttwid=renewed-by-room-validation');
    site.cookie = 'ttwid=new-account';
    await site.getRecommendRooms(page: 2);
    expect(requests.last.headers['cookie'], 'ttwid=new-account');
  });
  test('不足15条但非空的推荐页不代表已经到末页', () async {
    ids = ['online', 'offline'];
    final result = await TestDouyin().getRecommendRooms(page: 2);
    expect(result.items.map((room) => room.roomId), ['online']);
    expect(result.hasMore, isTrue);
    expect(requests.single.uri.queryParameters['offset'], '15');
  });
  test('过滤后全关播也保留上游后续分页信号', () async {
    ids = ['offline'];
    final result = await TestDouyin().getRecommendRooms();
    expect(result.items, isEmpty);
    expect(result.hasMore, isTrue);
  });
  test('状态查询全部失败应报告错误，不伪装成全部关播', () async {
    final site = TestDouyin()..fail = true;
    await expectLater(site.getRecommendRooms(), throwsA(anything));
  });
  test('接口业务错误不能当作成功推荐', () async {
    statusCode = 10011;
    final site = TestDouyin();
    await expectLater(site.getRecommendRooms(), throwsA(anything));
    expect(site.checked, isEmpty);
  });
  test('状态校验最多四并发并保持推荐顺序', () async {
    ids = List.generate(15, (index) => '$index');
    final site = TestDouyin();
    final result = await site.getRecommendRooms();
    expect(site.maxActive, 4);
    // Invalid web_rid=0 must not produce a broken card.
    expect(result.items.map((e) => e.roomId), ids.skip(1));
    expect(result.hasMore, isTrue);
  });
}
