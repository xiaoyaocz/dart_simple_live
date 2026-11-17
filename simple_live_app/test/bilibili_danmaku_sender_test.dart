import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/bilibili_danmaku_sender.dart';

class _Http implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  dynamic reply = {'code': 0};
  int status = 200;
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    requests.add(options);
    await gate?.future;
    if (reply is Exception) throw reply as Exception;
    return ResponseBody.fromString(jsonEncode(reply), status, headers: {
      'content-type': ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'uses current account CSRF, canonical room and form POST, not a room WebView',
      () async {
    final http = _Http();
    var csrf = 'first';
    final sender = BilibiliDanmakuSender(
        roomId: '7734200',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async => {'SESSDATA': 'session', 'bili_jct': csrf});
    expect((await sender.send('你好 👋')).sent, isTrue);
    final request = http.requests.single;
    expect(request.uri, BilibiliDanmakuSender.endpoint);
    expect(request.method, 'POST');
    expect(request.data, containsPair('roomid', '7734200'));
    expect(request.data, containsPair('msg', '你好 👋'));
    expect(request.data, containsPair('csrf', 'first'));
    expect(request.data, containsPair('csrf_token', 'first'));
    expect(request.contentType, Headers.formUrlEncodedContentType);
    csrf = 'refreshed';
    await sender.send('next');
    expect(http.requests.last.data['csrf'], 'refreshed');
    await sender.dispose();
  });
  test('no login does not submit; expiry and filtering are not success',
      () async {
    final http = _Http();
    var cookies = <String, String>{};
    final sender = BilibiliDanmakuSender(
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async => cookies);
    expect((await sender.send('x')).status, 'login');
    expect(http.requests, isEmpty);
    cookies = {'SESSDATA': 's', 'bili_jct': 'c'};
    for (final response in [
      {'code': -101},
      {'code': 0, 'message': 'f'},
      {'code': 0, 'msg': '屏蔽'}
    ]) {
      http.reply = response;
      expect((await sender.send('x')).sent, isFalse);
    }
    cookies = {};
    expect((await sender.send('x')).status, 'login');
    expect(http.requests, hasLength(3));
    await sender.dispose();
  });
  test('single flight, unknown response guard, no automatic retries', () async {
    final http = _Http()..gate = Completer<void>();
    final sender = BilibiliDanmakuSender(
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async => {'SESSDATA': 's', 'bili_jct': 'c'});
    final pending = sender.send('x');
    for (var i = 0; http.requests.isEmpty && i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect((await sender.send('x')).status, 'busy');
    expect(http.requests, hasLength(1));
    http.reply = {};
    http.gate!.complete();
    expect((await pending).status, 'unknown');
    expect((await sender.send('x')).status, 'unknown');
    expect(http.requests, hasLength(1));
    http.gate = null;
    http.reply = TimeoutException('fixture');
    expect((await sender.send('y')).status, 'unknown');
    expect(http.requests, hasLength(2));
    expect((await sender.send('y')).status, 'unknown');
    expect(http.requests, hasLength(2));
    await sender.dispose();
  });
  test('HTTP 500 is uncertain, not safe to repeat, HTTP 403 is rejection',
      () async {
    final http = _Http()..status = 500;
    final sender = BilibiliDanmakuSender(
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async => {'SESSDATA': 's', 'bili_jct': 'c'});
    expect((await sender.send('x')).status, 'unknown');
    expect((await sender.send('x')).status, 'unknown');
    expect(http.requests, hasLength(1));
    http.status = 403;
    expect((await sender.send('y')).status, 'rejected');
    await sender.dispose();
  });
  test('switching room cancels preparation and prevents late submits',
      () async {
    final http = _Http();
    final cookie = Completer<Map<String, String>>();
    final sender = BilibiliDanmakuSender(
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) => cookie.future);
    final pending = sender.send('x');
    await sender.dispose();
    cookie.complete({'SESSDATA': 's', 'bili_jct': 'c'});
    expect((await pending).status, 'closed');
    expect(http.requests, isEmpty);
  });
}
