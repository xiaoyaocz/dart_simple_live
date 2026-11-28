import 'package:simple_live_core/simple_live_core.dart';

typedef SimilarGameRooms = ({
  LiveSubCategory category,
  List<LiveRoomItem> rooms
});

class _Entry<T> {
  late final Future<T> future;
  DateTime?
      expires; // null while in flight: concurrent opens share the request.
}

/// On-demand only: never compete with startup playback by speculative prefetch.
class SimilarGameRoomsLoader {
  SimilarGameRoomsLoader({DateTime Function()? now})
      : _now = now ?? DateTime.now;
  static final shared = SimilarGameRoomsLoader();
  final DateTime Function() _now;
  final _results = <(LiveSite, String), _Entry<SimilarGameRooms?>>{};
  final _catalogs = <LiveSite, _Entry<List<LiveCategory>>>{};

  Future<SimilarGameRooms?> load(LiveSite site, LiveRoomDetail detail,
      {bool force = false}) {
    final id = detail.categoryId?.trim();
    final validId = id != null && id.isNotEmpty && id != '0';
    final douyinId = validId && RegExp(r'^[1-9]\d*,\d+$').hasMatch(id);
    final lookup = site is DouyinSite && !douyinId
        ? 'room:${detail.roomId}'
        : validId
            ? 'id:$id'
            : 'name:${detail.categoryName}';
    final key = (site, lookup);
    final previous = _results.remove(key);
    if (previous != null &&
        (previous.expires == null ||
            (!force && _now().isBefore(previous.expires!)))) {
      _results[key] = previous;
      return previous.future;
    }
    while (_results.length >= 16) {
      _results.remove(_results.keys.first);
    }
    if (force) _catalogs.remove(site);
    final entry = _Entry<SimilarGameRooms?>();
    _results[key] = entry;
    entry.future = _load(site, detail, validId, douyinId).then((value) {
      if (identical(_results[key], entry)) {
        if (value == null) {
          _results
              .remove(key); // Missing categories must be retried, not pinned.
        } else {
          entry.expires = _now().add(const Duration(seconds: 30));
        }
      }
      return value;
    }, onError: (Object error, StackTrace stack) {
      if (identical(_results[key], entry)) _results.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
    return entry.future;
  }

  Future<List<LiveCategory>> _categories(LiveSite site) {
    final previous = _catalogs.remove(site);
    if (previous != null &&
        (previous.expires == null || _now().isBefore(previous.expires!))) {
      _catalogs[site] = previous;
      return previous.future;
    }
    while (_catalogs.length >= 4) {
      _catalogs.remove(_catalogs.keys.first);
    }
    final entry = _Entry<List<LiveCategory>>();
    _catalogs[site] = entry;
    entry.future = Future<List<LiveCategory>>.sync(site.getCategores)
        .timeout(const Duration(seconds: 8))
        .then((value) {
      if (identical(_catalogs[site], entry)) {
        if (value.isEmpty) {
          _catalogs.remove(site);
        } else {
          entry.expires = _now().add(const Duration(minutes: 10));
        }
      }
      return value;
    }, onError: (Object error, StackTrace stack) {
      if (identical(_catalogs[site], entry)) _catalogs.remove(site);
      Error.throwWithStackTrace(error, stack);
    });
    return entry.future;
  }

  Future<SimilarGameRooms?> _load(
      LiveSite site, LiveRoomDetail detail, bool validId, bool douyinId) async {
    LiveSubCategory? selected;
    if ((validId &&
            RegExp(r'^[1-9]\d*$').hasMatch(detail.categoryId!.trim()) &&
            {'huya', 'douyu'}.contains(site.id)) ||
        (site is DouyinSite && douyinId)) {
      // These endpoints need only the leaf ID. Bilibili requires a real parent.
      selected = LiveSubCategory(
          id: detail.categoryId!.trim(),
          parentId: '',
          name: detail.categoryName ?? detail.leafCategoryName ?? '同类游戏');
    } else if (site is DouyinSite) {
      selected = await site
          .getRoomGameCategory(detail.roomId)
          .timeout(const Duration(seconds: 8));
    } else if (validId || detail.categoryName?.isNotEmpty == true) {
      final categories = await _categories(site);
      LiveSubCategory? byName;
      for (final parent in categories) {
        for (final category in parent.children) {
          if (validId && category.id == detail.categoryId!.trim())
            selected ??= category;
          if (category.name == detail.categoryName) byName ??= category;
        }
      }
      selected ??= byName;
    }
    if (selected == null) return null;
    final rooms = await site
        .getCategoryRooms(selected)
        .timeout(const Duration(seconds: 8));
    return (
      category: selected,
      rooms: List<LiveRoomItem>.unmodifiable(rooms.items)
    );
  }
}
