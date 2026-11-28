import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/modules/home/home_list_view.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;

class _RealNetwork extends HttpOverrides {}

class _Controller extends HomeListController {
  _Controller(super.site, this.networkZone);
  final Zone networkZone;
  @override
  Future<List<LiveRoomItem>> getData(int page, int pageSize) async {
    final rooms = await networkZone.run(() =>
        HttpOverrides.runWithHttpOverrides(
            () => super.getData(page, pageSize), _RealNetwork()));
    // Only covers use the bundled placeholder. Room IDs, live-status checks,
    // request parameters and pagination signals come from the real adapters.
    return [
      for (final room in rooms)
        LiveRoomItem(
          roomId: room.roomId,
          title: room.title,
          cover: '',
          userName: room.userName,
          online: room.online,
        )
    ];
  }

  @override
  void handleError(Object exception, {bool showPageError = false}) {
    errorMsg.value = exception.toString();
    pageError.value = showPageError;
    debugPrint('LIVE ERROR: $exception');
  }
}

// Opt-in real upstream verification; no account cookie or room mocks.
// flutter test --dart-define=LIVE_HOME_PAGINATION=true test/home_live_pagination_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final source in <LiveSite>[DouyinSite(), DouyuSite()]) {
    testWidgets('${source.id}真实推荐接口：大屏填满并下滚续载', (tester) async {
      late Zone networkZone;
      await tester.runAsync(() async {
        networkZone = Zone.current;
      });
      final originalDio = core.HttpClient.instance.dio;
      core.HttpClient.instance.dio = core.HttpClient().dio;
      CoreLog.enableLog = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2560, 1512);
      addTearDown(() {
        Get.delete<HomeListController>(tag: source.id, force: true);
        Get.reset();
        core.HttpClient.instance.dio.close(force: true);
        core.HttpClient.instance.dio = originalDio;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = _Controller(
          Site(id: source.id, name: source.name, logo: '', liveSite: source),
          networkZone);
      Get.put<HomeListController>(controller, tag: source.id);
      await tester.pumpWidget(GetMaterialApp(
          home: DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: Scaffold(
            body: TabBarView(children: [
          const SizedBox(),
          HomeListView(source.id),
        ])),
      )));
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 900; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump(const Duration(milliseconds: 100));
          if (ready()) return;
          if (!controller.loadding &&
              controller.currentPage > 1 &&
              !controller.canLoadMore.value) {
            fail('Upstream stopped with ${controller.list.length} rooms');
          }
          if (i % 100 == 0) {
            debugPrint(
                '${source.id}: rooms=${controller.list.length}, page=${controller.currentPage}, loading=${controller.loadding}, more=${controller.canLoadMore}, extentAfter=${controller.scrollController.hasClients ? controller.scrollController.position.extentAfter : -1}');
          }
        }
        fail('${source.id}: rooms=${controller.list.length}, '
            'page=${controller.currentPage}, more=${controller.canLoadMore}, '
            'error=${controller.errorMsg}');
      }

      await waitFor(() =>
          controller.list.length >= 100 &&
          !controller.loadding &&
          controller.scrollController.position.extentAfter > 200);
      // A fast upstream can fill the screen before EasyRefresh finishes its
      // initial header animation. Let that settle before imitating user scroll.
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final before = controller.list.length;
      final first = controller.list.first.roomId;
      controller.scrollController
          .jumpTo(controller.scrollController.position.maxScrollExtent);
      // A live upstream can reach its end between runs. At the bottom it must
      // either append rooms or finish pagination, never leave a pending load.
      await waitFor(() => controller.list.length > before ||
          (!controller.loadding && !controller.canLoadMore.value));
      expect(controller.list.first.roomId, first);
      expect(controller.list.map((room) => room.roomId).toSet().length,
          controller.list.length);
      debugPrint('${source.id} real viewport=$before rooms, '
          'after scroll=${controller.list.length}, page=${controller.currentPage}');
      await tester.pumpWidget(const SizedBox());
      Get.delete<HomeListController>(tag: source.id, force: true);
      Get.reset();
      await tester.pump(const Duration(minutes: 1));
    },
        skip: !const bool.fromEnvironment('LIVE_HOME_PAGINATION'),
        timeout: const Timeout(Duration(minutes: 4)));
  }
}
