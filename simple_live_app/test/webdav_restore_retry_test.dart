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
import 'webdav_merge_upload_test.dart' as fixture;

class _Dav implements DAVClient {
  late Uint8List bytes;
  @override
  Future<List<int>> recovery() async => bytes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailTagWrite implements Box<FollowUserTag> {
  final Box<FollowUserTag> delegate;
  bool fail = true;
  _FailTagWrite(this.delegate);
  @override
  Iterable<FollowUserTag> get values => delegate.values;
  @override
  Iterable<dynamic> get keys => delegate.keys;
  @override
  FollowUserTag? get(dynamic key, {FollowUserTag? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, FollowUserTag value) async {
    if (fail) {
      fail = false;
      throw const FileSystemException('fixture: disk full at tag write');
    }
    await delegate.put(key, value);
  }

  @override
  Future<void> flush() => delegate.flush();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late DBService db;
  late _Dav dav;
  late RemoteSyncWebDAVController controller;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('webdav-retry-');
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FollowUserAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(FollowUserTagAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HistoryAdapter());
    db = Get.put(DBService());
    await db.init();
    await Get.put(LocalStorageService()).init();
    dav = _Dav()
      ..bytes = fixture.zip({
        fixture.follows: fixture.data([
          fixture.user('huya_1', 'must preserve', tag: 'remote'),
          fixture.user('huya_2', 'new', tag: 'remote')
        ]),
        fixture.tags: fixture.data([
          fixture.tag('remote-tag', 'remote', ['huya_1', 'huya_2'])
        ])
      });
    controller = RemoteSyncWebDAVController()..davClient = dav;
    await db.followBox.put('huya_1',
        FollowUser.fromJson(fixture.user('huya_1', 'local', tag: 'local')));
    await db.tagBox.put('local-tag',
        FollowUserTag(id: 'local-tag', tag: 'local', userId: ['huya_1']));
  });
  tearDown(() async {
    await Hive.close();
    Get.reset();
    await temp.delete(recursive: true);
  });
  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: SizedBox())));
    await tester.runAsync(body);
    SmartDialog.dismiss(status: SmartStatus.allToast);
    SmartDialog.dismiss(status: SmartStatus.loading);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  for (final restart in [false, true]) {
    testWidgets(
        'failed tag write retries imported membership${restart ? " after Hive restart" : ""}, preserving existing groups',
        (tester) async {
      await run(tester, () async {
        final real = db.tagBox;
        db.tagBox = _FailTagWrite(real);
        await controller.doWebDAVRecovery();
        expect(db.followBox.containsKey('huya_2'), isTrue);
        expect(real.get('remote-tag'), isNull);
        expect(controller.lastRecoverTime.value, '--');
        db.tagBox = real;
        if (restart) {
          await Hive.close();
          Get.reset();
          Hive.init(temp.path);
          db = Get.put(DBService());
          await db.init();
          await Get.put(LocalStorageService()).init();
          controller = RemoteSyncWebDAVController()..davClient = dav;
        }
        await controller.doWebDAVRecovery();
        expect(db.tagBox.get('remote-tag')?.userId, ['huya_2']);
        expect(db.followBox.get('huya_1')!.userName, 'local');
        expect(db.followBox.get('huya_1')!.tag, 'local');
        expect(db.tagBox.get('local-tag')!.userId, ['huya_1']);
        expect(controller.lastRecoverTime.value, isNot('--'));
        await controller.doWebDAVRecovery();
        expect(db.tagBox.get('remote-tag')!.userId, ['huya_2']);
      });
    });
  }
  testWidgets(
      'retry does not undo intentional regrouping of interrupted imported user',
      (tester) async {
    await run(tester, () async {
      final real = db.tagBox;
      db.tagBox = _FailTagWrite(real);
      await controller.doWebDAVRecovery();
      db.tagBox = real;
      final changed = FollowUser.fromJson(
          {...db.followBox.get('huya_2')!.toJson(), 'tag': 'local'});
      await db.followBox.put(changed.id, changed);
      await db.tagBox.put(
          'local-tag',
          FollowUserTag(
              id: 'local-tag', tag: 'local', userId: ['huya_1', 'huya_2']));
      await controller.doWebDAVRecovery();
      expect(db.followBox.get('huya_2')!.tag, 'local');
      expect(db.tagBox.get('remote-tag'), isNull);
      expect(db.tagBox.get('local-tag')!.userId, ['huya_1', 'huya_2']);
    });
  });
  testWidgets(
      'retry respects existing tag rename while repairing only imported member',
      (tester) async {
    await run(tester, () async {
      await db.followBox.put(
          'huya_3',
          FollowUser.fromJson(
              fixture.user('huya_3', 'existing', tag: 'remote')));
      await db.tagBox.put('remote-tag',
          FollowUserTag(id: 'remote-tag', tag: 'remote', userId: ['huya_3']));
      final real = db.tagBox;
      db.tagBox = _FailTagWrite(real);
      await controller.doWebDAVRecovery();
      db.tagBox = real;
      await db.tagBox.put('remote-tag',
          FollowUserTag(id: 'remote-tag', tag: 'renamed', userId: ['huya_3']));
      await db.followBox.put(
          'huya_3',
          FollowUser.fromJson(
              fixture.user('huya_3', 'existing', tag: 'renamed')));
      await controller.doWebDAVRecovery();
      expect(db.followBox.get('huya_2')!.tag, 'renamed');
      expect(db.tagBox.get('remote-tag')!.tag, 'renamed');
      expect(db.tagBox.get('remote-tag')!.userId, ['huya_3', 'huya_2']);
      expect(db.followBox.get('huya_1')!.tag, 'local');
    });
  });
}
