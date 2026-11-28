import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:simple_live_core/src/common/adaptive_http2_adapter.dart';
import 'package:test/test.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Future<ResponseBody> Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{"ok":true}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('白名单 HTTPS 主机走 HTTP/2、剥离 H1 非法头并自动解压 gzip/deflate', () async {
    final h1 = _FakeAdapter();
    final h2 = _FakeAdapter()
      ..handler = (options) async {
        expect(options.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authority')));
        expect(options.headers.keys.map((k) => k.toLowerCase()), isNot(contains('host')));
        expect(options.headers.keys.map((k) => k.toLowerCase()), isNot(contains('connection')));
        expect(options.headers.keys.map((k) => k.toLowerCase()), isNot(contains('keep-alive')));
        expect(options.headers['accept-encoding'], 'gzip');

        final gz = gzip.encode(utf8.encode('{"msg":"ok-h2"}'));
        return ResponseBody(
          Stream.value(Uint8List.fromList(gz)),
          200,
          headers: {
            'content-type': ['application/json'],
            'content-encoding': ['gzip'],
            'content-length': ['${gz.length}'],
          },
        );
      };

    final adapter = AdaptiveHttp2Adapter(
      http1Adapter: h1,
      http2Adapter: h2,
    );
    final dio = Dio()..httpClientAdapter = adapter;

    final resp = await dio.get<String>(
      'https://live.douyin.com/webcast/room/web/enter/',
      options: Options(
        headers: {
          'Authority': 'live.douyin.com',
          'Host': 'live.douyin.com',
          'Connection': 'keep-alive',
          'Keep-Alive': 'timeout=60',
          'Referer': 'https://live.douyin.com',
        },
        responseType: ResponseType.plain,
      ),
    );

    expect(resp.data, '{"msg":"ok-h2"}');
    expect(resp.headers.value('content-encoding'), isNull);
    expect(h2.requests.length, 1);
    expect(h1.requests, isEmpty);
    adapter.close(force: true);
  });

  test('非白名单主机、HTTP 明文与代理条件禁用走 HTTP/1.1 适配器', () async {
    final h1 = _FakeAdapter();
    final h2 = _FakeAdapter();
    var proxyActive = false;

    final adapter = AdaptiveHttp2Adapter(
      http1Adapter: h1,
      http2Adapter: h2,
      shouldUseHttp2: (_) => !proxyActive,
    );
    final dio = Dio()..httpClientAdapter = adapter;

    await dio.get('https://mp.huya.com/cache.php');
    await dio.get('http://live.douyin.com/test');
    proxyActive = true;
    await dio.get('https://www.douyu.com/betard/1');

    expect(h2.requests, isEmpty);
    expect(h1.requests.length, 3);
    adapter.close(force: true);
  });

  test('HTTP/2 协议/传输失败回退 HTTP/1.1 并降级该域名，而 badResponse 不降级不回退', () async {
    final h1 = _FakeAdapter();
    final h2 = _FakeAdapter();
    final adapter = AdaptiveHttp2Adapter(
      http1Adapter: h1,
      http2Adapter: h2,
    );
    final dio = Dio()..httpClientAdapter = adapter;

    // 1. 服务端 HTTP 错误 (badResponse) 原样抛出，不走 H1 重试、不降级域名
    h2.handler = (options) async {
      throw DioException.badResponse(
        statusCode: 444,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 444),
      );
    };
    await expectLater(
      () => dio.get('https://live.douyin.com/err444'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'code', 444)),
    );
    expect(h1.requests, isEmpty);
    expect(adapter.isHostDowngraded('live.douyin.com'), isFalse);

    // 2. 协商/传输失败时立即回退 H1 并加入降级表，后续同域名直走 H1
    h2.handler = (options) async {
      throw DioH2NotSupportedException(options.uri, 'http/1.1');
    };
    await dio.get('https://www.douyu.com/betard/9999');
    expect(adapter.isHostDowngraded('www.douyu.com'), isTrue);
    expect(h1.requests.length, 1);

    h2.requests.clear();
    await dio.get('https://www.douyu.com/betard/10000');
    expect(h2.requests, isEmpty);
    expect(h1.requests.length, 2);
    adapter.close(force: true);
  });

  test('请求取消异常直接抛出，不回退不降级', () async {
    final h1 = _FakeAdapter();
    final h2 = _FakeAdapter()
      ..handler = (options) async {
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'cancelled',
        );
      };
    final adapter = AdaptiveHttp2Adapter(
      http1Adapter: h1,
      http2Adapter: h2,
    );
    final dio = Dio()..httpClientAdapter = adapter;

    await expectLater(
      () => dio.get('https://api.live.bilibili.com/test'),
      throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.cancel)),
    );
    expect(h1.requests, isEmpty);
    expect(adapter.isHostDowngraded('api.live.bilibili.com'), isFalse);
    adapter.close(force: true);
  });
}
