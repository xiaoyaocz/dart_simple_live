import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Site extends HuyaSite {
  bool living = true;
  Future<void>? detailGate;
  String? category = ' 英雄联盟 ';
  int online = 16000;
  int statusRequests = 0;
  int detailRequests = 0;
  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    statusRequests++;
    return living;
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    detailRequests++;
    await detailGate;
    return LiveRoomDetail(
        roomId: roomId,
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: online,
        status: true,
        url: '',
        categoryName: category);
  }
}

class _Service extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

FollowUser _user() => FollowUser(
    id: 'huya_1',
    roomId: '1',
    siteId: 'huya',
    userName: '测试主播',
    face: '',
    addTime: DateTime(2026));

// 模拟旧版本七字段记录，验证新增字段仍能读取旧数据。
class _LegacyAdapter extends FollowUserAdapter {
  @override
  void write(BinaryWriter writer, FollowUser obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.userName)
      ..writeByte(4)
      ..write(obj.face)
      ..writeByte(5)
      ..write(obj.addTime)
      ..writeByte(6)
      ..write(obj.tag);
  }
}

void main() {
  late Directory directory;
  late DBService db;
  late Site original;
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('simple-live-category-test-');
    Hive.init(directory.path);
    Hive.registerAdapter(FollowUserAdapter(), override: true);
    db = Get.put(DBService());
    db.followBox = await Hive.openBox<FollowUser>('FollowUser');
    original = Sites.allSites['huya']!;
  });
  tearDown(() async {
    Sites.allSites['huya'] = original;
    await Hive.close();
    Get.reset();
    await directory.delete(recursive: true);
  });

  test('旧七字段关注记录可读取，分类JSON和Hive持久化可往返', () async {
    await db.followBox.close();
    Hive.registerAdapter(_LegacyAdapter(), override: true);
    var box = await Hive.openBox<FollowUser>('Legacy');
    await box.put('user', _user());
    await box.close();
    Hive.registerAdapter(FollowUserAdapter(), override: true);
    box = await Hive.openBox<FollowUser>('Legacy');
    final legacy = box.get('user')!;
    expect(legacy.categoryName, isNull);
    expect(legacy.userName, '测试主播');
    legacy.categoryName = '英雄联盟';
    await box.put('user', legacy);
    await box.close();
    box = await Hive.openBox<FollowUser>('Legacy');
    expect(box.get('user')!.categoryName, '英雄联盟');
    expect(FollowUser.fromJson(box.get('user')!.toJson()).categoryName, '英雄联盟');
  });

  test('保存现有详情分类不增加请求，无分类响应保留缓存，取消关注不被重新加入', () async {
    final site = _Site();
    Sites.allSites['huya'] = Site(
        id: original.id,
        name: original.name,
        logo: original.logo,
        liveSite: site);
    final item = _user();
    await db.addFollow(item);
    final service = _Service();
    service.followList.add(item);
    await service.updateLiveStatus(item);
    expect(item.categoryName, '英雄联盟');
    expect(item.heat, 16000);
    expect(site.statusRequests, 1);
    expect(site.detailRequests, 1);
    await db.followBox.close();
    db.followBox = await Hive.openBox<FollowUser>('FollowUser');
    final restored = db.followBox.get(item.id)!;
    expect(restored.categoryName, '英雄联盟');
    expect(restored.heat, isNull);
    site.category = null;
    site.online = 0;
    await service.updateLiveStatus(restored);
    expect(restored.heat, isNull);
    expect(restored.categoryName, '英雄联盟');
    final beforeCancel = restored.categoryName;
    await db.deleteFollow(item.id);
    site.category = '无畏契约';
    await service.updateLiveStatus(restored);
    expect(db.getFollowList(), isEmpty);
    expect(site.statusRequests, 3);
    // A cancelled follow is rejected after the status response, before an
    // unnecessary room-detail request or any in-memory/database mutation.
    expect(site.detailRequests, 2);
    expect(restored.categoryName, beforeCancel);
  });

  test('未开播转开播先发布状态，随后用单次详情补齐分类', () async {
    final site = _Site();
    Sites.allSites['huya'] = Site(
        id: original.id,
        name: original.name,
        logo: original.logo,
        liveSite: site);
    final item = _user()..liveStatus.value = 1;
    await db.addFollow(item);
    final service = _Service()..followList.add(item);
    final gate = Completer<void>();
    site.detailGate = gate.future;
    final update = service.updateLiveStatus(item);
    await Future<void>.delayed(Duration.zero);
    final statusBeforeCategory = item.liveStatus.value;
    gate.complete();
    await update;
    expect(statusBeforeCategory, 2);
    expect(item.liveStatus.value, 2);
    expect(item.categoryName, '英雄联盟');
    expect(site.detailRequests, 1);
  });

  test('内存关注对象与数据库对象不相同时仍补齐分类，并立即通知分组', () async {
    final site = _Site();
    Sites.allSites['huya'] = Site(
        id: original.id,
        name: original.name,
        logo: original.logo,
        liveSite: site);
    final stored = _user();
    await db.addFollow(stored);
    final item = FollowUser.fromJson(stored.toJson())..liveStatus.value = 1;
    final other = _user()
      ..id = 'huya_2'
      ..roomId = '2';
    final service = _Service()..followList.assignAll([item, other]);
    final events = <dynamic>[];
    final subscription = service.updatedListStream.listen(events.add);
    await service.updateLiveStatus(item);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(item.categoryName, '英雄联盟');
    expect(service.liveList, contains(item));
    expect(events, isNotEmpty);
    expect(db.followBox.get(item.id), same(stored));
    expect(site.detailRequests, 1);
  });

  test('未开播空分类与已开播无效分类均从最新详情恢复，不追加房间请求', () async {
    final site = _Site()..living = false;
    Sites.allSites['huya'] = Site(
        id: original.id,
        name: original.name,
        logo: original.logo,
        liveSite: site);
    final item = _user();
    await db.addFollow(item);
    final service = _Service()..followList.add(item);
    await service.updateLiveStatus(item);
    expect(item.liveStatus.value, 1);
    expect(item.categoryName, isNull);
    expect(site.detailRequests, 0);
    site.living = true;
    await service.updateLiveStatus(item);
    expect(item.categoryName, '英雄联盟');
    expect(site.detailRequests, 1);
    item.categoryName = '其他';
    site.category = '无畏契约';
    await service.updateLiveStatus(item);
    expect(item.categoryName, '无畏契约');
    expect(item.liveStatus.value, 2);
    expect(site.detailRequests, 2);
    expect(site.statusRequests, 3);
  });
}
