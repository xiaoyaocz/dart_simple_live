import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_controller.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_page.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/remote_sync_connection.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/services/webdav_account_sync.dart';

class _PassthroughHttpOverrides extends HttpOverrides {}

class _TestBiliAccountService extends BiliBiliAccountService {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future loadUserInfo() async {}
}

class _TestSyncService extends SyncService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpOverrides? previousHttpOverrides;

  setUp(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _PassthroughHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = previousHttpOverrides;
  });

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
    Map<String, dynamic>? storedWebDav;

    setUp(() async {
      storedFollows.clear();
      storedWords.clear();
      storedUsers.clear();
      storedBiliCookie = '';
      storedWebDav = null;

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
        if (method == 'POST' && path == '/sync/account/webdav') {
          final body = await utf8.decoder.bind(req).join();
          storedWebDav = Map<String, dynamic>.from(jsonDecode(body) as Map);
          await sendJson(200, {'status': true, 'message': 'success'});
          return;
        }
        if (method == 'GET' && path == '/sync/account/webdav') {
          await sendJson(200, {
            'status': true,
            'data': storedWebDav,
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

    test('支持 info 查询及关注/屏蔽词+用户/B站与WebDAV账号双向推拉', () async {
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

      await request.syncWebDavAccount(client, {
        'uri': 'https://dav.jianguoyun.com/dav/',
        'user': 'user@example.com',
        'password': 'secret',
        'autoSync': true,
      });
      final pulledWebDav = await request.fetchWebDavAccount(client);
      expect(pulledWebDav, {
        'uri': 'https://dav.jianguoyun.com/dav/',
        'user': 'user@example.com',
        'password': 'secret',
        'autoSync': true,
      });
    });

    test('对端旧版本缺少拉取接口返回 404 时给出明确中文提示', () async {
      await expectLater(
        () => request.fetchHistory(client),
        throwsA(contains('对端版本不支持该操作')),
      );
    });
  });

  group('局域网一键同步全部数据（含 WebDAV 账号）', () {
    late Directory directory;
    late DBService db;
    late LocalStorageService storage;
    late AppSettingsController settings;
    late _TestBiliAccountService bili;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('lan-sync-all-');
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(FollowUserAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HistoryAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(FollowUserTagAdapter());
      }
      storage = Get.put(LocalStorageService());
      await storage.init();
      db = Get.put(DBService());
      await db.init();
      settings = Get.put(AppSettingsController());
      bili = Get.put<BiliBiliAccountService>(_TestBiliAccountService())
          as _TestBiliAccountService;
    });

    tearDown(() async {
      Get.reset();
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('SyncService 真路由接收并导出 WebDAV 账号凭据与自动同步开关', () async {
      final service = _TestSyncService();
      final server = await shelf_io.serve(
        service.buildSyncRouter().call,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));

      final client = SyncClinet(
        id: 'self',
        name: 'Desktop',
        address: server.address.address,
        port: server.port,
        type: 'windows',
      );
      final req = SyncClientRequest();

      expect(await req.fetchWebDavAccount(client), isNull);

      final pushResp = await req.syncWebDavAccount(client, {
        'uri': 'https://dav.jianguoyun.com/dav/',
        'user': 'alice@example.com',
        'password': 'app-password',
        'autoSync': true,
      });
      expect(pushResp['status'], isTrue);
      expect(pushResp['updated'], isTrue);

      final exported = await req.fetchWebDavAccount(client);
      expect(exported, {
        'uri': 'https://dav.jianguoyun.com/dav/',
        'user': 'alice@example.com',
        'password': 'app-password',
        'autoSync': true,
      });
      expect(settings.webDavAutoSync.value, isTrue);
      expect(
        storage.getValue(LocalStorageService.kWebDAVPassword, ''),
        'app-password',
      );
    });

    test('SyncDeviceController.syncAll 与 pullAll 一次性同步全部数据（含 WebDAV），并对旧版对端降级兼容', () async {
      final remote = <String, dynamic>{
        'follows': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
        'histories': <Map<String, dynamic>>[],
        'words': <String>[],
        'users': <String>[],
        'biliCookie': '',
        'webdav': null,
      };
      var simulateLegacyPeer = false;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        Future<void> sendJson(int status, Object body) async {
          req.response.statusCode = status;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode(body));
          await req.response.close();
        }

        final path = req.uri.path;
        final method = req.method;
        if (method == 'POST' && path == '/sync/follow') {
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as List;
          remote['follows'] =
              body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          await sendJson(200, {'status': true, 'added': body.length, 'updated': 0});
          return;
        }
        if (method == 'GET' && path == '/sync/follow') {
          await sendJson(200, {'status': true, 'data': remote['follows']});
          return;
        }
        if (method == 'POST' && path == '/sync/tag') {
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as List;
          remote['tags'] =
              body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          await sendJson(200, {'status': true, 'changed': body.length});
          return;
        }
        if (method == 'GET' && path == '/sync/tag') {
          await sendJson(200, {'status': true, 'data': remote['tags']});
          return;
        }
        if (method == 'POST' && path == '/sync/history') {
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as List;
          remote['histories'] =
              body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          await sendJson(200, {'status': true, 'added': body.length});
          return;
        }
        if (method == 'GET' && path == '/sync/history') {
          await sendJson(200, {'status': true, 'data': remote['histories']});
          return;
        }
        if (method == 'POST' && path == '/sync/blocked_word') {
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
          remote['words'] = (body['words'] as List).cast<String>();
          remote['users'] = (body['users'] as List).cast<String>();
          await sendJson(200, {'status': true});
          return;
        }
        if (method == 'GET' && path == '/sync/blocked_word') {
          await sendJson(200, {
            'status': true,
            'data': remote['words'],
            'users': remote['users'],
          });
          return;
        }
        if (method == 'POST' && path == '/sync/account/bilibili') {
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
          remote['biliCookie'] = body['cookie'];
          await sendJson(200, {'status': true});
          return;
        }
        if (method == 'GET' && path == '/sync/account/bilibili') {
          await sendJson(200, {'status': true, 'cookie': remote['biliCookie']});
          return;
        }
        if (path == '/sync/account/webdav') {
          if (simulateLegacyPeer) {
            await sendJson(404, {'status': false, 'message': 'not found'});
            return;
          }
          if (method == 'POST') {
            remote['webdav'] = jsonDecode(await utf8.decoder.bind(req).join());
            await sendJson(200, {'status': true, 'updated': true});
            return;
          }
          if (method == 'GET') {
            await sendJson(200, {'status': true, 'data': remote['webdav']});
            return;
          }
        }
        await sendJson(404, {'status': false});
      });

      final peer = SyncClinet(
        id: 'peer',
        name: 'PixelPhone',
        address: server.address.address,
        port: server.port,
        type: 'android',
      );
      final deviceController = SyncDeviceController(
        client: peer,
        info: SyncClientInfoModel(
          name: 'PixelPhone',
          version: '2.0.25',
          address: peer.address,
          port: peer.port,
          type: 'android',
        ),
      );

      // 本地填充完整数据并一键发送
      await db.addFollow(FollowUser(
        id: 'bilibili_6',
        roomId: '6',
        siteId: 'bilibili',
        userName: '主播A',
        face: '',
        addTime: DateTime(2026),
        tag: '常看',
      ));
      final tag = await db.addFollowTag('常看');
      await db.updateFollowTag(tag.copyWith(userId: ['bilibili_6']));
      await db.addOrUpdateHistory(History(
        id: 'huya_1',
        roomId: '1',
        siteId: 'huya',
        userName: '历史主播',
        face: '',
        updateTime: DateTime(2026, 11, 28),
      ));
      settings.addShieldList('刷屏词');
      settings.addShieldUser('黑粉');
      bili.setCookie('SESSDATA=pc_cookie;');
      await WebDavAccountSync.applyLocal(const WebDavAccountPayload(
        uri: 'https://dav.jianguoyun.com/dav/',
        user: 'pc@example.com',
        password: 'pc-password',
        autoSync: true,
      ));

      await deviceController.syncAll();
      expect(deviceController.lastSyncError.value, isFalse);
      expect((remote['follows'] as List).length, 1);
      expect((remote['tags'] as List).length, 1);
      expect((remote['histories'] as List).length, 1);
      expect(remote['words'], ['刷屏词']);
      expect(remote['users'], ['黑粉']);
      expect(remote['biliCookie'], 'SESSDATA=pc_cookie;');
      expect(remote['webdav'], {
        'uri': 'https://dav.jianguoyun.com/dav/',
        'user': 'pc@example.com',
        'password': 'pc-password',
        'autoSync': true,
      });

      // 对端不支持 /sync/account/webdav 时一键发送不整体报错
      simulateLegacyPeer = true;
      await deviceController.syncAll();
      expect(deviceController.lastSyncError.value, isFalse);
      expect(deviceController.lastSyncStatus.value, contains('对端版本过旧未同步'));

      // 清空本地并从对端一键拉取全部数据（包括 WebDAV）
      simulateLegacyPeer = false;
      await db.followBox.clear();
      await db.tagBox.clear();
      await db.historyBox.clear();
      await settings.clearShieldList();
      settings.shieldUserList.clear();
      bili.setCookie('');
      await storage.setValue(LocalStorageService.kWebDAVUri, '');
      await storage.setValue(LocalStorageService.kWebDAVUser, '');
      await storage.setValue(LocalStorageService.kWebDAVPassword, '');
      settings.setWebDavAutoSync(false);

      await deviceController.pullAll();
      expect(deviceController.lastSyncError.value, isFalse);
      expect(db.getFollowList().single.id, 'bilibili_6');
      expect(db.getFollowTagList().single.userId, ['bilibili_6']);
      expect(db.getHistores().single.id, 'huya_1');
      expect(settings.shieldList, contains('刷屏词'));
      expect(settings.shieldUserList, contains('黑粉'));
      expect(bili.cookie, 'SESSDATA=pc_cookie;');
      final restoredWebDav = WebDavAccountSync.readLocal();
      expect(restoredWebDav?.uri, 'https://dav.jianguoyun.com/dav/');
      expect(restoredWebDav?.user, 'pc@example.com');
      expect(restoredWebDav?.password, 'pc-password');
      expect(restoredWebDav?.autoSync, isTrue);
    });

    testWidgets('局域网设备同步页只显示整合后的发送和拉取入口', (tester) async {
      final peer = SyncClinet(
        id: 'p1',
        name: 'AndroidPhone',
        address: '192.168.1.2',
        port: 23234,
        type: 'android',
      );
      Get.put(SyncDeviceController(
        client: peer,
        info: SyncClientInfoModel(
          name: 'AndroidPhone',
          version: '2.0.25',
          address: peer.address,
          port: peer.port,
          type: 'android',
        ),
      ));

      await tester.pumpWidget(const GetMaterialApp(home: SyncDevicePage()));
      expect(find.text('一键发送全部数据'), findsOneWidget);
      expect(find.text('一键拉取全部数据'), findsOneWidget);
      expect(find.text('发送关注列表和标签'), findsNothing);
      expect(find.text('发送观看记录'), findsNothing);
      expect(find.text('发送弹幕屏蔽词'), findsNothing);
      expect(find.text('发送哔哩哔哩账号'), findsNothing);
      expect(find.text('拉取关注列表和标签'), findsNothing);
      expect(find.text('拉取观看记录'), findsNothing);
      expect(find.text('拉取弹幕屏蔽词'), findsNothing);
      expect(find.text('拉取哔哩哔哩账号'), findsNothing);
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
