import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class PendingHome extends HomeListController {
  PendingHome() : super(Sites.allSites.values.first);
  final calls = <Completer<List<LiveRoomItem>>>[];
  final pages = <int>[];
  @override
  Future<List<LiveRoomItem>> getData(int page, int pageSize) {
    pages.add(page);
    final request = Completer<List<LiveRoomItem>>();
    calls.add(request);
    return request.future;
  }
}

LiveRoomItem room(String id) =>
    LiveRoomItem(roomId: id, title: id, cover: '', userName: id);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('刷新已登记时普通加载不能插入第二页请求', () async {
    final c = PendingHome();
    final initial = c.loadData();
    c.calls.first.complete([room('old')]);
    await initial;
    final refresh = c.refreshData();
    final load = c.loadData();
    await Future<void>.delayed(Duration.zero);
    expect(c.calls.length, 2);
    expect(c.pages, [1, 1]);
    c.calls.last.complete([room('fresh')]);
    await Future.wait([refresh, load]);
    expect(c.currentPage, 2);
    expect(c.list.map((e) => e.roomId), ['fresh']);
  });
  test('加载中刷新应等待后重新请求第一页，不能被旧数据回填', () async {
    final c = PendingHome();
    final old = c.loadData();
    final refresh = c.refreshData();
    final again = c.refreshData();
    c.calls.first.complete([room('old')]);
    await old;
    await Future<void>.delayed(Duration.zero);
    expect(c.calls.length, 2);
    c.calls.last.complete([room('fresh')]);
    await Future.wait([refresh, again]);
    expect(c.list.map((e) => e.roomId), ['fresh']);
    expect(c.currentPage, 2);
  });
}
