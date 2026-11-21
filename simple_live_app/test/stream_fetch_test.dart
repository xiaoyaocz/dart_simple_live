import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;

class _Bili extends BiliBiliSite {
  @override
  Future<Map<String, String>> getHeader() async => {};
}

class _Huya extends HuyaSite {
  int tokenCalls = 0;
  bool tokenFails = false;
  @override
  Future<String> getCndTokenInfoEx(String stream) async {
    tokenCalls++;
    if (tokenFails) throw StateError('鉴权接口不可用');
    return 'wsSecret=备用';
  }
}

class _Douyu extends DouyuSite {
  @override
  Future<String> getPlayUrl(
      String roomId, String args, int rate, String cdn) async {
    if (cdn == '失败') throw StateError('线路失败');
    return 'https://example.com/live.flv';
  }
}

class _SlowDouyu extends DouyuSite {
  final started = <String>[];
  final release = Completer<void>();

  @override
  Future<String> getPlayUrl(
      String roomId, String args, int rate, String cdn) async {
    started.add(cdn);
    await release.future;
    return 'https://example.com/$cdn.flv';
  }
}

LiveRoomDetail _detail({Object data = ''}) => LiveRoomDetail(
      roomId: '1',
      title: '',
      cover: '',
      userName: '',
      userAvatar: '',
      online: 0,
      status: true,
      url: '',
      data: data,
    );

HuyaLineModel _line({String anti = 'wsSecret=页面', bool hls = false}) =>
    HuyaLineModel(
      line: 'https://example.com',
      streamName: 'live',
      cdnType: '',
      flvAntiCode: anti,
      hlsAntiCode: anti,
      presenterUid: 1,
      lineType: hls ? HuyaLineType.hls : HuyaLineType.flv,
    );

void main() {
  test('B站普通线路保持原顺序，mcdn 排后并去重', () async {
    final dio = core.HttpClient.instance.dio;
    final interceptor = InterceptorsWrapper(onRequest: (request, handler) {
      handler.resolve(Response(requestOptions: request, data: {
        'data': {
          'playurl_info': {
            'playurl': {
              'stream': [
                {
                  'format': [
                    {
                      'codec': [
                        {
                          'base_url': '/live.flv',
                          'url_info': [
                            {'host': 'https://mcdn.example.com', 'extra': ''},
                            {'host': 'https://first.example.com', 'extra': ''},
                            {'host': 'https://second.example.com', 'extra': ''},
                            {'host': 'https://first.example.com', 'extra': ''},
                          ],
                        }
                      ]
                    }
                  ]
                },
              ]
            }
          }
        },
      }));
    });
    dio.interceptors.add(interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));
    final urls = await _Bili().getPlayUrls(
      detail: _detail(),
      quality: LivePlayQuality(quality: '', data: 10000),
    );
    expect(urls.urls, [
      'https://first.example.com/live.flv',
      'https://second.example.com/live.flv',
      'https://mcdn.example.com/live.flv',
    ]);
  });
  test('B站优先 AVC 并保留 HEVC 备用流', () async {
    final dio = core.HttpClient.instance.dio;
    final interceptor = InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.queryParameters['codec'], '0,1');
      handler.resolve(Response(requestOptions: request, data: {
        'data': {'playurl_info': {'playurl': {'stream': [
          {'format': [
            {'codec': [
              {'codec_name': 'hevc', 'base_url': '/hevc.flv', 'url_info': [
                {'host': 'https://hevc.example.com', 'extra': ''}
              ]},
              {'codec_name': 'avc', 'base_url': '/avc.flv', 'url_info': [
                {'host': 'https://avc.example.com', 'extra': ''}
              ]},
            ]}
          ]}
        ]}}}
      }));
    });
    dio.interceptors.add(interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));
    final urls = await _Bili().getPlayUrls(
      detail: _detail(),
      quality: LivePlayQuality(quality: '', data: 10000),
    );
    expect(urls.urls, [
      'https://avc.example.com/avc.flv',
      'https://hevc.example.com/hevc.flv',
    ]);
  });
  test('斗鱼空数据及非法地址不会变成播放链接', () async {
    final dio = core.HttpClient.instance.dio;
    dynamic responseData;
    final interceptor = InterceptorsWrapper(onRequest: (request, handler) {
      handler.resolve(Response(requestOptions: request, data: responseData));
    });
    dio.interceptors.add(interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));
    for (final data in [
      null,
      {},
      {'rtmp_url': 'null', 'rtmp_live': 'null'}
    ]) {
      responseData = {'error': 1, 'data': data};
      expect(await DouyuSite().getPlayUrl('1', '', 0, ''), isEmpty);
    }
  });
  test('虎牙 FLV 优先使用原生鉴权并保留清晰度', () async {
    final site = _Huya();
    final url = await site.getPlayUrl(_line(), 2000);
    expect(url, contains('.flv?wsSecret=备用'));
    expect(url, contains('&ratio=2000'));
    expect(site.tokenCalls, 1);
  });
  test('虎牙原生鉴权失败回退页面鉴权', () async {
    final site = _Huya()..tokenFails = true;
    expect(await site.getPlayUrl(_line(), 0), contains('wsSecret=页面'));
  });
  test('虎牙同一流多线路共享当次原生鉴权请求', () async {
    final site = _Huya();
    await site.getPlayUrls(
        detail: _detail(),
        quality: LivePlayQuality(quality: '', data: {
          'urls': [_line(), _line(), _line()],
          'bitRate': 0,
        }));
    expect(site.tokenCalls, 1);
  });
  test('虎牙页面鉴权缺失才请求备用接口', () async {
    final site = _Huya();
    expect(await site.getPlayUrl(_line(anti: ''), 0), contains('备用'));
    expect(site.tokenCalls, 1);
  });
  test('虎牙 HLS 使用正确扩展名', () async {
    expect(await _Huya().getPlayUrl(_line(hls: true), 0), contains('.m3u8?'));
  });
  test('虎牙 HLS 不复用 FLV 原生令牌', () async {
    final site = _Huya();
    await expectLater(
        site.getPlayUrl(_line(hls: true, anti: ''), 0), throwsStateError);
    expect(site.tokenCalls, 0);
  });
  test('虎牙原生签名缺少 t 时使用原生平台参数 100', () {
    final anti = Uri(queryParameters: {
      'fm': base64Encode(utf8.encode('prefix_0_stream_hash_time')),
      'wsTime': 'ffffffff',
      'fs': '1',
      'ctype': 'huya_pc_exe',
    }).query;
    final signed = HuyaSite().buildAntiCode('live', 123, anti);
    expect(Uri(query: signed).queryParameters['t'], '100');
  });
  test('虎牙保留所有 FLV 主线路并追加有效 HLS 备用线路', () async {
    final dio = core.HttpClient.instance.dio;
    final fixture = {
      'roomInfo': {
        'eLiveStatus': 2,
        'tProfileInfo': {'sNick': '测试主播', 'sAvatar180': ''},
        'tLiveInfo': {
          'lTotalCount': 1,
          'lProfileRoom': 1,
          'tLiveStreamInfo': {
            'vStreamInfo': {
              'value': [
                {
                  'sFlvUrl': 'https://first.example.com',
                  'sHlsUrl': 'https://hls.example.com',
                  'sFlvAntiCode': 'wsSecret=flv',
                  'sHlsAntiCode': 'wsSecret=hls',
                  'sStreamName': 'first',
                  'sCdnType': 'AL',
                  'lPresenterUid': 123
                },
                {
                  'sFlvUrl': 'https://second.example.com',
                  'sHlsUrl': 'https://empty.example.com',
                  'sFlvAntiCode': 'wsSecret=flv',
                  'sHlsAntiCode': '',
                  'sStreamName': 'second',
                  'sCdnType': 'TX',
                  'lPresenterUid': 456
                },
              ]
            },
            'vBitRateInfo': {
              'value': [
                {'iBitRate': 0, 'sDisplayName': '原画'}
              ]
            },
          },
        },
      },
      'roomProfile': {
        'liveLineUrl': base64Encode(utf8.encode('//example.com/live.flv'))
      },
    };
    final interceptor = InterceptorsWrapper(onRequest: (request, handler) {
      handler.resolve(Response(
          requestOptions: request,
          data: 'window.HNF_GLOBAL_INIT = ${jsonEncode(fixture)}</script>'));
    });
    dio.interceptors.add(interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));
    final site = _Huya();
    final detail = await site.getRoomDetail(roomId: '1');
    final qualities = await site.getPlayQualites(detail: detail);
    final urls =
        await site.getPlayUrls(detail: detail, quality: qualities.first);
    expect(urls.urls.map((url) => Uri.parse(url).path),
        ['/first.flv', '/second.flv', '/first.m3u8']);
    expect((detail.data as HuyaUrlDataModel).lines.first.presenterUid, 123);
    expect(site.tokenCalls, 2);
  });
  test('虎牙损坏线路不影响可用线路并去重', () async {
    final urls = await (_Huya()..tokenFails = true).getPlayUrls(
      detail: _detail(),
      quality: LivePlayQuality(quality: '', data: {
        'urls': [_line(anti: 'fm=损坏'), _line(), _line()],
        'bitRate': 0,
      }),
    );
    expect(urls.urls, hasLength(1));
  });
  test('斗鱼单线路失败仍保留其他线路并去重', () async {
    final urls = await _Douyu().getPlayUrls(
      detail: _detail(),
      quality: LivePlayQuality(
          quality: '', data: DouyuPlayData(0, ['失败', '线路一', '线路二'])),
    );
    expect(urls.urls, ['https://example.com/live.flv']);
  });
  test('斗鱼备用线路同时请求且结果保持原顺序', () async {
    final site = _SlowDouyu();
    final pending = site.getPlayUrls(
      detail: _detail(),
      quality: LivePlayQuality(
          quality: '原画', data: DouyuPlayData(0, ['线路一', '线路二'])),
    );
    await Future<void>.delayed(Duration.zero);
    expect(site.started, ['线路一', '线路二']);
    site.release.complete();
    final urls = await pending;
    expect(urls.urls, [
      'https://example.com/线路一.flv',
      'https://example.com/线路二.flv'
    ]);
  });
  test('抖音优先同画质备用 FLV，过滤无效和重复线路', () async {
    final site = DouyinSite();
    final detail = _detail(data: {
      'live_core_sdk_data': {
        'pull_data': {
          'options': {
            'qualities': [
              {'name': '原画', 'level': 2, 'sdk_key': 'origin'},
              {'name': '高清', 'level': 1, 'sdk_key': 'hd'},
            ],
          },
          'stream_data': jsonEncode({
            'data': {
              'origin': {
                'main': {
                  'flv': 'https://first/live.flv',
                  'hls': 'https://first/live.m3u8',
                },
                'backup': {
                  'flv': 'https://spare/live.flv',
                  'hls': 'https://first/live.m3u8',
                },
              },
              'hd': {
                'main': {'flv': 'file:///invalid'},
                'backup': {'hls': 'https://spare/hd.m3u8'},
              },
            },
          }),
        },
      },
    });
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((q) => q.quality), ['原画', '高清']);
    expect(
      (await site.getPlayUrls(detail: detail, quality: qualities.first)).urls,
      ['https://first/live.flv', 'https://spare/live.flv', 'https://first/live.m3u8'],
    );
    expect(
      (await site.getPlayUrls(detail: detail, quality: qualities.last)).urls,
      ['https://spare/hd.m3u8'],
    );
  });
  test('抖音读取地址不会修改画质原数据', () async {
    final original = [
      'https://example.com/live.flv',
      'https://example.com/live.m3u8'
    ];
    final urls = await DouyinSite().getPlayUrls(
      detail: _detail(),
      quality: LivePlayQuality(quality: '', data: original),
    );
    urls.urls.clear();
    expect(original, hasLength(2));
  });
}
