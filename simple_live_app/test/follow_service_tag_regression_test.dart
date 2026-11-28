import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Service extends FollowService {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  int getOptimalConcurrency() => 1;
}

class _GateSite extends HuyaSite {
  final requests = <Completer<bool>>[];
  final requestedRooms = <String>[];
  final details = <Completer<LiveRoomDetail>>[];
  @override
  Future<bool> getLiveStatus({required String roomId}) {
    requestedRooms.add(roomId);
    final gate = Completer<bool>();
    requests.add(gate);
    return gate.future;
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) {
    final gate = Completer<LiveRoomDetail>();
    details.add(gate);
    return gate.future;
  }
}

// Fail one actual Hive write while delegating every read and subsequent write
// to the real temporary box. This exercises migration failure/retry boundaries.
class _FailingTagBox implements Box<FollowUserTag> {
  final Box<FollowUserTag> delegate;
  int writesBeforeFailure;
  _FailingTagBox(this.delegate, this.writesBeforeFailure);
  @override
  String get name => delegate.name;
  @override
  bool get isOpen => delegate.isOpen;
  @override
  Iterable<dynamic> get keys => delegate.keys;
  @override
  Iterable<FollowUserTag> get values => delegate.values;
  @override
  FollowUserTag? get(dynamic key, {FollowUserTag? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, FollowUserTag value) async {
    if (writesBeforeFailure-- == 0) {
      throw StateError('injected disk write failure');
    }
    await delegate.put(key, value);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => delegate.deleteAll(keys);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GatedTagBox extends _FailingTagBox {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool gated = false;
  _GatedTagBox(Box<FollowUserTag> delegate) : super(delegate, -1);
  @override
  Future<void> put(dynamic key, FollowUserTag value) async {
    if (!gated) {
      gated = true;
      entered.complete();
      await release.future;
    }
    await delegate.put(key, value);
  }
}

FollowUser _user(String id, {int status = 0}) => FollowUser(
      id: 'huya_$id',
      roomId: id,
      siteId: 'huya',
      userName: '同名主播',
      face: '',
      addTime: DateTime(2026),
      categoryName: '旧分类',
    )..liveStatus.value = status;

LiveRoomDetail _detail(String category, int heat, {String roomId = 'race'}) =>
    LiveRoomDetail(
      roomId: roomId,
      title: '',
      cover: '',
      userName: '',
      userAvatar: '',
      online: heat,
      status: true,
      url: '',
      categoryName: category,
    );
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('等待服务发布超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Future<void> _tick() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DBService db;
  late _Service service;
  late Site original;
  late _GateSite site;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('follow-tag-regression-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FollowUserAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(FollowUserTagAdapter());
    }
    db = Get.put(DBService());
    db.followBox = await Hive.openBox<FollowUser>('follow');
    db.tagBox = await Hive.openBox<FollowUserTag>('tags');
    service = Get.put<FollowService>(_Service()) as _Service;
    original = Sites.allSites['huya']!;
    site = _GateSite();
    Sites.allSites['huya'] = Site(
        id: original.id,
        name: original.name,
        logo: original.logo,
        liveSite: site);
  });
  tearDown(() async {
    Sites.allSites['huya'] = original;
    service.onClose();
    Get.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('虎牙别名刷新后合并到正式房间并保留标签，同名主播各自保留', () async {
    final alias = _user('dank1ng');
    final canonical = _user('12345');
    final namesake = _user('67890');
    await db.addFollow(alias);
    await db.addFollow(canonical);
    await db.addFollow(namesake);
    final tag = await db.addFollowTag('CS2');
    await db.updateFollowTag(
        tag.copyWith(userId: [alias.id, canonical.id, namesake.id]));
    await service.loadData();
    for (var i = 0; i < 3; i++) {
      await _until(() => site.requests.length > i);
      final isAlias = site.requestedRooms[i] == alias.roomId;
      site.requests[i].complete(isAlias);
    }
    await _until(() => site.details.isNotEmpty);
    site.details.single.complete(_detail('CS2', 900, roomId: canonical.roomId));
    await _until(() => service.followList.length == 2);
    expect(service.followList.map((user) => user.id),
        unorderedEquals([canonical.id, namesake.id]));
    expect(db.followBox.get(alias.id), isNull);
    expect(db.getFollowTag('CS2')!.userId, [canonical.id, namesake.id]);
  });

  test('旧轮详情响应不覆盖新轮直播状态、分类、热度或持久化数据', () async {
    final item = _user('race');
    await db.addFollow(item);
    await service.loadData();
    site.requests[0].complete(true);
    await _tick();
    await service.loadData();
    site.requests[1].complete(true);
    await _tick();
    site.details[1].complete(_detail('最新分类', 900));
    await _until(() => item.categoryName == '最新分类');
    expect(item.liveStatus.value, 2);
    site.details[0].complete(_detail('过期分类', 1));
    await _tick();
    expect(item.categoryName, '最新分类');
    expect(item.heat, 900);
    expect(item.liveStatus.value, 2);
    expect(service.updatedCount, 1);
    expect(service.updating.value, isFalse);
    await db.followBox.close();
    db.followBox = await Hive.openBox<FollowUser>('follow');
    expect(db.followBox.get(item.id)!.categoryName, '最新分类');
  });

  test('慢详情不占用状态并发，开播名单先更新且停止转圈', () async {
    final first = _user('first');
    final second = _user('second');
    await db.addFollow(first);
    await db.addFollow(second);
    await service.loadData();
    site.requests.first.complete(true);
    await _until(() => site.requests.length == 2);
    expect(service.liveList, [first]);
    site.requests.last.complete(true);
    await _until(() => !service.updating.value && site.details.isNotEmpty);
    expect(service.liveList, containsAll([first, second]));
    site.details.first.completeError(StateError('详情暂不可用'));
    await _until(() => site.details.length == 2);
    site.details.last.complete(_detail('最新分类', 10));
    await _until(() => second.heat == 10);
    expect(service.liveList, containsAll([first, second]));
  });

  test('状态请求失败保留上次已开播的主播', () async {
    final item = _user('known', status: 2);
    await db.addFollow(item);
    await service.loadData();
    site.requests.single.completeError(StateError('临时网络故障'));
    await _until(() => !service.updating.value);
    expect(service.liveList.single, same(item));
  });

  test('旧轮完成不能提前结束仍在等待的当前轮', () async {
    await db.addFollow(_user('race'));
    await service.loadData();
    await service.loadData();
    site.requests[0].complete(false);
    await _tick();
    expect(service.updating.value, isTrue);
    expect(service.updatedCount, 0);
    site.requests[1].complete(false);
    await _tick();
    expect(service.updating.value, isFalse);
    expect(service.updatedCount, 1);
  });

  test('取消并重新关注同ID时旧对象及新对象均不接收旧详情', () async {
    final old = _user('race');
    await db.addFollow(old);
    await service.loadData();
    site.requests[0].complete(true);
    await _tick();
    await db.deleteFollow(old.id);
    final replacement = _user('race')..categoryName = '重新关注';
    await db.addFollow(replacement);
    await service.loadData(updateStatus: false);
    site.details[0].complete(_detail('过期分类', 1));
    await _tick();
    expect(old.liveStatus.value, 2);
    expect(old.heat, isNull);
    expect(old.categoryName, '旧分类');
    expect(replacement.categoryName, '重新关注');
    expect(db.followBox.get(old.id), same(replacement));
    expect(service.updatedCount, 0);
    expect(service.updating.value, isFalse);
  });

  test('最后一个关注删除后清空全部派生缓存并广播', () async {
    final item = _user('last', status: 2);
    await db.addFollow(item);
    await service.loadData(updateStatus: false);
    service.filterData();
    service
        .filterDataByTag(FollowUserTag(id: 't', tag: '游戏', userId: [item.id]));
    final events = <dynamic>[];
    final subscription = service.updatedListStream.listen(events.add);
    await db.deleteFollow(item.id);
    await service.loadData(updateStatus: false);
    await _tick();
    expect(service.followList, isEmpty);
    expect(service.liveList, isEmpty);
    expect(service.notLiveList, isEmpty);
    expect(service.curTagFollowList, isEmpty);
    expect(events, isNotEmpty);
    await subscription.cancel();
  });

  test('不请求网络的重新载入同样更新直播及未开播缓存并保留同名不同ID', () async {
    final first = _user('a', status: 2);
    final second = _user('b', status: 1);
    await db.addFollow(first);
    await db.addFollow(second);
    await service.loadData(updateStatus: false);
    expect(service.liveList.single, same(first));
    expect(service.notLiveList.single, same(second));
    expect(service.followList.length, 2);
    expect(site.requests, isEmpty);
  });

  test('排序后保持UUID键，重开盒后保持顺序且可更新和删除', () async {
    final a = await db.addFollowTag('游戏');
    final b = await db.addFollowTag('学习');
    await db.updateFollowTagOrder([b, a]);
    expect(db.tagBox.keys.toSet(), {a.id, b.id});
    await db.tagBox.close();
    db.tagBox = await Hive.openBox<FollowUserTag>('tags');
    expect(db.getFollowTagList().map((t) => t.id), [b.id, a.id]);
    await db.updateFollowTag(b.copyWith(tag: '新名称'));
    expect(db.getFollowTagList().length, 2);
    await db.deleteFollowTag(b.id);
    expect(db.getFollowTagList().single.id, a.id);
  });

  test('历史整数键及同名重复迁移合并成员且保留其他分组', () async {
    final a = FollowUserTag(id: 'uuid-a', tag: '游戏', userId: ['a', 'b']);
    final b = FollowUserTag(id: 'uuid-b', tag: '游戏', userId: ['b', 'c']);
    final custom = FollowUserTag(id: 'custom', tag: '我的分组', userId: ['a']);
    await db.tagBox.putAll({0: a, 1: b, custom.id: custom});
    // Every mutation must normalize old on-disk layouts before applying changes.
    await db.addFollowTag('游戏');
    expect(db.getFollowTagList().length, 2);
    final merged = db.getFollowTag('游戏')!;
    expect(merged.userId.toSet(), {'a', 'b', 'c'});
    expect(db.tagBox.keys.toSet(), {merged.id, custom.id});
    expect(db.getFollowTag('我的分组')!.userId, ['a']);
    await db.updateFollowTag(merged.copyWith(tag: '新名称'));
    await db.deleteFollowTag(merged.id);
    expect(db.getFollowTagList().single.id, custom.id);
  });

  test('两条短标签导入只生成一个标签并保留全部成员', () async {
    final a = _user('a')..tag = '游戏';
    final b = _user('b')..tag = '游戏';
    await service.inputJson(jsonEncode([a.toJson(), b.toJson()]));
    expect(db.getFollowTagList().length, 1);
    expect(db.getFollowTagList().single.userId.toSet(), {a.id, b.id});
    expect(db.getFollowList().length, 2);
  });

  test('迁移别名多次合并后旧ID仍能删除最终规范标签', () async {
    final a = FollowUserTag(id: 'a', tag: '甲', userId: ['1']);
    final b = FollowUserTag(id: 'b', tag: '乙', userId: ['2']);
    final c = FollowUserTag(id: 'c', tag: '乙', userId: ['3']);
    await db.tagBox.putAll({a.id: a, b.id: b, c.id: c});
    await db.normalizeFollowTags();
    await db.updateFollowTag(db.getFollowTag('乙')!.copyWith(tag: '甲'));
    expect(db.getFollowTagList().single.userId.toSet(), {'1', '2', '3'});
    await db.deleteFollowTag(c.id);
    expect(db.getFollowTagList(), isEmpty);
  });

  test('迁移中途写失败保留源成员，队列可重试且不清空其他分组', () async {
    final a = FollowUserTag(id: 'a', tag: '游戏', userId: ['1']);
    final b = FollowUserTag(id: 'b', tag: '游戏', userId: ['2']);
    final other = FollowUserTag(id: 'other', tag: '自定义', userId: ['3']);
    final box = db.tagBox;
    await box.putAll({0: a, 1: b, 2: other});
    db.tagBox = _FailingTagBox(box, 1);
    await expectLater(db.normalizeFollowTags(), throwsStateError);
    expect(box.keys, containsAll([0, 1, 2]));
    await db.normalizeFollowTags();
    expect(db.getFollowTag('游戏')!.userId.toSet(), {'1', '2'});
    expect(db.getFollowTag('自定义')!.userId, ['3']);
    expect(box.keys.toSet(), {'a', 'other'});
    db.tagBox = box;
  });

  test('迁移快照之后旧同步直接新增的UUID不能被误删', () async {
    final box = db.tagBox;
    await box.put(
        0, FollowUserTag(id: 'legacy-uuid', tag: '旧分组', userId: ['old-user']));
    final gate = _GatedTagBox(box);
    db.tagBox = gate;
    final migration = db.normalizeFollowTags();
    await gate.entered.future;
    // Legacy sync writes directly to Hive, outside the DB mutation queue.
    await box.put('sync-uuid',
        FollowUserTag(id: 'sync-uuid', tag: '同步新增', userId: ['new-user']));
    gate.release.complete();
    await migration;
    expect(box.get('legacy-uuid')!.userId, ['old-user']);
    expect(box.get('sync-uuid')?.userId, ['new-user']);
    expect(box.keys.toSet(), {'legacy-uuid', 'sync-uuid'});
    db.tagBox = box;
  });

  test('重启服务与Hive后读取独立顺序元数据，不丢失成员或UUID', () async {
    final a = await db.addFollowTag('游戏');
    final b = await db.addFollowTag('自定义');
    await db.updateFollowTag(a.copyWith(userId: ['a', 'b']));
    await db.updateFollowTagOrder([b, a]);
    await Hive.close();
    final restarted = DBService();
    restarted.followBox = await Hive.openBox<FollowUser>('follow');
    restarted.tagBox = await Hive.openBox<FollowUserTag>('tags');
    await restarted.normalizeFollowTags();
    expect(restarted.getFollowTagList().map((t) => t.id), [b.id, a.id]);
    expect(restarted.getFollowTag('游戏')!.userId, ['a', 'b']);
    expect(restarted.tagBox.keys.toSet(), {a.id, b.id});
  });

  test('外部标签事务与迁移共用串行队列，失败后后继仍可执行', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final first = db.runFollowTagMutation(() async {
      started.complete();
      await gate.future;
      throw StateError('injected transaction failure');
    });
    final failure = expectLater(first, throwsStateError);
    await started.future;
    var finished = false;
    final second = db.addFollowTag('游戏').then((_) => finished = true);
    await _tick();
    expect(finished, isFalse);
    gate.complete();
    await failure;
    await second;
    expect(db.getFollowTagList().single.tag, '游戏');
  });

  test('过期离线与失败响应均不覆盖新轮次，也不发布多余缓存', () async {
    final item = _user('race');
    await db.addFollow(item);
    await service.loadData();
    await service.loadData();
    await service.loadData();
    site.requests[2].complete(true);
    await _until(() => site.details.length == 1);
    site.details.single.complete(_detail('最新', 100));
    await _until(() => item.categoryName == '最新');
    final events = <dynamic>[];
    final subscription = service.updatedListStream.listen(events.add);
    site.requests[0].complete(false);
    site.requests[1].completeError(StateError('old failure'));
    await _tick();
    expect(item.liveStatus.value, 2);
    expect(item.categoryName, '最新');
    expect(item.heat, 100);
    expect(service.updatedCount, 1);
    expect(events, isEmpty);
    await subscription.cancel();
  });

  test('并发添加相同短标签不会生成重复记录', () async {
    final tags =
        await Future.wait(List.generate(12, (_) => db.addFollowTag('游戏')));
    expect(tags.map((t) => t.id).toSet().length, 1);
    expect(db.tagBox.length, 1);
  });
}
