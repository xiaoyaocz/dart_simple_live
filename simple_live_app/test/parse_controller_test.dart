import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';

class _RedirectAdapter implements HttpClientAdapter {
  _RedirectAdapter(this.responses);

  final Map<String, ResponseBody> responses;
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
    final response = responses[options.uri.toString()];
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
      expect(
        ParseController.extractHttpUrl(
          '直播地址：https://live.douyin.com/123456，欢迎观看',
        ),
        'https://live.douyin.com/123456',
      );
      expect(
        ParseController.extractHttpUrl(
          '(https://v.kuaishou.com/abc)，欢迎观看',
        ),
        'https://v.kuaishou.com/abc',
      );
      expect(
        ParseController.extractHttpUrl(
          '（https://v.kuaishou.com/abc）',
        ),
        'https://v.kuaishou.com/abc',
      );
    });

    test('returns empty text when no URL exists', () {
      expect(ParseController.extractHttpUrl('没有链接'), isEmpty);
    });
  });

  group('ParseController.resolveKuaishouRoomId', () {
    test('follows trusted short-link redirects without a Cookie', () async {
      final adapter = _RedirectAdapter({
        'https://v.kuaishou.com/first': ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://v.kuaishou.com/second'],
          },
        ),
        'https://v.kuaishou.com/second': ResponseBody.fromString(
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
        'https://v.kuaishou.com/no-scheme': ResponseBody.fromString(
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
        'https://v.kuaishou.com/untrusted': ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://evil.example/u/room'],
          },
        ),
        'https://v.kuaishou.com/loop-a': ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://v.kuaishou.com/loop-b'],
          },
        ),
        'https://v.kuaishou.com/loop-b': ResponseBody.fromString(
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
}
