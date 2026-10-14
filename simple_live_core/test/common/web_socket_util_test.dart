import 'dart:async';
import 'dart:io';

import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  group('WebScoketUtils', () {
    test('retries failed handshakes and stops at maxReconnectTime', () async {
      var attempts = 0;
      var reconnects = 0;
      final stopped = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        attempts++;
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      final socket = WebScoketUtils(
        url: 'ws://${server.address.host}:${server.port}',
        heartBeatTime: 60000,
        reconnectDelay: const Duration(milliseconds: 10),
        onReconnect: () => reconnects++,
        onClose: (message) {
          if (message.contains('最大次数') && !stopped.isCompleted) {
            stopped.complete();
          }
        },
      )..maxReconnectTime = 3;
      addTearDown(socket.close);

      socket.connect();
      await stopped.future.timeout(const Duration(seconds: 1));

      expect(attempts, 4); // Initial attempt plus three reconnect attempts.
      expect(reconnects, 3);
      expect(socket.status, SocketStatus.closed);
    });

    test('onError enters the same controlled retry path', () async {
      final server = await _WebSocketServer.start();
      addTearDown(server.close);
      var attempts = 0;
      final ready = Completer<void>();
      final reconnected = Completer<void>();
      final socket = WebScoketUtils(
        url: server.url,
        heartBeatTime: 60000,
        reconnectDelay: const Duration(milliseconds: 10),
        webSocketConnector: (url, {connectTimeout, headers}) {
          attempts++;
          if (attempts == 1) return IOWebSocketChannel.connect(url);
          throw const SocketException('retry reached');
        },
        onReconnect: () {
          if (!reconnected.isCompleted) reconnected.complete();
        },
        onReady: ready.complete,
      );
      addTearDown(socket.close);

      socket.connect();
      await ready.future.timeout(const Duration(seconds: 1));
      socket.onError(
        const SocketException('stream failed'),
        StackTrace.current,
      );
      await reconnected.future.timeout(const Duration(seconds: 1));

      expect(attempts, greaterThanOrEqualTo(2));
    });

    test(
      'falls back to backup address before scheduling a reconnect',
      () async {
        final server = await _WebSocketServer.start();
        addTearDown(server.close);
        final tried = <String>[];
        final ready = Completer<void>();
        final socket = WebScoketUtils(
          url: 'ws://primary.invalid',
          backupUrl: server.url,
          heartBeatTime: 60000,
          webSocketConnector: (url, {connectTimeout, headers}) {
            tried.add(url);
            if (url.contains('primary')) {
              throw const SocketException('primary failed');
            }
            return IOWebSocketChannel.connect(url);
          },
          onReady: ready.complete,
        );
        addTearDown(socket.close);

        socket.connect();
        await ready.future.timeout(const Duration(seconds: 1));

        expect(tried, ['ws://primary.invalid', server.url]);
        expect(socket.status, SocketStatus.connected);
        expect(socket.reconnectTime, 0);
      },
    );

    test('a connection completed after close cannot become ready', () async {
      final server = await _WebSocketServer.start();
      addTearDown(server.close);
      final releaseConnection = Completer<void>();
      var readyCalls = 0;
      final socket = WebScoketUtils(
        url: server.url,
        heartBeatTime: 60000,
        webSocketConnector: (url, {connectTimeout, headers}) async {
          await releaseConnection.future;
          return IOWebSocketChannel.connect(url);
        },
        onReady: () => readyCalls++,
      );

      socket.connect();
      socket.close();
      releaseConnection.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(readyCalls, 0);
      expect(socket.status, SocketStatus.closed);
      expect(socket.webSocket, isNull);
    });

    test('a new explicit connect supersedes an in-flight connection', () async {
      final server = await _WebSocketServer.start();
      addTearDown(server.close);
      final releaseFirstConnection = Completer<void>();
      var attempts = 0;
      var readyCalls = 0;
      final ready = Completer<void>();
      final socket = WebScoketUtils(
        url: server.url,
        heartBeatTime: 60000,
        webSocketConnector: (url, {connectTimeout, headers}) async {
          attempts++;
          if (attempts == 1) await releaseFirstConnection.future;
          return IOWebSocketChannel.connect(url);
        },
        onReady: () {
          readyCalls++;
          if (!ready.isCompleted) ready.complete();
        },
      );
      addTearDown(socket.close);

      socket.connect();
      socket.connect();
      await ready.future.timeout(const Duration(seconds: 1));
      releaseFirstConnection.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(attempts, 2);
      expect(readyCalls, 1);
      expect(socket.status, SocketStatus.connected);
    });
  });
}

class _WebSocketServer {
  _WebSocketServer(this._server) {
    _server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      if (!connected.isCompleted) connected.complete();
    });
  }

  final HttpServer _server;
  final List<WebSocket> _clients = [];
  final Completer<void> connected = Completer<void>();

  String get url => 'ws://${_server.address.host}:${_server.port}';

  static Future<_WebSocketServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _WebSocketServer(server);
  }

  Future<void> close() async {
    for (final client in _clients) {
      await client.close();
    }
    await _server.close(force: true);
  }
}
