import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';

void main() {
  test('sync server probe measures a WebSocket ping/pong round trip', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.transform(WebSocketTransformer()).listen((socket) {
      socket.listen((event) {
        final message = json.decode(event as String) as Map<String, dynamic>;
        if (message['type'] == 'ping') {
          socket.add(json.encode({
            'type': 'pong',
            'requestId': message['requestId'],
          }));
        }
      });
    });

    final result = await SignalRService.probeServer(
      'ws://127.0.0.1:${server.port}',
      forceDirect: true,
    );

    expect(result.isReachable, isTrue);
    expect(result.latencyMs, isNotNull);
    expect(result.label, endsWith(' ms'));
  });
}
