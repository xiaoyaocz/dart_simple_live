import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/system_http_proxy.dart';

void main() {
  test('读取平台代理，不写死主机和端口', () {
    final proxy = SystemHttpProxy.fromPlatform({
      'host': '127.0.0.1', 'port': 32145, 'exclusions': ['localhost', '*.local'],
    })!;
    expect(proxy.directive(Uri.parse('https://live.example.com')), 'PROXY 127.0.0.1:32145');
    expect(proxy.playbackUrl(Uri.parse('https://cdn.example.com/live.flv')), 'http://127.0.0.1:32145');
  });
  for (final host in ['localhost', '192.168.1.2', 'media.local', 'printer', 'EXAMPLE.COM']) {
    test('遵守系统直连例外 $host', () {
      final proxy = SystemHttpProxy('127.0.0.1', 3128,
          ['localhost', '192.168.*', '*.local', '<local>', '.example.com']);
      final uri = Uri.parse('https://$host/live');
      expect(proxy.directive(uri), 'DIRECT');
      expect(proxy.playbackUrl(uri), isNull);
    });
  }
  test('IPv6 代理地址只保留一组方括号', () {
    final proxy = SystemHttpProxy.fromPlatform({'host': '[::1]', 'port': 3128})!;
    expect(proxy.directive(Uri.parse('https://example.com')), 'PROXY [::1]:3128');
    expect(proxy.playbackUrl(Uri.parse('https://example.com')), 'http://[::1]:3128');
  });
  test('无代理和无效代理不生成错误路由', () {
    for (final value in <Map<String, dynamic>?>[
      null, {}, {'host': 'proxy', 'port': -1}, {'host': 'proxy', 'port': 65536},
      {'host': 'proxy; DIRECT', 'port': 3128}, {'host': '', 'port': 3128},
    ]) {
      expect(SystemHttpProxy.fromPlatform(value), isNull);
    }
  });
  test('真实 Dio 和原生图片 HTTP 请求均通过系统代理取得数据', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <Uri>[];
    server.listen((request) async {
      paths.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"loaded":true}');
      await request.response.close();
    });
    final override = SystemProxyHttpOverrides(() => SystemHttpProxy('127.0.0.1', server.port, []));
    try {
      await HttpOverrides.runWithHttpOverrides(() async {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));
        final client = HttpClient();
        try {
          // This hostname cannot resolve without the proxy. Exercise real
          // sockets, not an interceptor that invents a successful response.
          final json = await dio.get('http://streams.invalid/rooms');
          expect(json.data, {'loaded': true});
          final response = await (await client.getUrl(Uri.parse('http://images.invalid/cover'))).close();
          expect(response.statusCode, 200);
          await response.drain<void>();
        } finally { dio.close(force: true); client.close(force: true); }
      }, override);
      expect(paths.map((uri) => uri.host), ['streams.invalid', 'images.invalid']);
      expect(paths.map((uri) => uri.path), ['/rooms', '/cover']);
    } finally { await server.close(force: true); }
  });
  test('已创建的 HTTP 客户端跟随代理变更并能恢复直连', () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final direct = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    void reply(HttpServer server, String value) => server.listen((request) async {
      request.response.write(value); await request.response.close();
    });
    reply(first, 'first'); reply(second, 'second'); reply(direct, 'direct');
    SystemHttpProxy? current = SystemHttpProxy('127.0.0.1', first.port, []);
    final override = SystemProxyHttpOverrides(() => current);
    final client = override.createHttpClient(null);
    Future<String> get(Uri uri) async {
      final result = await (await client.getUrl(uri)).close();
      return result.transform(const SystemEncoding().decoder).join();
    }
    try {
      final uri = Uri.parse('http://same.invalid/live');
      expect(await get(uri), 'first');
      current = SystemHttpProxy('127.0.0.1', second.port, []);
      expect(await get(uri), 'second');
      current = null;
      expect(await get(Uri.parse('http://127.0.0.1:${direct.port}/live')), 'direct');
    } finally {
      client.close(force: true);
      await Future.wait([first.close(force: true), second.close(force: true), direct.close(force: true)]);
    }
  });
}
