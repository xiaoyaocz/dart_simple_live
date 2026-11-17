import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;
import 'package:test/test.dart';

class _Bili extends BiliBiliSite {
  _Bili({this.status = 0});
  final int? status;
  @override
  Future<Map<String, dynamic>> getRoomInfo({required String roomId}) async => {
    'room_info': {'room_id': 1, 'title': '上次直播', 'live_status': status},
    'anchor_info': {
      'base_info': {'uname': '主播', 'face': ''},
    },
  };
  @override
  Future<Map<String, String>> getWbiSign(String url) async => {};
  @override
  Future<Map<String, String>> getHeader() async => {};
}

void main() {
  late Dio original;
  late List<String> paths;
  setUp(() {
    CoreLog.enableLog = false;
    original = core.HttpClient.instance.dio;
    core.HttpClient.instance.dio = Dio();
    paths = [];
  });
  tearDown(() {
    core.HttpClient.instance.dio.close();
    core.HttpClient.instance.dio = original;
  });
  void respond(dynamic Function(RequestOptions) build) {
    core.HttpClient.instance.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          paths.add(request.uri.path);
          final data = build(request);
          if (data == null) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
                error: 'unexpected extra request',
              ),
            );
          } else {
            handler.resolve(Response(requestOptions: request, data: data));
          }
        },
      ),
    );
  }

  test('B站已下播直接返回，不再请求弹幕鉴权', () async {
    respond((_) => null);
    final room = await _Bili().getRoomDetail(roomId: '1');
    expect(room.status, isFalse);
    expect(room.userName, '主播');
    expect(paths, isEmpty);
    expect(room.danmakuData, isNull);
  });

  test('B站仍在直播时继续读取弹幕鉴权', () async {
    respond((request) => request.uri.path.endsWith('getDanmuInfo')
        ? {'data': {'host_list': <dynamic>[], 'token': 'token'}} : null);
    final room = await _Bili(status: 1).getRoomDetail(roomId: '1');
    expect(room.status, isTrue);
    expect(room.danmakuData, isA<BiliBiliDanmakuArgs>());
    expect(paths, ['/xlive/web-room/v1/index/getDanmuInfo']);
  });

  test('缺失状态不能当作下播', () async {
    respond((_) => null);
    await expectLater(_Bili(status: null).getRoomDetail(roomId: '1'), throwsStateError);
  });

  test('斗鱼录像轮播不能被下播短路', () async {
    respond((request) => request.uri.path == '/betard/1'
        ? {'room': {'room_id': 1, 'show_status': 2, 'videoLoop': 1}} : null);
    // No real signature/native runtime needed: reaching H5 proves the replay
    // continues through the existing playback preparation path.
    await expectLater(DouyuSite().getRoomDetail(roomId: '1'), throwsA(anything));
    // 三个请求同时发出，加密串请求可能稍晚一拍才被拦截器记录。
    await Future<void>.delayed(Duration.zero);
    expect(
      paths,
      containsAll(['/betard/1', '/swf_api/h5room/1', '/swf_api/homeH5Enc']),
    );
  });

  test('抖音网页明确下播，anchor 缺失时仍使用 owner', () async {
    final state = {'state': {'roomStore': {'roomInfo': {'room': {
      'id_str': '123', 'status': 4, 'owner': {'nickname': '主播'},
    }}}}};
    respond((request) {
      if (request.uri.path == '/webcast/room/web/enter/') return null;
      if (request.method == 'HEAD') return '';
      return '<script>self.__next_f.push([1,${jsonEncode('7:${jsonEncode(state)}\n')}])</script>';
    });
    final room = await DouyinSite().getRoomDetailByWebRid('123');
    expect(room.status, isFalse);
    expect(room.userName, '主播');
    expect(room.danmakuData, isNull);
    // A connection error gets one safe read retry before the existing web fallback.
    expect(paths, ['/webcast/room/web/enter/', '/webcast/room/web/enter/', '/123', '/123']);
  });

  test('斗鱼已下播不再读取开播时间或执行播放签名', () async {
    respond(
      (request) => request.uri.path == '/betard/1'
          ? {
              'room': {
                'room_id': 1,
                'room_name': '上次直播',
                'owner_name': '主播',
                'owner_avatar': '',
                'show_status': 2,
                'videoLoop': 0,
              },
            }
          : null,
    );
    final room = await DouyuSite().getRoomDetail(roomId: '1');
    expect(room.status, isFalse);
    expect(room.isRecord, isFalse);
    expect(room.userName, '主播');
    expect(paths, ['/betard/1']);
    expect(room.data, isNull);
  });

  test('虎牙下播后缺少流字段也正常返回，不解析失效流', () async {
    respond(
      (_) =>
          '<script>window.HNF_GLOBAL_INIT = ${jsonEncode({
            'roomInfo': {
              'eLiveStatus': 1,
              'tLiveInfo': {'lProfileRoom': 1},
              'tProfileInfo': {'sNick': '主播', 'sAvatar180': ''},
            },
            'roomProfile': <String, dynamic>{},
          })}</script>',
    );
    final room = await HuyaSite().getRoomDetail(roomId: '1');
    expect(room.status, isFalse);
    expect(room.userName, '主播');
    expect(room.data, isNull);
    // 先尝试 JSON 接口（拿到的是 HTML，解析失败），再回退页面解析。
    expect(paths, ['/cache.php', '/1']);
  });

  test('抖音明确下播且仅保留 owner 时不进入网页兜底和重试', () async {
    respond(
      (request) => request.uri.path == '/webcast/room/web/enter/'
          ? {
              'data': {
                'data': [
                  {
                    'status': 4,
                    'id_str': '123',
                    'title': '上次直播',
                    'owner': {
                      'nickname': '主播',
                      'avatar_thumb': {
                        'url_list': ['avatar'],
                      },
                    },
                  },
                ],
              },
            }
          : null,
    );
    final room = await DouyinSite().getRoomDetail(roomId: '123');
    expect(room.status, isFalse);
    expect(room.userName, '主播');
    expect(paths, ['/webcast/room/web/enter/']);
    expect(room.danmakuData, isNull);
  });
}
