import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/modules/home/home_list_view.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Site extends LiveSite {
  int batchSize = 15;
  int calls = 0;
  int lastPage = 20;
  bool duplicate = false;
  bool fail = false;
  int? failPage;
  final emptyPages = <int>{};
  final repeatPages = <int>{};
  Duration latency = Duration.zero;
  Completer<LiveCategoryResult>? gate;
  final pages = <int>[];
  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    calls++;
    pages.add(page);
    if (gate != null) return gate!.future;
    if (fail || failPage == page) throw StateError('temporary');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return result(duplicate || repeatPages.contains(page) ? 1 : page,
        hasMore: page < lastPage,
        size: emptyPages.contains(page) ? 0 : batchSize);
  }
}

LiveCategoryResult result(int page, {bool hasMore = true, int size = 15}) =>
    LiveCategoryResult(
      hasMore: hasMore,
      items: List.generate(
          size,
          (i) => LiveRoomItem(
              roomId: '${page}_$i',
              title: '直播间$page-$i',
              cover: '',
              userName: '主播$i')),
    );

class _Controller extends HomeListController {
  _Controller(_Site source)
      : super(Site(id: 'douyin', name: '抖音', logo: '', liveSite: source));
  @override
  void handleError(Object exception, {bool showPageError = false}) {
    pageError.value = showPageError;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Get.reset());
  Future<void> mount(
      WidgetTester tester, _Controller controller, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put<HomeListController>(controller, tag: 'home');
    await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: HomeListView('home'))));
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final batch in [15, 30, 40, 120]) {
    testWidgets('首页每页$batch个房间时自动填满大窗口', (tester) async {
      final source = _Site()..batchSize = batch;
      final controller = _Controller(source);
      await mount(tester, controller, const Size(2000, 1100));
      expect(controller.list.length, greaterThanOrEqualTo(60));
      expect(source.calls, lessThan(10));
      final filled = source.calls;
      await tester.pump(const Duration(seconds: 2));
      expect(source.calls, filled);
    });
  }
  testWidgets('真实网络时序：空网格先布局，迟到第一页仍自动补满', (tester) async {
    final source = _Site()
      ..gate = Completer<LiveCategoryResult>()
      ..latency = const Duration(milliseconds: 250);
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2560, 1500));
    expect(source.calls, 1);
    expect(controller.list, isEmpty);
    final first = source.gate!;
    source.gate = null;
    first.complete(result(1));
    for (var frame = 0; frame < 70; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(source.calls, greaterThan(1));
    expect(controller.list.length, greaterThanOrEqualTo(84));
    debugPrint('迟到首屏：自动${source.calls}页，${controller.list.length}个房间');
  });
  testWidgets('扩大窗口继续补齐，普通重建不会反复加载', (tester) async {
    final source = _Site();
    final controller = _Controller(source);
    await mount(tester, controller, const Size(400, 600));
    final initial = source.calls;
    tester.view.physicalSize = const Size(2000, 1100);
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(source.calls, greaterThan(initial));
    expect(controller.list.length, greaterThanOrEqualTo(60));
    final filled = source.calls;
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(source.calls, filled);
  });
  testWidgets('接近底部自动加载下一页', (tester) async {
    final source = _Site();
    final controller = _Controller(source);
    await mount(tester, controller, const Size(800, 700));
    final initial = source.calls;
    final previous = controller.list.map((room) => room.roomId).toList();
    controller.scrollController
        .jumpTo(controller.scrollController.position.maxScrollExtent);
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(source.calls, greaterThan(initial));
    expect(controller.list.take(previous.length).map((room) => room.roomId),
        previous);
  });
  testWidgets('平台hasMore=false后不继续请求', (tester) async {
    final source = _Site()..lastPage = 1;
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2000, 1100));
    expect(source.calls, 1);
    expect(controller.canLoadMore.value, isFalse);
  });
  testWidgets('重复页没有新增房间就停止，不无限填屏', (tester) async {
    final source = _Site()..duplicate = true;
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2000, 1100));
    expect(source.calls, 4);
    expect(controller.list.length, 15);
    expect(controller.canLoadMore.value, isFalse);
  });
  testWidgets('抖音中间页过滤后为空但仍有后页，继续补满', (tester) async {
    final source = _Site()..emptyPages.add(2);
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2000, 1100));
    expect(controller.list.length, greaterThanOrEqualTo(60));
    expect(source.pages, contains(3));
    expect(
        controller.list.any((room) => room.roomId.startsWith('2_')), isFalse);
  });
  testWidgets('推荐偶发重复页后仍继续下一页，不在15个房间处停止', (tester) async {
    final source = _Site()..repeatPages.add(2);
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2000, 1100));
    expect(controller.list.length, greaterThanOrEqualTo(60));
    expect(controller.list.map((room) => room.roomId).toSet().length,
        controller.list.length);
  });
  testWidgets('连续空页即使误报还有更多也有上限', (tester) async {
    final source = _Site()..emptyPages.addAll([2, 3, 4, 5, 6]);
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2000, 1100));
    expect(source.calls, 4);
    expect(controller.list.length, 15);
    expect(controller.canLoadMore.value, isFalse);
  });
  testWidgets('自动翻页错误停止重试，保留已有列表供手动续载', (tester) async {
    final source = _Site()..failPage = 2;
    final controller = _Controller(source);
    await mount(tester, controller, const Size(2000, 1100));
    expect(source.calls, 2);
    expect(controller.list.length, 15);
    expect(controller.canLoadMore.value, isTrue);
    source.failPage = null;
    await controller.loadData();
    expect(source.pages.take(3), [1, 2, 2]);
  });
  test('并发加载共享同一页，不提前结束或重复请求', () async {
    final source = _Site()..gate = Completer<LiveCategoryResult>();
    final controller = _Controller(source);
    final first = controller.loadData();
    var completed = false;
    final second = controller.loadData().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 1);
    expect(completed, isFalse);
    source.gate!.complete(result(1));
    await Future.wait([first, second]);
    expect(controller.list.length, 15);
    controller.onClose();
  });
  test('末页停止后刷新仍重新请求第一页并清除旧列表', () async {
    final source = _Site()..lastPage = 1;
    final controller = _Controller(source);
    await controller.loadData();
    await controller.loadData();
    expect(source.pages, [1]);
    source.lastPage = 20;
    await controller.refreshData();
    expect(source.pages, [1, 1]);
    expect(controller.list.length, 15);
    expect(controller.canLoadMore.value, isTrue);
    await controller.loadData();
    expect(source.pages, [1, 1, 2]);
    expect(controller.list.length, 30);
    controller.onClose();
  });
  test('错误重试同一页，不跳页；关闭后不接收结果', () async {
    final source = _Site();
    final controller = _Controller(source);
    await controller.loadData();
    source.fail = true;
    await controller.loadData();
    expect(controller.currentPage, 2);
    source.fail = false;
    source.gate = Completer<LiveCategoryResult>();
    final pending = controller.loadData();
    controller.onClose();
    source.gate!.complete(result(2));
    await pending;
    expect(controller.list.length, 15);
  });
}
