import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryDetailController extends BasePageController<LiveRoomItem> {
  final Site site;
  final LiveSubCategory subCategory;
  CategoryDetailController({required this.site, required this.subCategory});

  int _generation = 0;
  Future<void>? _pending;
  bool _hasNext = true;
  bool _loadFailed = false;
  bool _closed = false;
  bool get canAutoLoad => !_loadFailed && !_closed;

  @override
  Future<void> refreshData() {
    if (_closed) return Future.value();
    ++_generation;
    _pending = null;
    _hasNext = true;
    _loadFailed = false;
    loadding = false;
    currentPage = 1;
    canLoadMore.value = false;
    list.clear();
    return loadData();
  }

  @override
  Future<void> loadData() {
    if (_closed || !_hasNext) return Future.value();
    final pending = _pending;
    if (pending != null) return pending;
    final operation = _load(_generation, currentPage);
    _pending = operation;
    return operation.whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
  }

  Future<void> _load(int generation, int page) async {
    bool current() => !_closed && generation == _generation;
    loadding = true;
    _loadFailed = false;
    pageError.value = false;
    pageLoadding.value = page == 1;
    try {
      final result =
          await site.liveSite.getCategoryRooms(subCategory, page: page);
      if (!current()) return;
      final seen = list.map((room) => room.roomId).toSet();
      final added =
          result.items.where((room) => seen.add(room.roomId)).toList();
      list.addAll(added);
      currentPage = page + 1;
      // The API's hasMore is authoritative. A repeated/empty page cannot keep
      // automatic viewport filling alive forever, even if that flag is wrong.
      _hasNext = result.hasMore && added.isNotEmpty;
      canLoadMore.value = _hasNext;
      pageEmpty.value = list.isEmpty;
    } catch (error) {
      if (!current()) return;
      _loadFailed =
          true; // A user retry is allowed; automatic retries stop here.
      handleError(error, showPageError: page == 1);
    } finally {
      if (current()) {
        loadding = false;
        pageLoadding.value = false;
      }
    }
  }

  @override
  void onClose() {
    if (_closed) return;
    _closed = true;
    ++_generation;
    super.onClose();
  }
}
