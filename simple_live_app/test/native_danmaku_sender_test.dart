import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/native_danmaku_sender.dart';

class _Http implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object reply = {'code': 0};
  Completer<void>? wait;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    requests.add(options);
    await wait?.future;
    if (reply is Exception) throw reply as Exception;
    return ResponseBody.fromString(jsonEncode(reply), 200, headers: {
      'content-type': ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'Bilibili uses only current website credentials and one direct form POST',
      () async {
    final http = _Http();
    final dio = Dio()..httpClientAdapter = http;
    var csrf = 'first';
    final urls = <Uri>[];
    final sender = NativeDanmakuSender(
        siteId: 'bilibili',
        roomId: '13914640',
        dio: dio,
        credentials: (uri) async {
          urls.add(uri);
          return {'SESSDATA': 'session', 'bili_jct': csrf};
        });
    expect((await sender.send('你好[dog]')).sent, isTrue);
    final r = http.requests.single;
    expect(r.uri.host, 'api.live.bilibili.com');
    expect(r.uri.path, '/msg/send');
    expect(r.method, 'POST');
    expect(r.data, containsPair('msg', '你好[dog]'));
    expect(r.data, containsPair('csrf', 'first'));
    expect(r.data, containsPair('csrf_token', 'first'));
    expect(r.data, containsPair('roomid', '13914640'));
    csrf = 'second';
    await sender.send('second');
    expect(http.requests.last.data['csrf'], 'second');
    expect(urls.every((u) => u.host == 'api.live.bilibili.com'), isTrue);
    await sender.dispose();
  });

  test('missing login, logout and platform errors never report success',
      () async {
    final http = _Http();
    var cookies = <String, String>{};
    final sender = NativeDanmakuSender(
        siteId: 'bilibili',
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async => cookies);
    expect((await sender.send('x')).status, 'login');
    expect(http.requests, isEmpty);
    cookies = {'SESSDATA': 'session', 'bili_jct': 'csrf'};
    http.reply = {'code': 0, 'message': 'f', 'msg': '您已被禁言'};
    expect((await sender.send('x')).sent, isFalse);
    http.reply = {'code': -101, 'message': '请先登录'};
    expect((await sender.send('x')).sent, isFalse);
    http.reply = {'code': 0};
    expect((await sender.send('x')).sent, isTrue);
    cookies = {};
    expect((await sender.send('x')).status, 'login');
    await sender.dispose();
  });

  test('Douyin uses internal room id, signed URL and preserves emoji text',
      () async {
    final http = _Http()..reply = {'status_code': 0};
    String? signed;
    final sender = NativeDanmakuSender(
        siteId: 'douyin',
        roomId: '1234567890123456789',
        webRoomId: 'visibleRid',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async =>
            {'sessionid': 'session', 'msToken': 'live-token'},
        signDouyin: (url, ua) {
          signed = url;
          return '$url&a_bogus=fixture';
        });
    expect((await sender.send('你好[比心] 👋')).sent, isTrue);
    final r = http.requests.single;
    expect(r.method, 'GET');
    expect(r.uri.queryParameters['room_id'], '1234567890123456789');
    expect(r.uri.queryParameters['content'], '你好[比心] 👋');
    expect(Uri.parse(signed!).queryParameters['msToken'], 'live-token');
    expect(r.headers['Referer'], 'https://live.douyin.com/visibleRid');
    expect(r.uri.queryParameters['a_bogus'], 'fixture');
    await sender.dispose();
  });

  test('malformed responses, submission timeout and cooldown are not retried',
      () async {
    final http = _Http()..reply = {};
    final sender = NativeDanmakuSender(
        siteId: 'douyin',
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) async => {'sessionid': 'session'},
        signDouyin: (u, _) => u);
    expect((await sender.send('x')).status, 'unknown');
    expect(http.requests.length, 1);
    http.reply = {'status_code': 2, 'status_msg': '发送过于频繁'};
    expect((await sender.send('x')).status, 'rejected');
    expect(http.requests.length, 2);
    http.reply = TimeoutException('fixture');
    expect((await sender.send('x')).status, 'unknown');
    expect(http.requests.length, 3);
    await sender.dispose();
  });

  test('prepare never submits and close prevents late credential completion',
      () async {
    final http = _Http();
    final login = Completer<Map<String, String>>();
    final sender = NativeDanmakuSender(
        siteId: 'bilibili',
        roomId: '1',
        dio: Dio()..httpClientAdapter = http,
        credentials: (_) => login.future);
    sender.prepare();
    await Future<void>.delayed(Duration.zero);
    expect(http.requests, isEmpty);
    final sending = sender.send('late');
    await sender.dispose();
    login.complete({'SESSDATA': 'session', 'bili_jct': 'csrf'});
    expect((await sending).status, 'closed');
    expect(http.requests, isEmpty);
  });
}
