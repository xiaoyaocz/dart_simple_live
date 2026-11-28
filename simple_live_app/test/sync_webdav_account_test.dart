import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/sync/remote_sync/room/remote_sync_room_controller.dart';
import 'package:simple_live_app/modules/sync/remote_sync/room/remote_sync_room_page.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/services/webdav_account_sync.dart';

class _TestBiliAccountService extends BiliBiliAccountService {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future loadUserInfo() async {}
}

class _TestWebDavController extends RemoteSyncWebDAVController {
  @override
  Future<void> checkIsLogin() async {
    notLogin.value = false;
  }
}

class _FakeSignalR extends SignalRService {
  final sent = <({String roomName, String action, bool overlay, String content})>[];

  @override
  Future<Resp> sendContent({
    required String roomName,
    required String action,
    required bool overlay,
    required String content,
  }) async {
    sent.add((
      roomName: roomName,
      action: action,
      overlay: overlay,
      content: content,
    ));
    return Resp(true, '', null);
  }
}

class _TestRemoteRoomController extends RemoteSyncRoomController {
  final _fakeSignalR = _FakeSignalR();

  _TestRemoteRoomController() : super('ABC123');

  @override
  SignalRService get signalR => _fakeSignalR;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onClose() {
    _fakeSignalR.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late LocalStorageService storage;
  late DBService db;
  late AppSettingsController settings;
  late _TestBiliAccountService bili;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync-webdav-account-');
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

  group('WebDavAccountSync 本地读写与应用', () {
    test('未配置时返回 null，应用凭据后写入并支持幂等与控制器刷新', () async {
      expect(WebDavAccountSync.readLocal(), isNull);
      expect(
        await WebDavAccountSync.applyLocal(const WebDavAccountPayload(
          uri: ' ',
          user: 'u',
          password: 'p',
        )),
        isFalse,
      );

      final webdavCtrl = Get.put<RemoteSyncWebDAVController>(
        _TestWebDavController(),
      ) as _TestWebDavController;
      expect(webdavCtrl.notLogin.value, isTrue);

      const payload = WebDavAccountPayload(
        uri: 'https://dav.jianguoyun.com/dav/',
        user: 'test@example.com',
        password: 'pw123',
        autoSync: true,
      );
      expect(await WebDavAccountSync.applyLocal(payload), isTrue);
      expect(await WebDavAccountSync.applyLocal(payload), isFalse);

      final local = WebDavAccountSync.readLocal()!;
      expect(local.uri, 'https://dav.jianguoyun.com/dav/');
      expect(local.user, 'test@example.com');
      expect(local.password, 'pw123');
      expect(local.autoSync, isTrue);
      expect(settings.webDavAutoSync.value, isTrue);
      expect(webdavCtrl.user.value, 'test@example.com');
      expect(webdavCtrl.notLogin.value, isFalse);
    });
  });

  group('RemoteSyncRoom 一键同步全部数据与 WebDAV 收发', () {
    test('syncAll 经现有4条通道一次性发送关注+标签、记录、屏蔽词+用户、B站和WebDAV账号', () async {
      final controller = _TestRemoteRoomController();
      addTearDown(controller.onClose);
      controller.roomUsers.assignAll([
        RoomUser.fromObject({'connectionId': 'self', 'isSelf': true}),
        RoomUser.fromObject({'connectionId': 'mobile', 'isSelf': false}),
      ]);

      await db.addFollow(FollowUser(
        id: 'huya_1',
        roomId: '1',
        siteId: 'huya',
        userName: '主播甲',
        face: '',
        addTime: DateTime(2026),
        tag: '游戏',
      ));
      final tag = await db.addFollowTag('游戏');
      await db.updateFollowTag(tag.copyWith(userId: ['huya_1']));
      await db.addOrUpdateHistory(History(
        id: 'huya_1',
        roomId: '1',
        siteId: 'huya',
        userName: '主播甲',
        face: '',
        updateTime: DateTime(2026, 11, 28),
      ));
      settings.addShieldList('广告');
      settings.addShieldUser('黑粉');
      bili.setCookie('SESSDATA=desktop;');
      await WebDavAccountSync.applyLocal(const WebDavAccountPayload(
        uri: 'https://dav.example.com/dav/',
        user: 'desk@example.com',
        password: 'desk-password',
        autoSync: true,
      ));

      await controller.syncAll();
      final sent = controller._fakeSignalR.sent;
      expect(sent.map((e) => e.action), [
        'SendFavorite',
        'SendHistory',
        'SendShieldWord',
        'SendBiliAccount',
      ]);

      final favPayload = jsonDecode(sent[0].content) as Map<String, dynamic>;
      expect((favPayload['follows'] as List).single['id'], 'huya_1');
      expect((favPayload['tags'] as List).single['tag'], '游戏');

      final shieldPayload = jsonDecode(sent[2].content) as Map<String, dynamic>;
      expect(shieldPayload['words'], ['广告']);
      expect(shieldPayload['users'], ['黑粉']);

      final accountPayload =
          jsonDecode(sent[3].content) as Map<String, dynamic>;
      expect(accountPayload['cookie'], 'SESSDATA=desktop;');
      expect(accountPayload['webdav'], {
        'uri': 'https://dav.example.com/dav/',
        'user': 'desk@example.com',
        'password': 'desk-password',
        'autoSync': true,
      });

      // 在另一台“手机端控制器”上回放收到的数据，完整还原全部本地状态
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

      await controller.onReceiveFavorite(false, sent[0].content);
      await controller.onReceiveHistory(false, sent[1].content);
      await controller.onReceiveShieldWord(false, sent[2].content);
      await controller.onReceiveBiliAccount(false, sent[3].content);

      expect(db.getFollowList().single.id, 'huya_1');
      expect(db.getFollowTagList().single.userId, ['huya_1']);
      expect(db.getHistores().single.id, 'huya_1');
      expect(settings.shieldList, contains('广告'));
      expect(settings.shieldUserList, contains('黑粉'));
      expect(bili.cookie, 'SESSDATA=desktop;');
      final mobileWebDav = WebDavAccountSync.readLocal()!;
      expect(mobileWebDav.uri, 'https://dav.example.com/dav/');
      expect(mobileWebDav.user, 'desk@example.com');
      expect(mobileWebDav.password, 'desk-password');
      expect(mobileWebDav.autoSync, isTrue);
    });

    test('未登录 B 站时也能单独同步 WebDAV 账号，且兼容旧版仅传 List/仅传 cookie', () async {
      final controller = _TestRemoteRoomController();
      addTearDown(controller.onClose);

      // 仅含 WebDAV、无 B站 cookie
      await controller.onReceiveBiliAccount(
        false,
        jsonEncode({
          'cookie': '',
          'webdav': {
            'uri': 'https://dav.only.com/dav/',
            'user': 'only@example.com',
            'password': 'pw',
            'autoSync': false,
          },
        }),
      );
      expect(bili.cookie, isEmpty);
      expect(WebDavAccountSync.readLocal()?.user, 'only@example.com');

      // 旧版仅传 B站 cookie，不清空已有的 WebDAV
      await controller.onReceiveBiliAccount(
        false,
        jsonEncode({'cookie': 'SESSDATA=legacy_only;'}),
      );
      expect(bili.cookie, 'SESSDATA=legacy_only;');
      expect(WebDavAccountSync.readLocal()?.user, 'only@example.com');

      // 旧版纯 List 关注和屏蔽词仍兼容
      await controller.onReceiveFavorite(
        false,
        jsonEncode([
          {
            'id': 'douyu_2',
            'roomId': '2',
            'siteId': 'douyu',
            'userName': '老版主播',
            'face': '',
            'addTime': DateTime(2026).toString(),
            'tag': '全部',
          }
        ]),
      );
      expect(db.getFollowList().single.id, 'douyu_2');

      await controller.onReceiveShieldWord(false, jsonEncode(['老版屏蔽词']));
      expect(settings.shieldList, contains('老版屏蔽词'));
    });

    testWidgets('RemoteSyncRoomPage 合并显示单一的一键同步入口', (tester) async {
      Get.put<RemoteSyncRoomController>(_TestRemoteRoomController());
      await tester.pumpWidget(
        const GetMaterialApp(home: RemoteSyncRoomPage()),
      );
      expect(find.text('一键同步全部数据'), findsOneWidget);
      expect(find.text('发送关注列表'), findsNothing);
      expect(find.text('发送观看记录'), findsNothing);
      expect(find.text('发送弹幕屏蔽词'), findsNothing);
      expect(find.text('发送哔哩哔哩账号'), findsNothing);
    });
  });
}
