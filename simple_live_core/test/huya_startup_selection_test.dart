import 'dart:async';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;
import 'package:test/test.dart';

class _Huya extends HuyaSite {
  int tokenCalls = 0;
  final tokenGate = Completer<String>();

  @override
  Future<String> getCndTokenInfoEx(String stream) {
    tokenCalls++;
    return tokenGate.future;
  }
}

HuyaLineModel line(String cdn, HuyaLineType type) => HuyaLineModel(
  line: 'http://$cdn.test/src',
  lineType: type,
  flvAntiCode: 'wsSecret=flv&wsTime=ffffffff',
  hlsAntiCode: 'wsSecret=hls&wsTime=ffffffff',
  streamName: 'live',
  cdnType: cdn,
  presenterUid: 123,
);

LiveRoomDetail room(List<HuyaLineModel> lines) => LiveRoomDetail(
  roomId: '660000',
  title: '',
  cover: '',
  userName: '',
  userAvatar: '',
  online: 0,
  status: true,
  url: '',
  data: HuyaUrlDataModel(
    url: '',
    uid: '123',
    lines: lines,
    bitRates: [
      HuyaBitRateModel(name: '4K', bitRate: 20000, codecType: 1),
      HuyaBitRateModel(name: '2K', bitRate: 14000, codecType: 1),
    ],
  ),
);

const manifest = '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\nsegment.ts\n';

void main() {
  late Dio original;
  late _Huya site;
  setUp(() {
    CoreLog.enableLog = false;
    original = core.HttpClient.instance.dio;
    core.HttpClient.instance.dio = Dio();
    site = _Huya();
  });
  tearDown(() {
    if (!site.tokenGate.isCompleted) site.tokenGate.complete('');
    core.HttpClient.instance.dio.close(force: true);
    core.HttpClient.instance.dio = original;
  });

  test('2K uses decodable AVC FLV instead of forcing slow HEVC HLS', () async {
    final detail = room([
      line('flv', HuyaLineType.flv),
      line('hls', HuyaLineType.hls),
    ]);
    final qualities = await site.getPlayQualites(detail: detail);
    site.tokenGate.complete('wsSecret=native&wsTime=ffffffff');
    final result = await site.getPlayUrls(
      detail: detail,
      quality: qualities[1],
    );
    final first = Uri.parse(result.urls.first);
    expect(first.path, '/src/live.flv');
    expect(first.queryParameters['codec'], '264');
    expect(first.queryParameters['ratio'], '14000');
  });

  test(
    '4K races manifests past rejected and slow CDNs without waiting for FLV tokens',
    () async {
      final slow = Completer<void>();
      final canceled = Completer<void>();
      core.HttpClient.instance.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            if (request.uri.host == 'slow.test') {
              request.cancelToken!.whenCancel.then((_) {
                if (!canceled.isCompleted) canceled.complete();
              });
              await slow.future;
            }
            if (request.uri.host == 'denied.test') {
              handler.reject(
                DioException.badResponse(
                  statusCode: 403,
                  requestOptions: request,
                  response: Response(requestOptions: request, statusCode: 403),
                ),
              );
            } else {
              handler.resolve(
                Response(requestOptions: request, data: manifest),
              );
            }
          },
        ),
      );
      final detail = room([
        line('flv', HuyaLineType.flv),
        line('denied', HuyaLineType.hls),
        line('slow', HuyaLineType.hls),
        line('good', HuyaLineType.hls),
      ]);
      try {
        final qualities = await site.getPlayQualites(detail: detail);
        final result = await site
            .getPlayUrls(detail: detail, quality: qualities.first)
            .timeout(const Duration(seconds: 1));
        expect(Uri.parse(result.urls.first).host, 'good.test');
        expect(site.tokenCalls, 0);
        await canceled.future.timeout(const Duration(seconds: 1));
        for (final url in result.urls) {
          final uri = Uri.parse(url);
          expect(uri.scheme, 'https');
          expect(uri.path, '/src/live.m3u8');
          expect(uri.queryParameters['ratio'], '20000');
          expect(uri.queryParameters['codec'], '265');
        }
      } finally {
        slow.complete();
      }
    },
  );

  test('4K rejects HTML and empty playlists even with HTTP 200', () async {
    core.HttpClient.instance.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(
            requestOptions: request,
            data: switch (request.uri.host) {
              'html.test' => '<html>Access denied</html>',
              'empty.test' => '#EXTM3U\n#EXT-X-TARGETDURATION:2\n',
              _ => manifest,
            },
          ),
        ),
      ),
    );
    final detail = room([
      line('html', HuyaLineType.hls),
      line('empty', HuyaLineType.hls),
      line('good', HuyaLineType.hls),
    ]);
    final quality = (await site.getPlayQualites(detail: detail)).first;
    final result = await site.getPlayUrls(detail: detail, quality: quality);
    expect(Uri.parse(result.urls.first).host, 'good.test');
  });

  test(
    'unavailable 4K fails explicitly rather than returning a known invalid first line',
    () async {
      core.HttpClient.instance.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(requestOptions: request, data: '<html>Denied</html>'),
          ),
        ),
      );
      final detail = room([line('bad', HuyaLineType.hls)]);
      final quality = (await site.getPlayQualites(detail: detail)).first;
      await expectLater(
        site.getPlayUrls(detail: detail, quality: quality),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    '4K HTTP 403 reports platform permission instead of endless loading',
    () async {
      core.HttpClient.instance.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException.badResponse(
              statusCode: 403,
              requestOptions: request,
              response: Response(requestOptions: request, statusCode: 403),
            ),
          ),
        ),
      );
      final detail = room([line('denied', HuyaLineType.hls)]);
      final quality = (await site.getPlayQualites(detail: detail)).first;
      await expectLater(
        site.getPlayUrls(detail: detail, quality: quality),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'permission message',
            contains('VIP'),
          ),
        ),
      );
    },
  );
}
