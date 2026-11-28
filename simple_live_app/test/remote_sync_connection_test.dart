import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/remote_sync_connection.dart';

class _DefaultProxy extends HttpOverrides {
  final String proxy;
  _DefaultProxy(this.proxy);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => proxy;
}

void main() {
  test('非 Windows 保留 HttpClient 原有代理解析', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peers = <WebSocket>[];
    final subscription = proxy.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      peers.add(socket);
      socket.listen(socket.add);
    });
    WebSocket? client;
    try {
      await HttpOverrides.runWithHttpOverrides(() async {
        final connection = RemoteSyncConnection(proxyResolver: (_) => null);
        client = await connection.connect('ws://unreachable.invalid/sync');
        final received = client!.first;
        client!.add('default-proxy-sync');
        expect(await received.timeout(const Duration(seconds: 2)),
            'default-proxy-sync');
      }, _DefaultProxy('PROXY 127.0.0.1:${proxy.port}'));
    } finally {
      await client?.close();
      for (final peer in peers) {
        await peer.close();
      }
      await subscription.cancel();
      await proxy.close(force: true);
    }
  }, skip: Platform.isWindows);

  test('非 Windows 注入代理的 WebSocket 行为保持不变', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peers = <WebSocket>[];
    final subscription = proxy.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      peers.add(socket);
      socket.listen(socket.add);
    });
    final connection = RemoteSyncConnection(
      proxyResolver: (_) => 'PROXY 127.0.0.1:${proxy.port}',
    );
    WebSocket? client;
    try {
      client = await connection.connect('ws://unreachable.invalid/sync');
      final received = client.first;
      client.add('room-sync');
      expect(await received.timeout(const Duration(seconds: 2)), 'room-sync');
    } finally {
      await client?.close();
      for (final peer in peers) {
        await peer.close();
      }
      await subscription.cancel();
      await proxy.close(force: true);
    }
  }, skip: Platform.isWindows);

  test('系统代理不可用时回退直连，已有局域网连接继续可用', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final unavailablePort = unused.port;
    await unused.close();
    final peers = <WebSocket>[];
    final subscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      peers.add(socket);
      socket.listen(socket.add);
    });
    final connection = RemoteSyncConnection(
      proxyResolver: (_) => 'PROXY 127.0.0.1:$unavailablePort',
    );
    WebSocket? client;
    try {
      client = await connection.connect('ws://127.0.0.1:${server.port}/sync');
      final received = client.first;
      client.add('direct-sync');
      expect(await received.timeout(const Duration(seconds: 2)), 'direct-sync');
    } finally {
      await client?.close();
      for (final peer in peers) {
        await peer.close();
      }
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('Windows 代理设置选择 HTTPS 代理，并尊重关闭和绕过列表', () {
    final remote = Uri.parse('wss://sync.example.com/sync');
    expect(
      RemoteSyncConnection.proxyDirective(remote,
          enabled: true, server: '127.0.0.1:7890'),
      'PROXY 127.0.0.1:7890',
    );
    expect(
      RemoteSyncConnection.proxyDirective(remote,
          enabled: true, server: 'http=127.0.0.1:8080;https=127.0.0.1:7890'),
      'PROXY 127.0.0.1:7890',
    );
    expect(
      RemoteSyncConnection.proxyDirective(remote,
          enabled: false, server: '127.0.0.1:7890'),
      isNull,
    );
    expect(
      RemoteSyncConnection.proxyDirective(remote,
          enabled: true,
          server: '127.0.0.1:7890',
          bypass: '*.example.com;<local>'),
      'DIRECT',
    );
    expect(
      RemoteSyncConnection.proxyDirective(Uri.parse('ws://localhost/sync'),
          enabled: true, server: '127.0.0.1:7890', bypass: '<local>'),
      'DIRECT',
    );
    expect(
      RemoteSyncConnection.proxyDirective(remote,
          enabled: true, server: 'socks=127.0.0.1:1080'),
      isNull,
    );
    expect(
      RemoteSyncConnection.proxyDirective(remote,
          enabled: true, server: 'bad proxy'),
      isNull,
    );
  });

  test('握手超时会终止本次连接，而不是无限等待', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((_) {});
    try {
      final connection = RemoteSyncConnection(proxyResolver: (_) => null);
      await expectLater(
        connection.connect('ws://127.0.0.1:${server.port}/sync',
            timeout: const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
