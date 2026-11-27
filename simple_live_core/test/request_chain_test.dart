import 'dart:async';
import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;
import 'package:test/test.dart';

class _Bili extends BiliBiliSite {
  int calls = 0;
  final gate = Completer<void>();
  @override
  Future<Map<String, dynamic>> getRoomInfo({required String roomId}) async {
    calls++;
    await gate.future;
    return {
      'room_info': {'room_id': roomId, 'live_status': 0},
    };
  }

  @override
  Future<Map<String, String>> getHeader() async => {};
}

LiveRoomDetail room() => LiveRoomDetail(
  roomId: '1',
  title: '',
  cover: '',
  userName: '',
  userAvatar: '',
  online: 0,
  status: true,
  url: '',
);
Map<String, dynamic> playInfo(String token) => {
  'data': {
    'playurl_info': {
      'playurl': {
        'g_qn_desc': [
          {'qn': 80, 'desc': '高清'},
        ],
        'stream': [
          {
            'format': [
              {
                'codec': [
                  {
                    'codec_name': 'avc',
                    'current_qn': 80,
                    'accept_qn': [80],
                    'base_url': '/live.flv',
                    'url_info': [
                      {'host': 'https://cdn.test', 'extra': '?token=$token'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  },
};
void main() {
  test('Bili explicit refresh bypasses in-flight room detail coalescing', () async {
    final site = _Bili();
    final old = site.getRoomDetail(roomId: '1');
    final fresh = site.refreshRoomDetail(roomId: '1');
    expect(site.calls, 2);
    site.gate.complete();
    await Future.wait([old, fresh]);
  });
  late Dio original;
  setUp(() {
    CoreLog.enableLog = false;
    original = core.HttpClient.instance.dio;
    core.HttpClient.instance.dio = Dio();
  });
  tearDown(() {
    core.HttpClient.instance.dio.close();
    core.HttpClient.instance.dio = original;
  });
  test('Bili prefetch and cached playback URLs are isolated by account', () async {
    final site = _Bili()..cookie = 'account-a';
    var calls = 0;
    core.HttpClient.instance.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (request, handler) {
        calls++;
        handler.resolve(Response(requestOptions: request, data: playInfo(site.cookie)));
      },
    ));
    site.prefetchRoom('1');
    await Future<void>.delayed(Duration.zero);
    site.cookie = 'account-b';
    final qualities = await site.getPlayQualites(detail: room());
    final selected = await site.getPlayUrls(detail: room(), quality: qualities.first);
    expect(selected.urls.first, contains('account-b'));
    expect(calls, 2);
    site.cookie = 'account-c';
    await site.getPlayQualites(detail: room());
    site.cookie = 'account-d';
    final changed = await site.getPlayUrls(detail: room(), quality: qualities.first);
    expect(changed.urls.first, contains('account-d'));
    expect(calls, 4);
  });
  test('Bili account change never joins previous account pending room details', () async {
    final site = _Bili()..cookie = 'account-a';
    final first = site.getRoomDetail(roomId: '1');
    site.cookie = 'account-b';
    final second = site.getRoomDetail(roomId: '1');
    expect(site.calls, 2);
    site.gate.complete();
    await Future.wait([first, second]);
  });
  test(
    'Bili concurrent details share one request but later refresh reloads',
    () async {
      final site = _Bili();
      final first = site.getRoomDetail(roomId: '1');
      final second = site.getRoomDetail(roomId: '1');
      site.gate.complete();
      await Future.wait([first, second]);
      expect(site.calls, 1);
      await site.getRoomDetail(roomId: '1');
      expect(site.calls, 2);
    },
  );
  test('Bili concurrent quality consumers share prefetched request', () async {
    var calls = 0;
    final gate = Completer<void>();
    core.HttpClient.instance.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          calls++;
          await gate.future;
          handler.resolve(
            Response(requestOptions: request, data: playInfo('initial')),
          );
        },
      ),
    );
    final site = _Bili();
    site.prefetchRoom('1');
    final first = site.getPlayQualites(detail: room());
    final second = site.getPlayQualites(detail: room());
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
  });
  test('Bili lines keep the requested quality when another codec returns a lower one', () async {
    final info = playInfo('low');
    final codecs = info['data']['playurl_info']['playurl']['stream'][0]
        ['format'][0]['codec'] as List;
    codecs.first['accept_qn'] = [10000, 80];
    codecs.add({
      'codec_name': 'hevc',
      'current_qn': 10000,
      'accept_qn': [10000, 80],
      'base_url': '/original.flv',
      'url_info': [
        {'host': 'https://primary.test', 'extra': ''},
        {'host': 'https://backup.test', 'extra': ''},
      ],
    });
    core.HttpClient.instance.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (request, handler) =>
          handler.resolve(Response(requestOptions: request, data: info)),
    ));
    final site = _Bili();
    final detail = room();
    final qualities = await site.getPlayQualites(detail: detail);
    final original = await site.getPlayUrls(detail: detail, quality: qualities.first);
    final low = await site.getPlayUrls(detail: detail, quality: qualities.last);
    expect(original.urls, [
      'https://primary.test/original.flv',
      'https://backup.test/original.flv',
    ]);
    expect(low.urls, ['https://cdn.test/live.flv?token=low']);
  });
  test(
    'Bili playback handoff is consumed once so recovery gets a fresh URL',
    () async {
      var calls = 0;
      core.HttpClient.instance.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls++;
            handler.resolve(
              Response(requestOptions: request, data: playInfo('$calls')),
            );
          },
        ),
      );
      final site = _Bili();
      final detail = room();
      final qualities = await site.getPlayQualites(detail: detail);
      final first = await site.getPlayUrls(
        detail: detail,
        quality: qualities.first,
      );
      final retry = await site.getPlayUrls(
        detail: detail,
        quality: qualities.first,
      );
      expect(first.urls.single, endsWith('token=1'));
      expect(retry.urls.single, endsWith('token=2'));
      expect(calls, 2);
    },
  );
  test('Bili fallback reports the highest delivered tier and keeps its lines together', () async {
    final info = playInfo('low');
    final playurl = info['data']['playurl_info']['playurl'];
    playurl['g_qn_desc'].add({'qn': 250, 'desc': '超清'});
    playurl['stream'][0]['format'][0]['codec'].add({
      'codec_name': 'hevc',
      'current_qn': 250,
      'base_url': '/hd.flv',
      'url_info': [
        {'host': 'https://primary.test', 'extra': ''},
        {'host': 'https://backup.test', 'extra': ''},
      ],
    });
    core.HttpClient.instance.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (request, handler) =>
          handler.resolve(Response(requestOptions: request, data: info)),
    ));
    final urls = await _Bili().getPlayUrls(
      detail: room(),
      quality: LivePlayQuality(quality: '原画', data: 10000),
    );
    expect(urls.urls, [
      'https://primary.test/hd.flv',
      'https://backup.test/hd.flv',
    ]);
    expect(urls.actualQuality, '超清');
  });
  test('Bili merges accept_qn across all protocols, formats, and codecs sorted highest first', () async {
    Uri? seenUri;
    final info = {
      'data': {
        'playurl_info': {
          'playurl': {
            'g_qn_desc': [
              {'qn': 30000, 'desc': '杜比'},
              {'qn': 20000, 'desc': '4K'},
              {'qn': 10000, 'desc': '原画'},
              {'qn': 250, 'desc': '超清'},
            ],
            'stream': [
              {
                'protocol_name': 'http_stream',
                'format': [
                  {
                    'format_name': 'flv',
                    'codec': [
                      {
                        'codec_name': 'avc',
                        'current_qn': 10000,
                        'accept_qn': [10000, 250],
                        'base_url': '/flv_10000.flv',
                        'url_info': [
                          {'host': 'https://flv.test', 'extra': ''},
                        ],
                      },
                    ],
                  },
                ],
              },
              {
                'protocol_name': 'http_hls',
                'format': [
                  {
                    'format_name': 'fmp4',
                    'codec': [
                      {
                        'codec_name': 'hevc',
                        'current_qn': 30000,
                        'accept_qn': [30000, 20000, 10000, 250],
                        'base_url': '/hls_30000.m3u8',
                        'url_info': [
                          {'host': 'https://hls.test', 'extra': ''},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
    };
    var calls = 0;
    core.HttpClient.instance.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (request, handler) {
        calls++;
        seenUri = request.uri;
        handler.resolve(Response(requestOptions: request, data: info));
      },
    ));
    final site = _Bili();
    final detail = room();
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((q) => q.data).toList(), [30000, 20000, 10000, 250]);
    expect(qualities.first.quality, '杜比');
    expect(seenUri?.queryParameters['dolby'], '5');
    expect(seenUri?.queryParameters['panorama'], '1');
    // Cached highest delivered qn (30000 on http_hls/hevc) is reused without an extra request.
    final top = await site.getPlayUrls(detail: detail, quality: qualities.first);
    expect(top.urls, ['https://hls.test/hls_30000.m3u8']);
    expect(top.actualQuality, '杜比');
    expect(calls, 1);
  });
  for (final entry in <String, LiveSite>{
    'douyu': DouyuSite(),
    'huya': HuyaSite(),
    'douyin': DouyinSite(),
  }.entries) {
    test(
      '${entry.key} concurrent details deduplicate but sequential refresh reloads',
      () async {
        var calls = 0;
        final gate = Completer<void>();
        core.HttpClient.instance.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) async {
              calls++;
              await gate.future;
              final data = switch (entry.key) {
                'douyu' => {
                  'room': {'room_id': 1, 'show_status': 2, 'videoLoop': 0},
                },
                'huya' => {
                  'data': {'liveStatus': 'OFF'},
                },
                _ => {
                  'data': {
                    'data': [
                      {
                        'status': 4,
                        'id_str': '1',
                        'owner': {'nickname': '主播'},
                      },
                    ],
                  },
                },
              };
              handler.resolve(Response(requestOptions: request, data: data));
            },
          ),
        );
        final first = entry.value.getRoomDetail(roomId: '1');
        final second = entry.value.getRoomDetail(roomId: '1');
        gate.complete();
        final details = await Future.wait([first, second]);
        expect(details.every((room) => !room.status), isTrue);
        expect(calls, 1);
        await entry.value.getRoomDetail(roomId: '1');
        expect(calls, 2);
      },
    );
  }
  test('Bili concurrent direct URL loads coalesce and retry reloads', () async {
    var calls = 0;
    final gate = Completer<void>();
    core.HttpClient.instance.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          calls++;
          await gate.future;
          handler.resolve(
            Response(requestOptions: request, data: playInfo('$calls')),
          );
        },
      ),
    );
    final site = _Bili();
    final quality = LivePlayQuality(quality: '高清', data: 80);
    final first = site.getPlayUrls(detail: room(), quality: quality);
    final second = site.getPlayUrls(detail: room(), quality: quality);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
    await site.getPlayUrls(detail: room(), quality: quality);
    expect(calls, 2);
  });
  test(
    'Douyu concurrent quality requests share only identical signing args',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      core.HttpClient.instance.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            calls++;
            await gate.future;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': {
                    'cdnsWithName': [
                      {'cdn': 'cdn'},
                    ],
                    'multirates': [
                      {'name': '高清', 'rate': 0},
                    ],
                  },
                },
              ),
            );
          },
        ),
      );
      final site = DouyuSite();
      final first = site.getPlayQualites(detail: room());
      final second = site.getPlayQualites(detail: room());
      gate.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
      await site.getPlayQualites(detail: room());
      expect(calls, 2);
    },
  );
  test(
    'Douyu identical CDN requests coalesce but signing args stay distinct',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      core.HttpClient.instance.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            calls++;
            await gate.future;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': {
                    'rtmp_url': 'https://cdn.test',
                    'rtmp_live': 'live.flv',
                  },
                },
              ),
            );
          },
        ),
      );
      final site = DouyuSite();
      final first = site.getPlayUrl('1', 'sign=one', 0, 'cdn');
      final second = site.getPlayUrl('1', 'sign=one', 0, 'cdn');
      final changed = site.getPlayUrl('1', 'sign=two', 0, 'cdn');
      gate.complete();
      await Future.wait([first, second, changed]);
      expect(calls, 2);
      await site.getPlayUrl('1', 'sign=one', 0, 'cdn');
      expect(calls, 3);
    },
  );
}
