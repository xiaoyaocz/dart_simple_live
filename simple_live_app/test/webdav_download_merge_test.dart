import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';

import 'webdav_merge_upload_test.dart' as fixture;

class _Settings extends AppSettingsController {
  @override
  // Keep the real settings model without application startup side effects.
  // ignore: must_call_super
  void onInit() {}
}

class _Account extends BiliBiliAccountService {
  @override
  // No remote account lookups in a local sync test.
  // ignore: must_call_super
  void onInit() {}
}

class _Dav implements DAVClient {
  late List<int> bytes;
  Completer<List<int>>? readGate;
  Object? uploadError;
  var reads = 0;
  var uploads = 0;
  @override
  Future<List<int>> recovery() async {
    reads++;
    if (readGate != null) return await readGate!.future;
    return bytes;
  }

  @override
  Future<bool> backup(Uint8List data) async {
    uploads++;
    if (uploadError != null) throw uploadError!;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late DBService db;
  late RemoteSyncWebDAVController controller;
  late _Dav dav;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('webdav-merge-test-');
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FollowUserAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(FollowUserTagAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HistoryAdapter());
    db = Get.put(DBService());
    await db.init();
    final storage = Get.put(LocalStorageService());
    await storage.init();
    Get.put<AppSettingsController>(_Settings());
    Get.put<BiliBiliAccountService>(_Account());
    dav = _Dav();
    controller = RemoteSyncWebDAVController()..davClient = dav;
  });
  tearDown(() async {
    await Hive.close();
    Get.reset();
    await temp.delete(recursive: true);
  });

  testWidgets('下载仅补充未关注用户，排序后的整数标签key不造成重复且新成员追加末尾', (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: SizedBox())));
    await tester.runAsync(() async {
      final local =
          FollowUser.fromJson(fixture.user('huya_1', '保留', tag: '分组'));
      final second =
          FollowUser.fromJson(fixture.user('huya_2', '第二', tag: '分组'));
      await db.followBox.putAll({local.id: local, second.id: second});
      final original = FollowUserTag(
          id: 'local-tag', tag: '分组', userId: ['huya_2', 'huya_1']);
      await db.tagBox.put(0, original);
      dav.bytes = fixture.zip({
        fixture.follows: fixture.data([
          fixture.user('huya_1', '不能覆盖', tag: '别组'),
          fixture.user('huya_3', '新增', tag: '分组')
        ]),
        fixture.tags: fixture.data([
          fixture.tag('phone-tag', '分组', ['huya_1', 'huya_3'])
        ])
      });
      await controller.doWebDAVRecovery();
      expect(db.followBox.get(local.id), same(local));
      expect(local.userName, '保留');
      expect(local.tag, '分组');
      expect(db.getFollowList().map((user) => user.id),
          ['huya_1', 'huya_2', 'huya_3']);
      expect(db.tagBox.length, 1);
      expect(db.tagBox.keys, [0]);
      expect(db.tagBox.get(0)!.id, 'local-tag');
      expect(db.tagBox.get(0)!.userId, ['huya_2', 'huya_1', 'huya_3']);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    SmartDialog.dismiss(status: SmartStatus.allToast);
    SmartDialog.dismiss(status: SmartStatus.loading);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('下载重复导入幂等且错误标签不会造成关注部分写入', (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: SizedBox())));
    await tester.runAsync(() async {
      dav.bytes = fixture.zip({
        fixture.follows:
            fixture.data([fixture.user('huya_1', '新增', tag: '新组')]),
        fixture.tags: fixture.data([
          fixture.tag('t1', '新组', ['huya_1'])
        ])
      });
      await controller.doWebDAVRecovery();
      final original = db.followBox.get('huya_1');
      await controller.doWebDAVRecovery();
      expect(db.followBox.length, 1);
      expect(db.followBox.get('huya_1'), same(original));
      expect(db.tagBox.length, 1);
      expect(db.tagBox.get('t1')!.userId, ['huya_1']);
      dav.bytes = fixture.zip({
        fixture.follows: fixture.data([fixture.user('huya_2', '不能部分写入')]),
        fixture.tags: fixture.data([
          {'id': 'broken', 'tag': '损坏', 'userId': 'not-list'}
        ])
      });
      await controller.doWebDAVRecovery();
      expect(db.followBox.length, 1);
      expect(db.followBox.containsKey('huya_2'), isFalse);
      expect(controller.isSyncing.value, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    SmartDialog.dismiss(status: SmartStatus.allToast);
    SmartDialog.dismiss(status: SmartStatus.loading);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('下载同ID异名分组映射本机组名，仅新增成员追加到原标签key', (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: SizedBox())));
    await tester.runAsync(() async {
      final local =
          FollowUser.fromJson(fixture.user('huya_1', '保留', tag: '本机组名'));
      await db.followBox.put(local.id, local);
      await db.tagBox.put(
          0, FollowUserTag(id: 'shared-tag', tag: '本机组名', userId: ['huya_1']));
      dav.bytes = fixture.zip({
        fixture.follows: fixture.data([
          fixture.user('huya_1', '不能覆盖', tag: '云端组名'),
          fixture.user('huya_2', '新增', tag: '云端组名')
        ]),
        fixture.tags: fixture.data([
          fixture.tag('shared-tag', '云端组名', ['huya_1', 'huya_2'])
        ])
      });
      await controller.doWebDAVRecovery();
      expect(db.followBox.get('huya_1'), same(local));
      expect(local.tag, '本机组名');
      expect(db.followBox.get('huya_2')!.tag, '本机组名');
      expect(db.tagBox.keys, [0]);
      expect(db.tagBox.get(0)!.tag, '本机组名');
      expect(db.tagBox.get(0)!.userId, ['huya_1', 'huya_2']);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    SmartDialog.dismiss(status: SmartStatus.allToast);
    SmartDialog.dismiss(status: SmartStatus.loading);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('下载期间阻止重复下载和上传，等待整个异步操作结束再解除busy', (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: SizedBox())));
    await tester.runAsync(() async {
      dav.readGate = Completer<List<int>>();
      final pending = controller.doWebDAVRecovery();
      expect(controller.isSyncing.value, isTrue);
      await controller.doWebDAVRecovery();
      await controller.doWebDAVUpload();
      expect(dav.reads, 1);
      expect(dav.uploads, 0);
      dav.readGate!.complete(fixture.zip({fixture.follows: fixture.data([])}));
      await pending;
      expect(controller.isSyncing.value, isFalse);
      expect(controller.lastRecoverTime.value, isNot('--'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    SmartDialog.dismiss(status: SmartStatus.allToast);
    SmartDialog.dismiss(status: SmartStatus.loading);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('上传错误释放busy，不写成功时间，并向用户显示真实原因', (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: SizedBox())));
    await tester.runAsync(() async {
      dav.uploadError = StateError('读取云端备份失败（HTTP 503）');
      await controller.doWebDAVUpload();
      expect(dav.uploads, 1);
      expect(controller.isSyncing.value, isFalse);
      expect(controller.lastUploadTime.value, '--');
      expect(
          LocalStorageService.instance.settingsBox
              .containsKey(LocalStorageService.kWebDAVLastUploadTime),
          isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    SmartDialog.dismiss(status: SmartStatus.allToast);
    SmartDialog.dismiss(status: SmartStatus.loading);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });
}
