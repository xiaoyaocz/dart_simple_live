import 'dart:async';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Sink implements WebSocketSink {
  int closes = 0;
  final sent = <dynamic>[];
  @override
  void add(dynamic data) => sent.add(data);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async { closes++; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Channel implements IOWebSocketChannel {
  final gate = Completer<void>();
  final messages = StreamController<dynamic>();
  @override
  final sink = _Sink();
  @override
  Future<void> get ready => gate.future;
  @override
  Stream<dynamic> get stream => messages.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('closing during handshake ignores late failure instead of retrying', () async {
    final channels = <_Channel>[];
    var closed = 0;
    final socket = WebScoketUtils(url: 'wss://primary.test', backupUrl: 'wss://backup.test', heartBeatTime: 1000,
      onClose: (_) => closed++, connectChannel: (_, __) { final channel = _Channel(); channels.add(channel); return channel; });
    addTearDown(socket.close);
    socket.connect();
    socket.close();
    channels.first.gate.completeError(StateError('late handshake failure'));
    await flush();
    expect(channels, hasLength(1));
    expect(socket.status, SocketStatus.closed);
    expect(closed, 0);
    expect(socket.reconnectTimer, isNull);
  });
  test('closing during handshake ignores late success without timers or callbacks', () async {
    final channel = _Channel(); var ready = 0;
    final socket = WebScoketUtils(url: 'wss://primary.test', heartBeatTime: 1000,
      onReady: () => ready++, connectChannel: (_, __) => channel);
    addTearDown(socket.close);
    socket.connect(); socket.close(); channel.gate.complete();
    await flush();
    expect(socket.status, SocketStatus.closed);
    expect(ready, 0);
    expect(socket.heartBeatTimer, isNull);
    expect(channel.messages.hasListener, isFalse);
  });
  test('superseded handshake cannot attach listeners to the newer socket', () async {
    final channels = <_Channel>[]; var ready = 0;
    final socket = WebScoketUtils(url: 'wss://primary.test', heartBeatTime: 1000,
      onReady: () => ready++, connectChannel: (_, __) { final channel = _Channel(); channels.add(channel); return channel; });
    addTearDown(socket.close);
    socket.connect(); socket.connect();
    channels.first.gate.complete(); await flush();
    expect(ready, 0);
    expect(channels.last.messages.hasListener, isFalse);
    channels.last.gate.complete(); await flush();
    expect(ready, 1);
    expect(channels.last.messages.hasListener, isTrue);
  });
  test('onReady may close synchronously without starting a heartbeat', () async {
    final channel = _Channel(); late WebScoketUtils socket;
    socket = WebScoketUtils(url: 'wss://primary.test', heartBeatTime: 1000,
      onReady: () => socket.close(), connectChannel: (_, __) => channel);
    addTearDown(socket.close);
    socket.connect(); channel.gate.complete(); await flush();
    expect(socket.status, SocketStatus.closed);
    expect(socket.heartBeatTimer, isNull);
  });
  test('primary failure still tries backup and delivers active messages', () async {
    final channels = <_Channel>[]; final urls = <String>[]; final messages = <dynamic>[];
    final socket = WebScoketUtils(url: 'wss://primary.test', backupUrl: 'wss://backup.test', heartBeatTime: 1000,
      onMessage: messages.add, connectChannel: (url, _) { urls.add(url); final channel = _Channel(); channels.add(channel); return channel; });
    addTearDown(socket.close);
    socket.connect(); channels.first.gate.completeError(StateError('primary failed')); await flush();
    expect(urls, ['wss://primary.test', 'wss://backup.test']);
    channels.last.gate.complete(); await flush();
    channels.last.messages.add('message'); await flush();
    expect(messages, ['message']);
    expect(socket.status, SocketStatus.connected);
    expect(socket.heartBeatTimer?.isActive, isTrue);
  });
}
