import 'dart:async';
import 'package:simple_live_core/simple_live_core.dart';

typedef _RoomKey = (LiveSite, String, String);
typedef _Entry = (Future<LiveRoomDetail>, DateTime);

/// 短时、单次的进房交接，不缓存播放直链，也不影响手动刷新。
class RoomStartupCache {
  RoomStartupCache({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static final instance = RoomStartupCache();
  final DateTime Function() _now;
  static const ttl = Duration(seconds: 8);
  final _ready = <_RoomKey, _Entry>{};
  final _pending = <_RoomKey, _Entry>{};
  final _consumers = <_RoomKey, Future<LiveRoomDetail>>{};
  final _speculative = <(_RoomKey, Future<LiveRoomDetail>)>{};

  _RoomKey _key(LiveSite source, String roomId) => (
        source,
        switch (source) {
          BiliBiliSite() => '${source.cookie}|${source.userId}',
          DouyinSite() => source.cookie,
          _ => '',
        },
        roomId,
      );

  void _prune() {
    _ready.removeWhere((key, entry) =>
        _now().difference(entry.$2) >= ttl || key != _key(key.$1, key.$3));
  }

  bool prefetch(LiveSite source, String roomId) {
    _prune();
    final key = _key(source, roomId);
    if (roomId.isEmpty ||
        _ready.containsKey(key) ||
        _pending.containsKey(key) ||
        _speculative.length >= 2) {
      return false;
    }
    // 只预取接口，不创建播放器、弹幕连接或后台音频。
    try {
      source.prefetchRoom(roomId);
    } catch (_) {/* 前台仍可正常取详情。 */}
    final request = _request(key);
    _speculative.add((key, request));
    return true;
  }

  Future<LiveRoomDetail> _request(_RoomKey key, {bool force = false}) {
    final pending = _pending[key];
    if (!force && pending != null) return pending.$1;
    final start = _now();
    final request = Future<LiveRoomDetail>.sync(() => force
        ? key.$1.refreshRoomDetail(roomId: key.$3)
        : key.$1.getRoomDetail(roomId: key.$3));
    _pending[key] = (request, start);
    request.then<void>((value) {
      final current = identical(_pending[key]?.$1, request);
      if (current) _pending.remove(key);
      _speculative.remove((key, request));
      _prune();
      if (current &&
          (value.status || value.isRecord) &&
          _now().difference(start) < ttl &&
          key == _key(key.$1, key.$3)) {
        _ready.remove(key);
        if (_ready.length >= 8) _ready.remove(_ready.keys.first);
        _ready[key] = (request, start);
      }
    }, onError: (Object _, StackTrace __) {
      if (identical(_pending[key]?.$1, request)) _pending.remove(key);
      _speculative.remove((key, request));
    });
    return request;
  }

  /// 显式刷新开启新一轮请求，不能复用上一轮的迟到结果。
  Future<LiveRoomDetail> refresh(LiveSite source, String roomId) {
    _prune();
    final key = _key(source, roomId);
    _ready.remove(key);
    _consumers.remove(key);
    return _request(key, force: true);
  }

  /// 消费后即移除；再次进入/刷新不重复使用旧详情和鉴权信息。
  Future<LiveRoomDetail> take(LiveSite source, String roomId) {
    _prune();
    final key = _key(source, roomId);
    final pending = _consumers[key];
    if (pending != null) return pending;
    final request = _take(key);
    _consumers[key] = request;
    void release() {
      if (identical(_consumers[key], request)) _consumers.remove(key);
    }

    request.then<void>((_) => release(),
        onError: (Object _, StackTrace __) => release());
    return request;
  }

  Future<LiveRoomDetail> _take(_RoomKey key) async {
    final entry = _ready.remove(key) ?? _pending[key];
    var request = entry?.$1 ?? _request(key);
    final speculative = _speculative.contains((key, request));
    try {
      LiveRoomDetail result;
      try {
        result = await request;
      } catch (_) {
        if (!speculative) rethrow;
        if (key != _key(key.$1, key.$3)) return await take(key.$1, key.$3);
        request = _request(key);
        result = await request;
      }
      if (key != _key(key.$1, key.$3)) return await take(key.$1, key.$3);
      return result;
    } finally {
      if (identical(_ready[key]?.$1, request)) _ready.remove(key);
    }
  }
}
