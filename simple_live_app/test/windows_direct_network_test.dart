import 'dart:io';

import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http_package;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/windows_direct_network.dart';
import 'package:simple_live_app/services/remote_sync_connection.dart';
import 'package:simple_live_app/requests/http_client.dart' as app;
import 'package:simple_live_core/src/common/http_client.dart' as core;

class _Proxy extends HttpOverrides {
  _Proxy(this.port);
  final int port;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
}

void main() {
  test(
      'Windows startup overrides inherited routing for Dart, all Dio factories and WebSockets',
      () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final trap = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var proxyHits = 0;
    final peers = <WebSocket>[];
    origin.listen((r) async {
      if (WebSocketTransformer.isUpgradeRequest(r)) {
        final ws = await WebSocketTransformer.upgrade(r);
        peers.add(ws);
        ws.listen(ws.add);
      } else {
        r.response.write('DIRECT');
        await r.response.close();
      }
    });
    trap.listen((r) async {
      proxyHits++;
      r.response.statusCode = 502;
      await r.response.close();
    });
    final previous = HttpOverrides.current;
    HttpOverrides.global = _Proxy(trap.port);
    final clients = <Dio>[];
    final sockets = <WebSocket>[];
    try {
      WindowsDirectNetwork.initialize();
      final url = 'http://127.0.0.1:${origin.port}/';
      final direct = HttpClient();
      try {
        final response = await (await direct.getUrl(Uri.parse(url))).close();
        expect(await response.transform(SystemEncoding().decoder).join(),
            'DIRECT');
      } finally {
        direct.close(force: true);
      }
      clients.addAll([Dio(), app.HttpClient().dio, core.HttpClient().dio]);
      for (final dio in clients) {
        expect((await dio.get<String>(url)).data, 'DIRECT');
      }
      expect((await http_package.get(Uri.parse(url))).body, 'DIRECT');
      sockets.add(await WebSocket.connect(url.replaceFirst('http:', 'ws:')));
      sockets.add(await RemoteSyncConnection(
              proxyResolver: (_) => 'PROXY 127.0.0.1:${trap.port}')
          .connect(url.replaceFirst('http:', 'ws:')));
      for (final ws in sockets) {
        final next = ws.first;
        ws.add('direct-ws');
        expect(await next, 'direct-ws');
      }
      expect(proxyHits, 0);
    } finally {
      for (final dio in clients) {
        dio.close(force: true);
      }
      for (final ws in [...sockets, ...peers]) {
        await ws.close();
      }
      await origin.close(force: true);
      await trap.close(force: true);
      HttpOverrides.global = previous;
    }
  }, skip: !Platform.isWindows);
}
