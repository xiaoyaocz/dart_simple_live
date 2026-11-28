import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;
import 'package:test/test.dart';

class _Huya extends HuyaSite {
  @override
  Future<String> getCndTokenInfoEx(String stream) async =>
      'wsSecret=token&wsTime=ffffffff';
}

void main() {
  late Dio original;
  final rates = [
    {'sDisplayName': '4K', 'iBitRate': 20000, 'iCodecType': 1},
    {'sDisplayName': '2K', 'iBitRate': 14000, 'iCodecType': 1},
    {'sDisplayName': '蓝光10M', 'iBitRate': 0, 'iCodecType': 0},
    {'sDisplayName': '超清', 'iBitRate': 2000},
    {'sDisplayName': '4K HDR', 'iBitRate': 20100, 'iCodecType': 1},
  ];
  final line = {
    'sFlvUrl': 'http://flv.test/src',
    'sHlsUrl': 'http://hls.test/src',
    'sFlvAntiCode': 'wsSecret=flv&wsTime=ffffffff',
    'sHlsAntiCode': 'wsSecret=hls&wsTime=ffffffff',
    'sStreamName': 'live-stream',
    'sCdnType': 'TX',
    'lPresenterUid': 123,
  };

  setUp(() {
    CoreLog.enableLog = false;
    original = core.HttpClient.instance.dio;
    core.HttpClient.instance.dio = Dio();
  });
  tearDown(() {
    core.HttpClient.instance.dio.close();
    core.HttpClient.instance.dio = original;
  });

  for (final html in [false, true]) {
    test(
      '${html ? 'HTML fallback' : 'JSON API'} preserves quality codec in FLV and HLS URLs',
      () async {
        core.HttpClient.instance.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.uri.host.endsWith('.test')) {
                handler.resolve(
                  Response(
                    requestOptions: request,
                    data: '#EXTM3U\n#EXTINF:2,\nsegment.ts\n',
                  ),
                );
                return;
              }
              if (html && request.uri.path == '/cache.php') {
                handler.reject(DioException(requestOptions: request));
                return;
              }
              final data = html
                  ? '<script>window.HNF_GLOBAL_INIT = ${jsonEncode({
                      'roomInfo': {
                        'eLiveStatus': 2,
                        'tLiveInfo': {
                          'lProfileRoom': 660000,
                          'lTotalCount': 1,
                          'tLiveStreamInfo': {
                            'vStreamInfo': {
                              'value': [line],
                            },
                            'vBitRateInfo': {'value': rates},
                          },
                        },
                        'tProfileInfo': <String, dynamic>{},
                      },
                      'roomProfile': {'liveLineUrl': base64Encode(utf8.encode('//flv.test/live'))},
                    })}</script>'
                  : {
                      'data': {
                        'liveStatus': 'ON',
                        'liveData': {
                          'profileRoom': 660000,
                          'bitRateInfo': jsonEncode(rates),
                        },
                        'stream': {
                          'baseSteamInfoList': [line],
                        },
                      },
                    };
              handler.resolve(Response(requestOptions: request, data: data));
            },
          ),
        );
        final site = _Huya();
        final room = await site.getRoomDetail(roomId: '660000');
        final qualities = await site.getPlayQualites(detail: room);
        expect(qualities.map((q) => q.quality), ['4K', '2K', '蓝光10M', '超清']);
        final expected = [
          ('265', '20000'),
          ('264', '14000'),
          ('264', null),
          ('264', '2000'),
        ];
        for (var i = 0; i < qualities.length; i++) {
          final urls = await site.getPlayUrls(
            detail: room,
            quality: qualities[i],
          );
          final hevc = i == 0;
          expect(urls.urls, hasLength(hevc ? 1 : 2));
          expect(
            Uri.parse(urls.urls[0]).path,
            hevc ? '/src/live-stream.m3u8' : '/src/live-stream.flv',
          );
          if (!hevc) {
            expect(Uri.parse(urls.urls[1]).path, '/src/live-stream.m3u8');
          }
          for (final url in urls.urls) {
            expect(Uri.parse(url).scheme, hevc ? 'https' : 'http');
            final query = Uri.parse(url).queryParameters;
            expect(
              query['codec'],
              expected[i].$1,
              reason: qualities[i].quality,
            );
            expect(query['ratio'], expected[i].$2);
            expect(query['wsSecret'], isNotEmpty);
          }
        }
      },
    );
  }
}
