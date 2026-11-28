import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/room_startup_cache.dart';
import 'package:simple_live_core/simple_live_core.dart';

LiveRoomDetail detail(String id, {bool live = true}) => LiveRoomDetail(
    roomId: id,
    title: '',
    cover: '',
    userName: '',
    userAvatar: '',
    online: 0,
    status: live,
    url: '');

class Source extends LiveSite {
  int calls = 0, warms = 0;
  Future<LiveRoomDetail> Function(String) request = (id) async => detail(id);
  @override
  void prefetchRoom(String roomId) {
    warms++;
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) {
    calls++;
    return request(roomId);
  }
}

class AccountSource extends DouyinSite {
  int calls = 0;
  Future<LiveRoomDetail> Function(String, String)? request;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    calls++;
    return request == null
        ? detail('$roomId:$cookie')
        : await request!(roomId, cookie);
  }
}

void main() {
  test('预取与两次同时进入共享请求，交接仅一次，刷新取新数据', () async {
    final cache = RoomStartupCache();
    final source = Source();
    final gate = Completer<LiveRoomDetail>();
    source.request = (_) => gate.future;
    expect(cache.prefetch(source, '1'), isTrue);
    final a = cache.take(source, '1');
    final b = cache.take(source, '1');
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 1);
    gate.complete(detail('1'));
    expect(await a, same(await b));
    source.request = (id) async => detail(id);
    await cache.take(source, '1');
    expect(source.calls, 2);
    await cache.refresh(source, '1');
    expect(source.calls, 3);
  });
  test('已完成的预取不重复获取详情，短缓存过期后重新读取', () async {
    var now = DateTime(2026);
    final cache = RoomStartupCache(now: () => now);
    final source = Source();
    cache.prefetch(source, '1');
    await Future<void>.delayed(Duration.zero);
    await cache.take(source, '1');
    expect(source.calls, 1);
    cache.prefetch(source, '2');
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 8));
    await cache.take(source, '2');
    expect(source.calls, 3);
  });
  test('最多两个后台房间，前台进入不被后台额度阻塞', () async {
    final cache = RoomStartupCache();
    final source = Source();
    final gate = Completer<LiveRoomDetail>();
    source.request =
        (id) => id == 'foreground' ? Future.value(detail(id)) : gate.future;
    expect(cache.prefetch(source, '1'), isTrue);
    expect(cache.prefetch(source, '2'), isTrue);
    expect(cache.prefetch(source, '3'), isFalse);
    expect((await cache.take(source, 'foreground')).roomId, 'foreground');
    expect(source.calls, 3);
    gate.complete(detail('1'));
  });
  test('预取失败不产生未处理错误，也不污染之后的进入', () async {
    final cache = RoomStartupCache();
    final source = Source()
      ..request = (_) => Future.error(StateError('failed'));
    cache.prefetch(source, '1');
    await Future<void>.delayed(Duration.zero);
    source.request = (id) async => detail(id);
    expect((await cache.take(source, '1')).roomId, '1');
    expect(source.calls, 2);
  });
  test('等待中的预取失败，前台重新请求一次', () async {
    final cache = RoomStartupCache();
    final source = Source();
    final gate = Completer<LiveRoomDetail>();
    source.request = (_) => gate.future;
    cache.prefetch(source, '1');
    final opening = cache.take(source, '1');
    await Future<void>.delayed(Duration.zero);
    source.request = (id) async => detail(id);
    gate.completeError(StateError('failed'));
    expect((await opening).roomId, '1');
    expect(source.calls, 2);
  });
  test('离线结果不缓存，不同平台实例不共享', () async {
    final cache = RoomStartupCache();
    final source = Source()..request = (id) async => detail(id, live: false);
    cache.prefetch(source, '1');
    await Future<void>.delayed(Duration.zero);
    await cache.take(source, '1');
    expect(source.calls, 2);
    final other = Source();
    await cache.take(other, '1');
    expect(other.calls, 1);
  });
  test('关注刷新结果短时交接给进房，手动刷新不读缓存', () async {
    final cache = RoomStartupCache();
    final source = Source();
    final fresh = await cache.refresh(source, '1');
    expect(await cache.take(source, '1'), same(fresh));
    expect(source.calls, 1);
    await cache.refresh(source, '1');
    await cache.refresh(source, '1');
    expect(source.calls, 3);
  });
  test('切换账号后丢弃旧预取，不能跨账号复用', () async {
    final cache = RoomStartupCache();
    final source = AccountSource()..cookie = 'account-a';
    cache.prefetch(source, '1');
    await Future<void>.delayed(Duration.zero);
    source.cookie = 'account-b';
    expect((await cache.take(source, '1')).roomId, '1:account-b');
    expect(source.calls, 2);
  });
  test('准备数据最多保留八个房间，旧房间被淘汰', () async {
    final cache = RoomStartupCache();
    final source = Source();
    for (var i = 0; i < 9; i++) {
      await cache.refresh(source, '$i');
    }
    await cache.take(source, '8');
    expect(source.calls, 9);
    await cache.take(source, '0');
    expect(source.calls, 10);
  });
  test('预取已完成时同时进入也只交接一次，不触发第二个网络请求', () async {
    final cache = RoomStartupCache();
    final source = Source();
    cache.prefetch(source, '1');
    await Future<void>.delayed(Duration.zero);
    final results =
        await Future.wait([cache.take(source, '1'), cache.take(source, '1')]);
    expect(results[0], same(results[1]));
    expect(source.calls, 1);
  });
  test('预取失败重试期间换账号，前台只收到新账号结果', () async {
    final cache = RoomStartupCache();
    final first = Completer<LiveRoomDetail>();
    final retry = Completer<LiveRoomDetail>();
    final source = AccountSource()..cookie = 'a';
    source.request = (id, account) => account == 'b'
        ? Future.value(detail('$id:b'))
        : source.calls == 1
            ? first.future
            : retry.future;
    cache.prefetch(source, '1');
    final opening = cache.take(source, '1');
    first.completeError(StateError('first failed'));
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 2);
    source.cookie = 'b';
    retry.complete(detail('1:a'));
    expect((await opening).roomId, '1:b');
    expect(source.calls, 3);
  });
  test('新一轮刷新不等待旧轮详情，旧响应不能覆盖新交接', () async {
    final cache = RoomStartupCache();
    final source = Source();
    final old = Completer<LiveRoomDetail>();
    source.request = (_) => old.future;
    final previous = cache.refresh(source, '1');
    source.request = (id) async => detail('new');
    await cache.refresh(source, '1');
    old.complete(detail('old'));
    await previous;
    expect((await cache.take(source, '1')).roomId, 'new');
    expect(source.calls, 2);
  });
  test('刷新解除旧消费登记，重新进入不等待旧页面的慢请求', () async {
    final cache = RoomStartupCache();
    final source = Source();
    final gate = Completer<LiveRoomDetail>();
    source.request = (_) => gate.future;
    final old = cache.take(source, '1');
    source.request = (_) async => detail('new');
    await cache.refresh(source, '1');
    final current = cache.take(source, '1');
    gate.complete(detail('old'));
    expect((await current).roomId, 'new');
    expect((await old).roomId, 'old');
  });
}
