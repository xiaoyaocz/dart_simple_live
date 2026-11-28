import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/douyu_native_sender.dart';

class _Http implements HttpClientAdapter {
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async {
    await gate?.future;
    final data = o.uri.path.contains('getEncryption')
        ? {
            'rand_str': 'nonce',
            'enc_time': 2,
            'cpp': {
              'danmu': {'key': 'key', 'key_ver': 'version'},
              'heartbeat': {'key': 'heartbeat', 'key_ver': 'version'}
            }
          }
        : {
            'wss': [
              {'domain': 'wsproxy.douyu.com', 'port': 6673}
            ]
          };
    return ResponseBody.fromString(jsonEncode({'error': 0, 'data': data}), 200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('nested repeater list opens authenticated receiving connection',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final receivingLogin = Completer<Map<String, String>>();
    final listener = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      final gateway = sockets.length == 1;
      final frames = DouyuFrames();
      socket.listen((bytes) {
        for (final msg in frames.add(bytes as List<int>)) {
          if (msg['type'] == 'loginreq' && gateway) {
            socket.add(DouyuFrames.encode(
                {'type': 'loginres', 'userid': '123', 'username': 'account'}));
          } else if (msg['type'] == 'livreq') {
            socket.add(DouyuFrames.encode(
                {'type': 'livres', 'nonce': 'nonce', 'its': '2'}));
            socket.add(DouyuFrames.encode({
              'type': 'msgrepeaterproxylist',
              'list': 'host@A=danmuproxy.douyu.com@Sport@A=8506@S/'
            }));
          } else if (msg['type'] == 'loginreq' && !gateway) {
            receivingLogin.complete(msg);
          }
        }
      });
    });
    final sender = DouyuNativeSender(
      roomId: '1',
      dio: Dio()..httpClientAdapter = _Http(),
      credentials: (_) async =>
          {'acf_username': 'account', 'acf_dmjwt_token': 'token'},
      connect: (uri, _) {
        if (uri.host == 'danmuproxy.douyu.com') expect(uri.port, 8506);
        return WebSocket.connect('ws://127.0.0.1:${server.port}');
      },
    );
    try {
      expect((await sender.checkReady()).status, 'ready');
      final login =
          await receivingLogin.future.timeout(const Duration(seconds: 1));
      expect(login['username'], 'account');
      expect(login['uid'], '123');
      expect(login['roomid'], '1');
    } finally {
      await sender.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await listener.cancel();
      await server.close(force: true);
    }
  });
  test(
      'logout during warmup prevents late connection with previous credentials',
      () async {
    var loggedIn = true, attempts = 0;
    final gate = Completer<void>();
    final sender = DouyuNativeSender(
        roomId: '1',
        dio: Dio()..httpClientAdapter = (_Http()..gate = gate),
        credentials: (_) async => loggedIn
            ? {'acf_username': 'account', 'acf_dmjwt_token': 'token'}
            : {},
        connect: (_, __) async {
          attempts++;
          throw StateError('Must not connect after logout');
        });
    sender.prepare();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    loggedIn = false;
    expect((await sender.send('x')).status, 'login');
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(attempts, 0);
    await sender.dispose();
  });
  test(
      'STT uses byte lengths, escapes once and handles fragmented/combined frames',
      () {
    const fields = {
      'type': 'chatmessage',
      'content': '你好👋/@A=',
      'sender': '123'
    };
    final bytes = DouyuFrames.encode(fields);
    expect(ByteData.sublistView(bytes).getUint32(0, Endian.little),
        bytes.length - 4);
    final decoder = DouyuFrames();
    expect(decoder.add(bytes.sublist(0, 9)), isEmpty);
    expect(decoder.add([...bytes.sublist(9), ...bytes]), [fields, fields]);
    expect(() => decoder.add(List.filled(12, 255)), throwsFormatException);
  });
  test('official challenge signature matches iterative MD5 construction', () {
    String digest(String v) => md5.convert(utf8.encode(v)).toString();
    expect(
        DouyuNativeSender.challenge(
            key: 'key',
            nonce: 'nonce',
            rounds: 2,
            roomId: '1',
            deviceId: 'did',
            timestamp: 100),
        digest('${digest('${digest('noncekey')}key')}key1did100'));
  });
  test(
      'authenticated persistent connection, no send during warmup, account refresh and exact echo',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final sent = <Map<String, String>>[];
    var connections = 0;
    final listener = server.listen((r) async {
      final socket = await WebSocketTransformer.upgrade(r);
      sockets.add(socket);
      connections++;
      final frames = DouyuFrames();
      socket.listen((b) {
        for (final msg in frames.add(b as List<int>)) {
          sent.add(msg);
          if (msg['type'] == 'loginreq') {
            socket.add(DouyuFrames.encode({
              'type': 'loginres',
              'userid': '123',
              'username': 'account',
              'npv': '0',
              'ps': '1'
            }));
          } else if (msg['type'] == 'livreq') {
            socket.add(DouyuFrames.encode(
                {'type': 'livres', 'nonce': 'nonce', 'its': '2'}));
          } else if (msg['type'] == 'chatmessage') {
            if (msg['content'] == 'timeout') continue;
            if (msg['content'] == 'blocked') {
              socket.add(DouyuFrames.encode({'type': 'chatres', 'res': '308'}));
              continue;
            }
            if (msg['content'] == 'accepted') {
              socket.add(DouyuFrames.encode({'type': 'chatres', 'res': '0'}));
              continue;
            }
            // A different user's matching message must not confirm this request.
            socket.add(DouyuFrames.encode(
                {'type': 'chatmsg', 'uid': '999', 'txt': msg['content']!}));
            // Even our own matching text from an old transaction is not its ACK.
            socket.add(DouyuFrames.encode({
              'type': 'chatmsg',
              'uid': '123',
              'txt': msg['content']!,
              'cst': 'old'
            }));
            Timer(
                const Duration(milliseconds: 20),
                () => socket.add(DouyuFrames.encode({
                      'type': 'chatmsg',
                      'uid': '123',
                      'txt': msg['content']!,
                      'cst': msg['cst']!
                    })));
          } else if (msg['type'] == 'keeplive') {
            socket.add(DouyuFrames.encode({
              'type': 'keeplive',
              'nonce': 'rotated',
              'its': '3',
              'kd': 'new-kd'
            }));
          }
        }
      });
    });
    var auth = 'first';
    final sender = DouyuNativeSender(
        roomId: '85200',
        dio: Dio()..httpClientAdapter = _Http(),
        credentials: (_) async => {
              'acf_username': 'account',
              'acf_auth_wl': auth,
              'acf_did': 'login-device',
              'dy_did': 'tracking-device'
            },
        connect: (uri, headers) {
          expect(uri.scheme, 'wss');
          expect(uri.host, 'wsproxy.douyu.com');
          return WebSocket.connect('ws://127.0.0.1:${server.port}');
        });
    try {
      sender.prepare();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sent.where((m) => m['type'] == 'chatmessage'), isEmpty);
      expect((await sender.send('你好/@')).sent, isTrue);
      expect((await sender.send('second')).sent, isTrue);
      expect(connections, 1);
      expect(sent.where((m) => m['type'] == 'lsigreq').length, 1);
      expect(sent.firstWhere((m) => m['type'] == 'loginreq')['devid'],
          'login-device');
      expect(sent.firstWhere((m) => m['type'] == 'chatmessage')['dy'],
          'tracking-device');
      sender.heartbeat();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      sender.heartbeat();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final beats = sent.where((m) => m['type'] == 'keeplive').toList();
      expect(beats.length, 2);
      expect(
          beats.last['sig'],
          DouyuNativeSender.challenge(
              key: 'heartbeat',
              nonce: 'rotated',
              rounds: 3,
              roomId: '85200',
              deviceId: 'login-device',
              timestamp: int.parse(beats.last['tick']!)));
      auth = 'new-account-token';
      expect((await sender.send('third')).sent, isTrue);
      expect(connections, 2);
      expect(sent.where((m) => m['type'] == 'chatmessage').length, 3);
      expect((await sender.send('accepted')).status, 'sent',
          reason:
              'An explicit success reply on our isolated sending connection is a platform ACK');
      expect((await sender.send('blocked')).status, 'rejected');
      expect((await sender.send('timeout')).status, 'unknown');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(sockets.last.readyState, WebSocket.closed,
          reason: 'An unknown transaction must not leave a stale ACK source');
      final beforeRepeat=sent.where((m)=>m['type']=='chatmessage').length;
      expect((await sender.send('timeout')).status,'unknown');
      expect(sent.where((m)=>m['type']=='chatmessage').length,beforeRepeat,
          reason:'Uncertain text must not be submitted again');
      expect((await sender.send('accepted')).status, 'sent');
      expect(connections, 3);
      await sender.dispose();
      expect((await sender.send('closed')).status, 'closed');
    } finally {
      await sender.dispose();
      for (final s in sockets) {
        await s.close();
      }
      await listener.cancel();
      await server.close(force: true);
    }
  });
}
