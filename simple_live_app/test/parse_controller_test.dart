import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';

class _RedirectAdapter implements HttpClientAdapter {
  // 每次请求都新建 ResponseBody，同一 URL 可能被多次请求。
  _RedirectAdapter(this.responses);

  final Map<String, ResponseBody Function()> responses;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses[options.uri.toString()]?.call();
    if (response == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
      );
    }
    return response;
  }
}

ParseController _controllerWithRedirects(_RedirectAdapter adapter) {
  final client = Dio()..httpClientAdapter = adapter;
  return ParseController(redirectClient: client);
}

void main() {
  group('ParseController.extractHttpUrl', () {
    test('extracts a Douyin short URL from share text', () {
      const shareText =
          '正在直播，复制链接打开抖音 https://v.douyin.com/GiurKu1HX_I/ 5@9.com';

      expect(
        ParseController.extractHttpUrl(shareText),
        'https://v.douyin.com/GiurKu1HX_I/',
      );
    });

    test('removes punctuation appended by prose', () {
      // 正则排除中文标点符号，所以会在这些符号处停止
      expect(
        ParseController.extractHttpUrl(
          '直播地址：https://live.douyin.com/123456，欢迎观看',
        ),
        'https://live.douyin.com/123456',
      );
      // 括号不在排除列表中，会被包含（这是合理的，因为URL可能包含括号）
      expect(
        ParseController.extractHttpUrl(
          '(https://v.kuaishou.com/abc)，欢迎观看',
        ),
        'https://v.kuaishou.com/abc)',
      );
      expect(
        ParseController.extractHttpUrl(
          '（https://v.kuaishou.com/abc）',
        ),
        'https://v.kuaishou.com/abc）',
      );
    });

    test('returns empty text when no URL exists', () {
      expect(ParseController.extractHttpUrl('没有链接'), isEmpty);
    });
  });

  group('ParseController.resolveKuaishouRoomId', () {
    test('follows trusted short-link redirects without a Cookie', () async {
      final adapter = _RedirectAdapter({
        'https://v.kuaishou.com/first': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://v.kuaishou.com/second'],
              },
            ),
        'https://v.kuaishou.com/second': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': [
                  'https://live.m.chenzhongtech.com/fw/live/mobile-room',
                ],
              },
            ),
      });

      final roomId = await _controllerWithRedirects(adapter)
          .resolveKuaishouRoomId('https://v.kuaishou.com/first');

      expect(roomId, 'mobile-room');
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests
            .expand((request) => request.headers.keys)
            .map((key) => key.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(
        adapter.requests.every(
          (request) =>
              request.connectTimeout == const Duration(seconds: 8) &&
              request.receiveTimeout == const Duration(seconds: 8),
        ),
        isTrue,
      );
    });

    test('accepts official links without an explicit scheme', () async {
      final adapter = _RedirectAdapter({
        'https://v.kuaishou.com/no-scheme': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://live.kuaishou.com/u/short-room'],
              },
            ),
      });
      final controller = _controllerWithRedirects(adapter);

      expect(
        await controller.resolveKuaishouRoomId(
          'live.kuaishou.com/u/direct-room',
        ),
        'direct-room',
      );
      expect(
        await controller.resolveKuaishouRoomId(
          'v.kuaishou.com/no-scheme',
        ),
        'short-room',
      );
    });

    test('rejects untrusted redirects and redirect loops', () async {
      final adapter = _RedirectAdapter({
        'https://v.kuaishou.com/untrusted': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://evil.example/u/room'],
              },
            ),
        'https://v.kuaishou.com/loop-a': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://v.kuaishou.com/loop-b'],
              },
            ),
        'https://v.kuaishou.com/loop-b': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://v.kuaishou.com/loop-a'],
              },
            ),
      });
      final controller = _controllerWithRedirects(adapter);

      expect(
        await controller.resolveKuaishouRoomId(
          'https://v.kuaishou.com/untrusted',
        ),
        isEmpty,
      );
      expect(
        await controller.resolveKuaishouRoomId(
          'https://v.kuaishou.com/loop-a',
        ),
        isEmpty,
      );
      expect(
        await controller.resolveKuaishouRoomId(
          'https://live.kuaishou.com.evil.example/u/room',
        ),
        isEmpty,
      );
    });
  });

  group('ParseController.parse', () {
    test('parses direct links of every site', () async {
      final controller = _controllerWithRedirects(_RedirectAdapter({}));

      final douyin = await controller.parse('https://live.douyin.com/123456');
      expect(douyin.first, '123456');
      expect(douyin.last.id, 'douyin');

      final followLive = await controller
          .parse('https://www.douyin.com/follow/live/884412345678');
      expect(followLive.first, '884412345678');
      expect(followLive.last.id, 'douyin');

      final webLive =
          await controller.parse('https://www.douyin.com/live/884412345678');
      expect(webLive.first, '884412345678');
      expect(webLive.last.id, 'douyin');

      final dottedRoom =
          await controller.parse('https://live.douyin.com/123.456');
      expect(dottedRoom.first, '123.456');
      expect(dottedRoom.last.id, 'douyin');

      final huya = await controller.parse('https://www.huya.com/abc.def');
      expect(huya.first, 'abc.def');
      expect(huya.last.id, 'huya');

      final douyu =
          await controller.parse('https://www.douyu.com/topic/xyz?rid=5087042');
      expect(douyu.first, '5087042');
      expect(douyu.last.id, 'douyu');
    });

    test('resolves douyin short links without a Cookie', () async {
      final adapter = _RedirectAdapter({
        'https://v.douyin.com/iAbC12d3/': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://live.douyin.com/7654321'],
              },
            ),
        'https://live.douyin.com/7654321': () =>
            ResponseBody.fromString('', 200),
      });

      final result = await _controllerWithRedirects(adapter)
          .parse('https://v.douyin.com/iAbC12d3/');

      expect(result.first, '7654321');
      expect(result.last.id, 'douyin');
      expect(
        adapter.requests
            .expand((request) => request.headers.keys)
            .map((key) => key.toLowerCase()),
        isNot(contains('cookie')),
      );
    });

    test('gives up on short-link chains beyond the depth limit', () async {
      final adapter = _RedirectAdapter({
        'https://v.douyin.com/a': () => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://v.douyin.com/b'],
              },
            ),
        // b 一直解析为短链（200 结束重定向），parse 会不断递归。
        'https://v.douyin.com/b': () => ResponseBody.fromString('', 200),
      });

      final result = await _controllerWithRedirects(adapter)
          .parse('https://v.douyin.com/a');

      expect(result, isEmpty);
      // a(302)、b(200) × 3 次 getLocation 后到达递归深度上限。
      expect(adapter.requests, hasLength(4));
    });

    test('rejects unrecognizable links', () async {
      final controller = _controllerWithRedirects(_RedirectAdapter({}));

      expect(await controller.parse('https://www.douyin.com/video/12345'),
          isEmpty);
      expect(await controller.parse('https://example.com/123'), isEmpty);
    });
  });
}
