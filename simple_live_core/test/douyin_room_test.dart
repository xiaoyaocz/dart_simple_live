import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/core_error.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;
import 'package:test/test.dart';

Map<String, dynamic> roomResponse({bool living = true}) {
  final owner = {
    'nickname': '测试主播',
    'signature': '简介',
    'avatar_thumb': {
      'url_list': ['https://example.com/avatar.jpg'],
    },
  };
  return {
    'status_code': 0,
    'data': {
      'user': owner,
      'data': [
        {
          'id_str': '1234567890123456789',
          'status': living ? 2 : 4,
          'title': '测试直播',
          'owner': owner,
          'cover': {
            'url_list': ['https://example.com/cover.jpg'],
          },
          'room_view_stats': {'display_value': 42},
          'stream_url': {
            'live_core_sdk_data': {
              'pull_data': {
                'options': {
                  'qualities': [
                    {'name': '原画', 'sdk_key': 'origin', 'level': 1},
                  ],
                },
                'stream_data': jsonEncode({
                  'data': {
                    'origin': {
                      'main': {
                        'flv': 'https://example.com/live.flv',
                        'hls': 'https://example.com/live.m3u8',
                      },
                    },
                  },
                }),
              },
            },
          },
        },
      ],
    },
  };
}

void main() {
  setUp(() => CoreLog.enableLog = false);

  test('原画标称 720p 时仍按平台档位排列并使用对应直播流', () async {
    Map<String, Object?> route(String name, String resolution) => {
      'main': {
        'flv': 'https://example.com/$name.flv',
        'sdk_params': jsonEncode({'resolution': resolution}),
      },
    };
    final detail = LiveRoomDetail(
      roomId: '1', title: '', cover: '', userName: '', userAvatar: '',
      online: 0, status: true, url: '', data: {
        'live_core_sdk_data': {'pull_data': {
          'options': {'qualities': [
            {'name': '原画', 'sdk_key': 'origin', 'level': 5},
            {'name': '蓝光', 'sdk_key': 'uhd', 'level': 4},
          ]},
          'stream_data': jsonEncode({'data': {
            'origin': route('origin', '1280x720'),
            'uhd': route('uhd', '1920x1080'),
          }}),
        }},
      },
    );
    final site = DouyinSite();
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((item) => item.quality), ['原画', '蓝光']);
    expect((await site.getPlayUrls(detail: detail, quality: qualities.first)).urls,
        ['https://example.com/origin.flv']);
    expect((await site.getPlayUrls(detail: detail, quality: qualities.last)).urls,
        ['https://example.com/uhd.flv']);
  });

  for (final hasSharperStream in [true, false]) {
    test('原画复用超清地址时按真实档位播放（有更清晰流=$hasSharperStream）', () async {
      Map<String, Object?> stream(String name, String size) => {
        for (final route in ['main', 'backup'])
          route: {
            'flv': 'https://$route.test/$name.flv',
            'hls': 'https://$route.test/$name.m3u8',
            'sdk_params': jsonEncode({'resolution': size, 'fps': 60}),
          },
      };
      final hd = stream('hd', '1280x720');
      final detail = LiveRoomDetail(
        roomId: '1',
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: true,
        url: '',
        data: {
          'live_core_sdk_data': {
            'pull_data': {
              'options': {
                'qualities': [
                  {'name': '原画', 'sdk_key': 'origin', 'level': 5},
                  if (hasSharperStream)
                    {'name': '蓝光', 'sdk_key': 'uhd', 'level': 4},
                  {'name': '超清', 'sdk_key': 'hd', 'level': 3},
                ],
              },
              'stream_data': jsonEncode({
                'data': {
                  'origin': hd,
                  'hd': hd,
                  if (hasSharperStream) 'uhd': stream('uhd', '1920x1080'),
                },
              }),
            },
          },
        },
      );
      final site = DouyinSite();
      final qualities = await site.getPlayQualites(detail: detail);
      expect(qualities.first.quality, '原画');
      final result = await site.getPlayUrls(
        detail: detail,
        quality: qualities.first,
      );
      final selected = hasSharperStream ? 'uhd' : 'hd';
      expect(result.actualQuality, hasSharperStream ? '蓝光' : '超清');
      expect(result.urls, [
        'https://main.test/$selected.flv',
        'https://backup.test/$selected.flv',
        'https://main.test/$selected.m3u8',
        'https://backup.test/$selected.m3u8',
      ]);
    });
  }

  void intercept(void Function(RequestOptions, RequestInterceptorHandler) run) {
    final interceptor = InterceptorsWrapper(onRequest: run);
    core.HttpClient.instance.dio.interceptors.add(interceptor);
    addTearDown(
      () => core.HttpClient.instance.dio.interceptors.remove(interceptor),
    );
  }

  void reject(
    RequestOptions request,
    RequestInterceptorHandler handler,
    int code,
  ) {
    handler.reject(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: request, statusCode: code),
      ),
    );
  }

  for (final emptyResponse in [false, true]) {
    test('${emptyResponse ? '空响应' : '444'}后刷新访客会话并恢复房间和播放地址', () async {
      var roomRequests = 0;
      var visitorRequests = 0;
      final site = DouyinSite()..cookie = 'ttwid=expired; sessionid=用户配置';
      intercept((request, handler) {
        if (request.method == 'HEAD' && request.uri.path == '/') {
          visitorRequests++;
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 404,
              headers: Headers.fromMap({
                'set-cookie': [
                  'ttwid=fresh; Path=/; HttpOnly',
                  'unrelated=ignore; Path=/',
                ],
              }),
            ),
          );
          return;
        }
        if (request.uri.path == '/webcast/room/web/enter/') {
          roomRequests++;
          if (roomRequests == 1) {
            if (emptyResponse) {
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: ''),
              );
            } else {
              reject(request, handler, 444);
            }
            return;
          }
          expect(request.headers['cookie'], contains('ttwid=fresh'));
          expect(request.headers['cookie'], contains('sessionid=用户配置'));
          expect(request.headers['cookie'], isNot(contains('ttwid=expired')));
          if (roomRequests == 2) {
            expect(request.uri.queryParameters, isNot(contains('a_bogus')));
          }
          handler.resolve(
            Response(requestOptions: request, data: roomResponse()),
          );
          return;
        }
        reject(request, handler, 444);
      });

      final detail = await site.getRoomDetailByWebRid('610094830592');
      expect(detail.status, isTrue);
      expect(detail.roomId, '610094830592');
      expect(detail.userName, '测试主播');
      final qualities = await site.getPlayQualites(detail: detail);
      final urls = await site.getPlayUrls(
        detail: detail,
        quality: qualities.single,
      );
      expect(urls.urls, [
        'https://example.com/live.flv',
        'https://example.com/live.m3u8',
      ]);
      expect(visitorRequests, 1);
      expect(roomRequests, 2);
      expect(site.cookie, 'ttwid=expired; sessionid=用户配置');
      expect(
        (detail.danmakuData as DouyinDanmakuArgs).cookie,
        contains('ttwid=fresh'),
      );
      expect(await site.getLiveStatus(roomId: '610094830592'), isTrue);
      expect(visitorRequests, 1);
      site.cookie = 'ttwid=changed';
      expect((await site.getRequestHeaders())['cookie'], 'ttwid=changed');
    });
  }

  test('正常返回未开播房间时不获取访客会话、不多次请求', () async {
    var requests = 0;
    intercept((request, handler) {
      requests++;
      expect(request.uri.path, '/webcast/room/web/enter/');
      expect(request.uri.queryParametersAll['msToken'], hasLength(1));
      handler.resolve(
        Response(requestOptions: request, data: roomResponse(living: false)),
      );
    });
    final detail = await DouyinSite().getRoomDetailByWebRid('610094830592');
    expect(detail.status, isFalse);
    expect(detail.userName, '测试主播');
    expect(requests, 1);
  });

  test('并发加载房间时共享访客会话请求，保留各自 Referer', () async {
    final release = Completer<void>();
    var visitorRequests = 0;
    var rejected = 0;
    intercept((request, handler) async {
      if (request.method == 'HEAD' && request.uri.path == '/') {
        visitorRequests++;
        await release.future;
        handler.resolve(
          Response(
            requestOptions: request,
            headers: Headers.fromMap({
              'set-cookie': ['ttwid=fresh; Path=/'],
            }),
          ),
        );
      } else if (request.uri.path == '/webcast/room/web/enter/') {
        if (!request.headers['cookie'].toString().contains('ttwid=fresh')) {
          if (++rejected == 2) release.complete();
          reject(request, handler, 444);
        } else {
          expect(
            request.headers['Referer'],
            'https://live.douyin.com/${request.uri.queryParameters['web_rid']}',
          );
          handler.resolve(
            Response(requestOptions: request, data: roomResponse()),
          );
        }
      } else {
        reject(request, handler, 444);
      }
    });
    final site = DouyinSite();
    final rooms = await Future.wait([
      site.getRoomDetailByWebRid('610094830592'),
      site.getRoomDetailByWebRid('610094830593'),
    ]);
    expect(rooms.map((room) => room.roomId), ['610094830592', '610094830593']);
    expect(visitorRequests, 1);
  });

  test('备用请求被拒绝后使用新会话重新签名，成功后停止请求', () async {
    var apiRequests = 0;
    var visitorRequests = 0;
    String? initialSignature;
    intercept((request, handler) {
      if (request.method == 'HEAD' && request.uri.path == '/') {
        visitorRequests++;
        handler.resolve(
          Response(
            requestOptions: request,
            headers: Headers.fromMap({
              'set-cookie': ['ttwid=fresh; Path=/; HttpOnly'],
            }),
          ),
        );
        return;
      }
      if (request.uri.path != '/webcast/room/web/enter/') {
        reject(request, handler, 444);
        return;
      }
      apiRequests++;
      if (apiRequests == 1) {
        initialSignature = request.uri.queryParameters['a_bogus'];
        reject(request, handler, 444);
      } else if (apiRequests == 2) {
        expect(request.uri.queryParameters, isNot(contains('a_bogus')));
        reject(request, handler, 444);
      } else {
        expect(request.headers['cookie'], contains('ttwid=fresh'));
        expect(request.headers['cookie'], contains('sessionid=account'));
        expect(
          request.headers['Referer'],
          'https://live.douyin.com/141601416352',
        );
        expect(request.uri.queryParameters['web_rid'], '141601416352');
        expect(request.uri.queryParameters['a_bogus'], isNotEmpty);
        expect(request.uri.queryParameters['a_bogus'], isNot(initialSignature));
        expect(request.uri.queryParametersAll['msToken'], hasLength(1));
        handler.resolve(
          Response(requestOptions: request, data: roomResponse()),
        );
      }
    });
    final site = DouyinSite()..cookie = 'ttwid=expired; sessionid=account';
    final detail = await site.getRoomDetailByWebRid('141601416352');
    expect(detail.status, isTrue);
    expect(detail.roomId, '141601416352');
    expect(
      (detail.danmakuData as DouyinDanmakuArgs).cookie,
      contains('ttwid=fresh'),
    );
    expect(site.cookie, 'ttwid=expired; sessionid=account');
    expect(apiRequests, 3);
    expect(visitorRequests, 1);
  });

  test('备用请求返回 403 时不继续签名重试', () async {
    var apiRequests = 0;
    intercept((request, handler) {
      if (request.method == 'HEAD' && request.uri.path == '/') {
        handler.resolve(Response(requestOptions: request));
      } else if (request.uri.path == '/webcast/room/web/enter/') {
        apiRequests++;
        reject(request, handler, apiRequests == 1 ? 444 : 403);
      } else {
        reject(request, handler, 403);
      }
    });
    await expectLater(
      DouyinSite().getRoomDetail(roomId: '141601416352'),
      throwsA(isA<CoreError>().having((error) => error.statusCode, '错误码', 403)),
    );
    expect(apiRequests, 2);
  });

  test('持续被拒绝时有限次请求后保留错误', () async {
    var requests = 0;
    var apiRequests = 0;
    intercept((request, handler) {
      requests++;
      if (request.uri.path == '/webcast/room/web/enter/') apiRequests++;
      reject(request, handler, 444);
    });
    await expectLater(
      DouyinSite().getRoomDetailByWebRid('610094830592'),
      throwsA(isA<CoreError>().having((error) => error.statusCode, '错误码', 444)),
    );
    expect(requests, lessThanOrEqualTo(6));
    expect(apiRequests, 3);
  });

  test('访客刷新未发放 Cookie 时仍尝试备用请求，不删除用户配置', () async {
    var roomRequests = 0;
    intercept((request, handler) {
      if (request.method == 'HEAD' && request.uri.path == '/') {
        handler.resolve(Response(requestOptions: request, statusCode: 404));
      } else if (++roomRequests == 1) {
        reject(request, handler, 444);
      } else {
        expect(request.uri.queryParameters, isNot(contains('a_bogus')));
        expect(request.headers['cookie'], 'ttwid=configured');
        handler.resolve(
          Response(requestOptions: request, data: roomResponse()),
        );
      }
    });
    final site = DouyinSite()..cookie = 'ttwid=configured';
    expect((await site.getRoomDetailByWebRid('610094830592')).status, isTrue);
    expect(roomRequests, 2);
    expect(site.cookie, 'ttwid=configured');
  });

  test('HTTP 403 沿用原有错误处理，不误触发访客刷新', () async {
    var apiRequests = 0;
    var visitorRequests = 0;
    intercept((request, handler) {
      if (request.uri.path == '/webcast/room/web/enter/') apiRequests++;
      if (request.uri.path == '/') visitorRequests++;
      reject(request, handler, 403);
    });
    await expectLater(
      DouyinSite().getRoomDetailByWebRid('610094830592'),
      throwsA(isA<CoreError>().having((error) => error.statusCode, '错误码', 403)),
    );
    expect(apiRequests, 1);
    expect(visitorRequests, 0);
  });
}
