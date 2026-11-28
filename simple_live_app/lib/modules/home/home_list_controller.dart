import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class HomeListController extends BasePageController<LiveRoomItem> {
  final Site site;
  HomeListController(this.site);

  Future? _pendingLoad;
  Future? _pendingRefresh;
  bool _hasNext = true;
  bool _loadFailed = false;
  bool _closed = false;
  int _noProgressPages = 0;
  bool get canAutoLoad => !_loadFailed && !_closed;

  @override
  Future loadData() {
    // Once refresh is queued, a load-more event must not slip ahead of it.
    if (_pendingRefresh != null) return _pendingRefresh!;
    if (_closed || !_hasNext) return Future.value();
    return _pendingLoad ??= _load();
  }

  Future _load() async {
    if (_closed) return;
    final page = currentPage;
    loadding = true;
    _loadFailed = false;
    pageError.value = false;
    pageEmpty.value = false;
    pageLoadding.value = page == 1;
    try {
      final result = await getData(page, pageSize);
      if (_closed) return;
      // Deduplicate in O(existing + incoming) time. Recommendation feeds can
      // repeat a batch or filter every room in one batch as offline. Allow a
      // small gap, but stop after three no-progress pages to bound requests.
      final seen = list.map((room) => room.roomId).toSet();
      final added = result.where((room) => seen.add(room.roomId)).toList();
      list.addAll(added);
      currentPage = page + 1;
      _noProgressPages = added.isEmpty ? _noProgressPages + 1 : 0;
      _hasNext = _hasNext && _noProgressPages < 3;
      canLoadMore.value = _hasNext;
      pageEmpty.value = list.isEmpty;
    } catch (error) {
      if (_closed) return;
      _loadFailed = true;
      handleError(error, showPageError: page == 1);
    } finally {
      loadding = false;
      if (!_closed) pageLoadding.value = false;
      _pendingLoad = null;
    }
  }

  // Coalesce repeated refreshes. Never clear/reset pagination while an older
  // request is still running, otherwise it can overwrite the new first page.
  @override
  Future refreshData() => _pendingRefresh ??= _refresh();

  Future _refresh() async {
    try {
      await _pendingLoad;
      if (_closed) return;
      currentPage = 1;
      _hasNext = true;
      _noProgressPages = 0;
      _loadFailed = false;
      canLoadMore.value = false;
      list.value = [];
      // Bypass the public loadData refresh gate to avoid awaiting ourselves.
      await (_pendingLoad ??= _load());
    } finally {
      _pendingRefresh = null;
    }
  }

  @override
  Future<List<LiveRoomItem>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getRecommendRooms(page: page);
    if (!_closed) _hasNext = result.hasMore;
    return result.items;
  }

  @override
  void onClose() {
    _closed = true;
    super.onClose();
  }
}
