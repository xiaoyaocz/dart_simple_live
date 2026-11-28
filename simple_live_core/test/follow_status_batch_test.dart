import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:test/test.dart';

class _SubclassBili extends BiliBiliSite {
  bool live = true;
  int liveStatusCalls = 0;

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    liveStatusCalls++;
    return live;
  }
}

class _SubclassHuya extends HuyaSite {
  bool live = true;
  int liveStatusCalls = 0;

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    liveStatusCalls++;
    return live;
  }
}

class _SubclassDouyu extends DouyuSite {
  bool live = false;
  int liveStatusCalls = 0;

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    liveStatusCalls++;
    return live;
  }
}

void main() {
  late Dio original;
  final requests = <RequestOptions>[];

  setUp(() {
    CoreLog.enableLog = false;
    requests.clear();
    original = HttpClient.instance.dio;
  });

  tearDown(() {
    HttpClient.instance.dio.close();
    HttpClient.instance.dio = original;
  });

  test('B站批量查询按40个切片、使用room_ids重复参数并支持短号与开播时间映射', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.uri.path == '/xlive/web-room/v1/index/getRoomBaseInfo') {
            final ids = options.uri.queryParametersAll['room_ids'] ?? const [];
            expect(options.uri.query, isNot(contains('room_ids[]')));
            final byRoomIds = <String, Map<String, dynamic>>{};
            for (final id in ids) {
              if (id == '6') {
                byRoomIds['7734200'] = {
                  'room_id': 7734200,
                  'short_id': 6,
                  'live_status': 1,
                  'online': 144132,
                  'area_name': '游戏赛事',
                  'parent_area_name': '赛事',
                  'live_time': '2026-11-14 10:25:51',
                  'title': 'S赛直播',
                };
              } else if (id == '45') {
                // 模拟遗漏第45号房间，验证上层可感知缺失并回退
                continue;
              } else {
                final numId = int.parse(id);
                byRoomIds[id] = {
                  'room_id': numId,
                  'short_id': 0,
                  'live_status': numId % 2 == 0 ? 1 : 0,
                  'online': numId * 10,
                  'area_name': '英雄联盟',
                  'parent_area_name': '网游',
                  'live_time': numId % 2 == 0
                      ? '2026-11-14 10:25:51'
                      : '0000-00-00 00:00:00',
                  'title': '房间$id',
                };
              }
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'code': 0,
                  'data': {'by_room_ids': byRoomIds},
                },
              ),
            );
            return;
          }
          if (options.uri.path == '/room/v1/Room/get_info') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'code': 0,
                  'data': {
                    'room_id': 45,
                    'live_status': 1,
                    'online': 999,
                    'area_name': '单机',
                    'parent_area_name': '主机游戏',
                    'live_time': '2026-11-28 08:00:00',
                    'title': '单房兜底',
                  },
                },
              ),
            );
            return;
          }
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    HttpClient.instance.dio = dio;

    final site = BiliBiliSite()..buvid3 = 'test-buvid3';
    expect(site.supportsFollowStatusBatch, isTrue);

    final roomIds = [
      '6',
      for (var i = 2; i <= 46; i++)
        if (i != 6) '$i',
    ];
    final result = await site.getFollowStatusBatch(roomIds: roomIds);

    expect(requests.length, 2);
    expect(requests[0].uri.queryParametersAll['room_ids']!.length, 40);
    expect(requests[1].uri.queryParametersAll['room_ids']!.length, 5);
    expect(result.length, 44);
    expect(result.containsKey('45'), isFalse);

    final shortRoom = result['6']!;
    expect(shortRoom.isLive, isTrue);
    expect(shortRoom.resolvedRoomId, '7734200');
    expect(shortRoom.online, 144132);
    expect(shortRoom.categoryName, '游戏赛事');
    expect(
      shortRoom.showTime,
      '${DateTime.parse('2026-11-14T10:25:51+08:00').millisecondsSinceEpoch ~/ 1000}',
    );
    expect(shortRoom.needsDetailFallback, isFalse);

    final offline = result['3']!;
    expect(offline.isLive, isFalse);
    expect(offline.showTime, isNull);
    expect(offline.online, isNull);
    expect(offline.needsDetailFallback, isFalse);

    final singleFallback = await site.getFollowStatus(roomId: '45');
    expect(singleFallback.isLive, isTrue);
    expect(singleFallback.online, 999);
    expect(singleFallback.categoryName, '单机');
    expect(singleFallback.needsDetailFallback, isFalse);
  });

  test('虎牙单次profileRoom返回全字段，失败时优雅回退HTML页提取', () async {
    var failProfile = false;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.uri.host == 'mp.huya.com') {
            if (failProfile) {
              handler.reject(DioException(requestOptions: options));
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'liveStatus': 'ON',
                    'liveData': {
                      'profileRoom': 660000,
                      'userCount': 329926,
                      'gameFullName': '英雄联盟',
                      'gameHostName': '网游',
                      'startTime': 1793092036,
                      'introduction': '虎牙测试',
                    },
                  },
                },
              ),
            );
            return;
          }
          if (options.uri.host == 'm.huya.com') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: '<script>window.HNF_GLOBAL_INIT = {"roomInfo":{"eLiveStatus":2,"tProfileInfo":{"lProfileRoom":660000},"tLiveInfo":{"lProfileRoom":660000,"lTotalCount":12000,"sGameFullName":"无畏契约","lStartTime":1793099000,"sRoomName":"HTML回退"}}}</script>',
              ),
            );
            return;
          }
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    HttpClient.instance.dio = dio;

    final site = HuyaSite();
    final apiStatus = await site.getFollowStatus(roomId: 'aliasName');
    expect(requests.single.uri.host, 'mp.huya.com');
    expect(apiStatus.isLive, isTrue);
    expect(apiStatus.resolvedRoomId, '660000');
    expect(apiStatus.online, 329926);
    expect(apiStatus.categoryName, '英雄联盟');
    expect(apiStatus.showTime, '1793092036');
    expect(apiStatus.needsDetailFallback, isFalse);

    requests.clear();
    failProfile = true;
    final htmlStatus = await site.getFollowStatus(roomId: '660000');
    expect(requests.map((r) => r.uri.host), ['mp.huya.com', 'm.huya.com']);
    expect(htmlStatus.isLive, isTrue);
    expect(htmlStatus.resolvedRoomId, '660000');
    expect(htmlStatus.online, 12000);
    expect(htmlStatus.categoryName, '无畏契约');
    expect(htmlStatus.showTime, '1793099000');
    expect(htmlStatus.needsDetailFallback, isFalse);
  });

  test('斗鱼单次betard返回热度/分区/开播时间，并正确处理轮播与game.tag_name', () async {
    var videoLoop = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.uri.path == '/betard/9263298') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'room': {
                    'room_id': 9263298,
                    'show_status': 1,
                    'videoLoop': videoLoop,
                    'show_time': 1795772503,
                    'cate_name': null,
                    'second_lvl_name': null,
                    'room_name': '斗鱼测试',
                    'room_biz_all': {
                      'hot': '6728296',
                      'videoLoop': videoLoop,
                    },
                  },
                  'game': {'tag_name': '和平精英'},
                },
              ),
            );
            return;
          }
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    HttpClient.instance.dio = dio;

    final site = DouyuSite();
    final live = await site.getFollowStatus(roomId: '9263298');
    expect(requests.single.uri.path, '/betard/9263298');
    expect(live.isLive, isTrue);
    expect(live.resolvedRoomId, '9263298');
    expect(live.online, 6728296);
    expect(live.categoryName, '和平精英');
    expect(live.showTime, '1795772503');
    expect(live.needsDetailFallback, isFalse);

    videoLoop = 1;
    final replay = await site.getFollowStatus(roomId: '9263298');
    expect(replay.isLive, isFalse);
    expect(replay.online, isNull);
    expect(replay.showTime, isNull);
    expect(replay.needsDetailFallback, isFalse);
  });

  test('测试替身子类仅重写getLiveStatus时自动走兼容回退路径', () async {
    final bili = _SubclassBili();
    final huya = _SubclassHuya();
    final douyu = _SubclassDouyu();

    expect(bili.supportsFollowStatusBatch, isFalse);
    final biliStatus = await bili.getFollowStatus(roomId: '1');
    expect(bili.liveStatusCalls, 1);
    expect(biliStatus.isLive, isTrue);
    expect(biliStatus.needsDetailFallback, isTrue);

    final huyaStatus = await huya.getFollowStatus(roomId: '1');
    expect(huya.liveStatusCalls, 1);
    expect(huyaStatus.isLive, isTrue);
    expect(huyaStatus.needsDetailFallback, isTrue);

    final douyuStatus = await douyu.getFollowStatus(roomId: '1');
    expect(douyu.liveStatusCalls, 1);
    expect(douyuStatus.isLive, isFalse);
    expect(douyuStatus.needsDetailFallback, isTrue);
  });

  test('抖音轻量 getFollowStatus 走签名 enter 接口，444 时只刷新一次访客 cookie 并重签重试且不拉 HTML',
      () async {
    var enterCalls = 0;
    var headCalls = 0;
    var htmlCalls = 0;
    var categoryTreeCalls = 0;
    var failFirstWith444 = true;
    var leafTitle = '王者荣耀';
    var leafId = '999';

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.uri.path == '/webcast/room/web/enter/') {
            enterCalls++;
            if (failFirstWith444 && enterCalls == 1) {
              handler.reject(
                DioException.badResponse(
                  statusCode: 444,
                  requestOptions: options,
                  response: Response(requestOptions: options, statusCode: 444),
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'data': [
                      {
                        'id_str': '7001',
                        'status': 2,
                        'title': '抖音轻量测试',
                        'room_view_stats': {'display_value': 4321},
                      },
                    ],
                    'partition_road_map': {
                      'partition': {'id_str': '2', 'type': 1, 'title': '竞技游戏'},
                      'sub_partition': {
                        'partition': {
                          'id_str': leafId,
                          'type': 1,
                          'title': leafTitle,
                        },
                      },
                    },
                  },
                },
              ),
            );
            return;
          }
          if (options.method == 'HEAD' && options.uri.path == '/') {
            headCalls++;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 404,
                headers: Headers.fromMap({
                  'set-cookie': ['ttwid=refreshed_ttwid; Path=/; HttpOnly'],
                }),
              ),
            );
            return;
          }
          if (options.method == 'GET' && options.uri.path == '/') {
            categoryTreeCalls++;
            final cats = [
              {
                'partition': {'id_str': '1', 'type': 2, 'title': '游戏'},
                'sub_partition': [
                  {
                    'partition': {'id_str': '888', 'type': 1, 'title': '无畏契约'},
                  },
                ],
              },
            ];
            final encoded = jsonEncode(jsonEncode(cats));
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: r'\"categoryData\":' + encoded.substring(1, encoded.length - 1),
              ),
            );
            return;
          }
          htmlCalls++;
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    HttpClient.instance.dio = dio;

    final site = DouyinSite();
    final direct = await site.getFollowStatus(roomId: '123456');
    expect(enterCalls, 2);
    expect(headCalls, 1);
    expect(htmlCalls, 0);
    expect(direct.isLive, isTrue);
    expect(direct.online, 4321);
    expect(direct.categoryName, '王者荣耀');
    expect(direct.needsDetailFallback, isFalse);

    // 若分类仍是“游戏”且目录尚未加载，则返回 categoryId 走轻量二级查表；
    // 目录加载后则直接命中内存映射，不再 fallback。
    failFirstWith444 = false;
    leafTitle = '游戏';
    leafId = '888';
    final needsLookup = await site.getFollowStatus(roomId: '123456');
    expect(needsLookup.needsDetailFallback, isTrue);
    expect(needsLookup.categoryId, '888,1');
    expect(needsLookup.parentCategoryName, '竞技游戏');

    await site.getCategores();
    expect(categoryTreeCalls, 1);
    final cachedHit = await site.getFollowStatus(roomId: '123456');
    expect(cachedHit.needsDetailFallback, isFalse);
    expect(cachedHit.categoryName, '无畏契约');
    expect(htmlCalls, 0);
  });
}
