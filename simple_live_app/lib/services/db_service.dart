import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

class DBService extends GetxService {
  static DBService get instance => Get.find<DBService>();
  late Box<History> historyBox;
  late Box<FollowUser> followBox;
  late Box<FollowUserTag> tagBox;
  final Uuid uuid = const Uuid();
  Future<void> _tagMutationTail = Future.value();
  Box<List>? _tagOrderBox;
  final Map<String, String> _tagAliases = {};
  final Map<String, String> _followRoomAliases = {};

  // The tail absorbs errors only for queue continuity; the caller still receives
  // the original failed future and can retry the idempotent migration.
  /// Serialize a direct tag-box transaction; do not call queued tag methods
  /// inside the callback (the queue is deliberately non-reentrant).
  Future<T> runFollowTagMutation<T>(Future<T> Function() action) {
    final result = _tagMutationTail.then((_) => action());
    _tagMutationTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future init() async {
    historyBox = await Hive.openBox("History");
    followBox = await Hive.openBox("FollowUser");
    tagBox = await Hive.openBox("FollowUserTag");
    await normalizeFollowTags();
  }

  String _resolveTagId(String id) {
    final seen = <String>{};
    var current = id;
    while (_tagAliases.containsKey(current) && seen.add(current)) {
      current = _tagAliases[current]!;
    }
    // Compress chains created by successive same-name merges.
    for (final alias in seen) {
      if (alias != current) _tagAliases[alias] = current;
    }
    return current;
  }

  // follow_user_tag 相关逻辑
  bool getFollowTagExist(String id) =>
      tagBox.values.any((tag) => tag.id == _resolveTagId(id));

  FollowUserTag? getFollowTag(String tag) =>
      getFollowTagList().firstWhereOrNull((item) => item.tag == tag);

  bool getFollowTagExistByTag(String tag) => getFollowTag(tag) != null;

  List<FollowUserTag> getFollowTagList() {
    final tags = tagBox.values.toList();
    final order = _tagOrderBox?.isOpen == true
        ? _tagOrderBox!.get('ids', defaultValue: <String>[])!
        : <String>[];
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final original = {for (var i = 0; i < tags.length; i++) tags[i].id: i};
    tags.sort((a, b) => (rank[a.id] ?? order.length + original[a.id]!)
        .compareTo(rank[b.id] ?? order.length + original[b.id]!));
    return tags;
  }

  Future<void> normalizeFollowTags() =>
      runFollowTagMutation(_normalizeFollowTags);

  Future<void> _normalizeFollowTags() async {
    final sourceKeys = tagBox.keys.toList();
    _tagOrderBox ??= await Hive.openBox<List>('${tagBox.name}_order');
    if (!_tagOrderBox!.isOpen) {
      _tagOrderBox = await Hive.openBox<List>('${tagBox.name}_order');
    }
    // First reconcile duplicate physical keys for the same logical ID. Prefer
    // the UUID-key record's name (it can be a rename after the old ordering bug).
    final byId = <String, FollowUserTag>{};
    for (final key in sourceKeys) {
      final tag = tagBox.get(key)!;
      final previous = byId[tag.id];
      byId[tag.id] = previous == null
          ? tag.copyWith(userId: tag.userId.toSet().toList())
          : previous.copyWith(
              tag: key == tag.id ? tag.tag : previous.tag,
              userId: {...previous.userId, ...tag.userId}.toList());
    }
    final byName = <String, FollowUserTag>{};
    for (final tag in byId.values) {
      final previous = byName[tag.tag];
      if (previous == null) {
        byName[tag.tag] = tag;
      } else {
        _tagAliases[tag.id] = previous.id;
        byName[tag.tag] = previous.copyWith(
            userId: {...previous.userId, ...tag.userId}.toList());
      }
    }
    final canonical = {for (final tag in byName.values) tag.id: tag};
    // Write every union before deleting any obsolete key. A failed write leaves
    // all source memberships available for the next migration attempt. O(n+m).
    for (final tag in canonical.values) {
      final current = tagBox.get(tag.id);
      if (current == null ||
          current.tag != tag.tag ||
          !const ListEquality<String>().equals(current.userId, tag.userId)) {
        await tagBox.put(tag.id, tag);
      }
    }
    // Legacy direct writers may add UUIDs while the canonical writes await I/O.
    // Only remove keys that belonged to this migration's original snapshot.
    final obsolete =
        sourceKeys.where((key) => !canonical.containsKey(key)).toList();
    if (obsolete.isNotEmpty) await tagBox.deleteAll(obsolete);
    final previousOrder = _tagOrderBox!.get('ids', defaultValue: <String>[])!;
    final order = <String>{
      for (final id in previousOrder)
        if (canonical.containsKey(_resolveTagId(id))) _resolveTagId(id),
      ...canonical.keys,
    }.toList();
    if (!const ListEquality().equals(previousOrder, order)) {
      await _tagOrderBox!.put('ids', order);
    }
  }

  Future<void> deleteFollowTag(String id) => runFollowTagMutation(() async {
        await _normalizeFollowTags();
        final resolved = _resolveTagId(id);
        await tagBox.delete(resolved);
        await _normalizeFollowTags();
        WebDavAutoSyncService.notifyLocalMutation();
      });

  Future<void> updateFollowTag(FollowUserTag followTag) =>
      runFollowTagMutation(() async {
        await _normalizeFollowTags();
        final id = _resolveTagId(followTag.id);
        final previous = tagBox.get(id);
        final tag = followTag.copyWith(
            id: id,
            userId: id != followTag.id && previous != null
                ? {...previous.userId, ...followTag.userId}.toList()
                : followTag.userId.toSet().toList());
        await tagBox.put(id, tag);
        await _normalizeFollowTags();
        WebDavAutoSyncService.notifyLocalMutation();
      });

  Future<FollowUserTag> addFollowTag(String tag) =>
      runFollowTagMutation(() async {
        await _normalizeFollowTags();
        // Uniqueness is independent of name length. Keep imported/legacy long
        // names intact instead of truncating distinct user-defined groups.
        final existing = getFollowTag(tag);
        if (existing != null) return existing;
        final item = FollowUserTag(id: uuid.v4(), tag: tag, userId: []);
        await tagBox.put(item.id, item);
        await _normalizeFollowTags();
        WebDavAutoSyncService.notifyLocalMutation();
        return tagBox.get(item.id)!;
      });

  Future<void> updateFollowTagOrder(List<FollowUserTag> userTagList) {
    // Copy at call time; the UI may mutate its RxList before this queue runs.
    final ids = userTagList.map((tag) => tag.id).toList();
    return runFollowTagMutation(() async {
      await _normalizeFollowTags();
      final current = getFollowTagList();
      final currentIds = current.map((tag) => tag.id).toSet();
      final order = <String>{
        for (final id in ids)
          if (currentIds.contains(_resolveTagId(id))) _resolveTagId(id),
        ...current.map((tag) => tag.id),
      }.toList();
      // A separate, lazily opened metadata box preserves both UUID keys and
      // ordering without clearing the tag box or dropping concurrently added tags.
      await _tagOrderBox!.put('ids', order);
      WebDavAutoSyncService.notifyLocalMutation();
    });
  }

  bool getFollowExist(String id) {
    return followBox.containsKey(id);
  }

  List<FollowUser> getFollowList() {
    return followBox.values.toList();
  }

  /// Move a platform-confirmed room alias and its tag memberships to the
  /// canonical follow key. Write the destination before removing the alias.
  Future<bool> mergeFollowRoom(FollowUser source, String roomId,
          {required bool Function() isCurrent}) =>
      runFollowTagMutation(() async {
        final id = '${source.siteId}_$roomId';
        if (id == source.id || !isCurrent()) return false;
        final target = followBox.get(id) ??
            FollowUser(
              id: id,
              roomId: roomId,
              siteId: source.siteId,
              userName: source.userName,
              face: source.face,
              addTime: source.addTime,
              tag: source.tag,
              categoryName: source.categoryName,
            );
        if (source.addTime.isBefore(target.addTime)) {
          target.addTime = source.addTime;
        }
        if (target.tag == '全部') target.tag = source.tag;
        target.categoryName = source.categoryName ?? target.categoryName;
        target.liveStatus.value = source.liveStatus.value;
        target.liveStartTime = source.liveStartTime;
        target.heat = source.heat;
        await followBox.put(id, target);
        for (final key in tagBox.keys.toList()) {
          final tag = tagBox.get(key);
          if (tag == null || !tag.userId.contains(source.id)) continue;
          final members =
              tag.userId.map((member) => member == source.id ? id : member);
          await tagBox.put(key, tag.copyWith(userId: members.toSet().toList()));
        }
        await followBox.delete(source.id);
        _followRoomAliases[source.id] = id;
        return true;
      });

  Future addFollow(FollowUser follow) async {
    await followBox.put(follow.id, follow);
    WebDavAutoSyncService.notifyLocalMutation();
  }

  /// Writes follow metadata cached from live status polling without triggering
  /// WebDAV auto-upload.
  Future addFollowSilently(FollowUser follow) async {
    await followBox.put(follow.id, follow);
  }

  /// 本轮关注刷新结束时一次性批量写入元数据，减少逐条写入磁盘的开销。
  Future<void> putFollowsSilently(Map<String, FollowUser> entries) async {
    if (entries.isEmpty || !followBox.isOpen) return;
    await followBox.putAll(entries);
  }

  Future deleteFollow(String id) => deleteFollows([id]);

  Future<void> deleteFollows(Iterable<String> ids) =>
      runFollowTagMutation(() async {
        await followBox.deleteAll({
          ...ids,
          for (final id in ids)
            if (_followRoomAliases.containsKey(id)) _followRoomAliases[id]!,
        });
        WebDavAutoSyncService.notifyLocalMutation();
      });

  History? getHistory(String id) {
    if (historyBox.containsKey(id)) {
      return historyBox.get(id);
    }
    return null;
  }

  Future addOrUpdateHistory(History history) async {
    await historyBox.put(history.id, history);
  }

  List<History> getHistores() {
    var his = historyBox.values.toList();
    his.sort((a, b) => b.updateTime.compareTo(a.updateTime));
    return his;
  }
}
