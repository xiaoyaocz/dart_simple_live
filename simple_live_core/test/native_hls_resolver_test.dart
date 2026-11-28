import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';

void main() {
  late Dio dio;
  late Dio old;
  setUp(() {
    old = HttpClient.instance.dio;
    dio = Dio();
    HttpClient.instance.dio = dio;
  });
  tearDown(() {
    HttpClient.instance.dio = old;
    dio.close(force: true);
  });
  test('FLV bypasses manifest probing', () async {
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          requests++;
          h.reject(DioException(requestOptions: o));
        },
      ),
    );
    final input = LivePlayUrl(urls: ['https://example.com/live.flv']);
    expect(await preferNativeHls(input), same(input));
    expect(requests, 0);
  });
  test(
    'master requests retain headers and variant keeps master fallback',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            expect(o.headers['Referer'], 'https://example.com/');
            h.resolve(
              Response(
                requestOptions: o,
                data: ResponseBody.fromString(
                  '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=10,FRAME-RATE=120\nhi.m3u8?token=a\n',
                  200,
                ),
              ),
            );
          },
        ),
      );
      final input = LivePlayUrl(
        urls: ['https://example.com/master.m3u8'],
        headers: {'Referer': 'https://example.com/'},
      );
      final selected = await preferNativeHls(input);
      expect(selected.urls, [
        'https://example.com/hi.m3u8?token=a',
        ...input.urls,
      ]);
      expect(selected.headers, input.headers);
    },
  );
  test(
    'oversized playlist falls back without downloading entire stream',
    () async {
      var consumed = 0;
      Stream<Uint8List> bytes() async* {
        for (var i = 0; i < 100; i++) {
          consumed++;
          yield Uint8List.fromList(utf8.encode('x' * 10000));
        }
      }

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            h.resolve(
              Response(requestOptions: o, data: ResponseBody(bytes(), 200)),
            );
          },
        ),
      );
      final input = LivePlayUrl(urls: ['https://example.com/master.m3u8']);
      expect(await preferNativeHls(input), same(input));
      expect(consumed, lessThan(100));
    },
  );
  test(
    'forbidden manifests retain original URL and never invent a stream',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            h.reject(
              DioException(
                requestOptions: o,
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: o, statusCode: 403),
              ),
            );
          },
        ),
      );
      final input = LivePlayUrl(urls: ['https://example.com/master.m3u8']);
      expect(await preferNativeHls(input), same(input));
    },
  );
}
