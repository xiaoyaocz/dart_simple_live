import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/remote_sync_connection.dart';
import 'package:simple_live_app/services/sync_service.dart';

void main() {
  group('SyncService 地址与端口格式化', () {
    test('默认端口 23234 不附加端口，回退端口自动附带端口号', () {
      final service = SyncService();
      service.ipAddress.value = '192.168.1.10;10.0.0.2';
      service.serverPort.value = SyncService.httpPort;
      expect(service.qrAddress, '192.168.1.10;10.0.0.2');

      service.serverPort.value = 23236;
      expect(service.qrAddress, '192.168.1.10:23236;10.0.0.2:23236');
    });
  });

  group('SyncClientRequest 局域网直连推拉协议', () {
    late HttpServer server;
    late SyncClinet client;
    late SyncClientRequest request;
    final storedFollows = <Map<String, dynamic>>[];
    final storedWords = <String>[];
    final storedUsers = <String>[];
    String storedBiliCookie = '';

    setUp(() async {
      storedFollows.clear();
      storedWords.clear();
      storedUsers.clear();
      storedBiliCookie = '';

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final path = req.uri.path;
        final method = req.method;
        Future<void> sendJson(int status, Object body) async {
          req.response.statusCode = status;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode(body));
          await req.response.close();
        }

        if (method == 'GET' && path == '/info') {
          await sendJson(200, {
            'id': 'peer-1',
            'type': 'android',
            'name': 'TestPhone',
            'version': '2.0.25',
            'address': server.address.address,
            'port': server.port,
            'app': 'simplelive',
          });
          return;
        }
        if (method == 'POST' && path == '/sync/follow') {
          final body = await utf8.decoder.bind(req).join();
          final list = (jsonDecode(body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          var added = 0;
          var updated = 0;
          for (final item in list) {
            final idx = storedFollows.indexWhere((e) => e['id'] == item['id']);
            if (idx == -1) {
              storedFollows.add(item);
              added++;
            } else {
              storedFollows[idx] = item;
              updated++;
            }
          }
          await sendJson(200, {
            'status': true,
            'message': 'success',
            'added': added,
            'updated': updated,
            'total': storedFollows.length,
          });
          return;
        }
        if (method == 'GET' && path == '/sync/follow') {
          await sendJson(200, {
            'status': true,
            'data': storedFollows,
          });
          return;
        }
        if (method == 'POST' && path == '/sync/blocked_word') {
          final body = await utf8.decoder.bind(req).join();
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            storedWords
              ..clear()
              ..addAll((decoded['words'] as List).cast<String>());
            storedUsers
              ..clear()
              ..addAll((decoded['users'] as List).cast<String>());
          }
          await sendJson(200, {'status': true, 'message': 'success'});
          return;
        }
        if (method == 'GET' && path == '/sync/blocked_word') {
          await sendJson(200, {
            'status': true,
            'data': storedWords,
            'users': storedUsers,
          });
          return;
        }
        if (method == 'POST' && path == '/sync/account/bilibili') {
          final body = await utf8.decoder.bind(req).join();
          final map = jsonDecode(body) as Map;
          storedBiliCookie = map['cookie']?.toString() ?? '';
          await sendJson(200, {'status': true, 'message': 'success'});
          return;
        }
        if (method == 'GET' && path == '/sync/account/bilibili') {
          await sendJson(200, {
            'status': true,
            'cookie': storedBiliCookie,
          });
          return;
        }
        await sendJson(404, {'status': false, 'message': 'not found'});
      });

      client = SyncClinet(
        id: 'peer-1',
        name: 'TestPhone',
        address: server.address.address,
        port: server.port,
        type: 'android',
      );
      request = SyncClientRequest();
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('支持 info 查询及关注/屏蔽词+用户/B站账号双向推拉', () async {
      final info = await request.getClientInfo(client);
      expect(info.name, 'TestPhone');
      expect(info.type, 'android');

      final pushRes = await request.syncFollow(client, [
        {'id': 'bilibili_1', 'roomId': '1', 'siteId': 'bilibili', 'userName': 'A'},
      ]);
      expect(pushRes['added'], 1);
      expect(pushRes['total'], 1);

      final pulledFollows = await request.fetchFollow(client);
      expect(pulledFollows, hasLength(1));
      expect(pulledFollows.first['userName'], 'A');

      await request.syncBlockedWord(client, {
        'words': ['广告', '/刷屏/i'],
        'users': ['喷子甲'],
      });
      final pulledShield = await request.fetchBlockedWord(client);
      expect(pulledShield['data'], ['广告', '/刷屏/i']);
      expect(pulledShield['users'], ['喷子甲']);

      await request.syncBiliAccount(client, 'SESSDATA=abc123;');
      expect(await request.fetchBiliAccount(client), 'SESSDATA=abc123;');
    });

    test('对端旧版本缺少拉取接口返回 404 时给出明确中文提示', () async {
      await expectLater(
        () => request.fetchHistory(client),
        throwsA(contains('对端版本不支持该操作')),
      );
    });
  });

  group('RemoteSyncConnection 代理与回环直连策略', () {
    test('回环地址始终直连，非回环地址可经代理并在代理不可用时回退', () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin.transform(WebSocketTransformer()).listen((ws) => ws.close());
      var proxyHits = 0;
      final trap = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      trap.listen((req) {
        proxyHits++;
        req.response.statusCode = 502;
        req.response.close();
      });
      addTearDown(() async {
        await origin.close(force: true);
        await trap.close(force: true);
      });

      final connection = RemoteSyncConnection(
        proxyResolver: (_) => 'PROXY 127.0.0.1:${trap.port}',
      );
      final socket = await connection.connect(
        'ws://127.0.0.1:${origin.port}/',
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
      expect(proxyHits, 0);
    });
  });
}
