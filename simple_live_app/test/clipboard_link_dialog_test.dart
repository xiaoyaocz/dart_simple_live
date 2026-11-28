import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  late Site original;
  setUp(() {
    original = Sites.allSites['douyin']!;
    Sites.allSites['douyin'] = Site(id: original.id, name: original.name,
        logo: original.logo, liveSite: LiveSite());
  });
  tearDown(() { Sites.allSites['douyin'] = original; });
  for (final size in [
    const Size(2560, 1600),
    const Size(1280, 720),
    const Size(390, 844),
    const Size(568, 320)
  ]) {
    for (final action in [
      'buttons',
      'title',
      'link',
      'topPadding',
      'bottomPadding',
      'outside'
    ]) {
      testWidgets('检测链接弹窗在$size内保持紧凑，操作$action正常工作', (tester) async {
        final link =
            'https://live.douyin.com/531854687617?${List.filled(100, 'source=long_tracking_value').join('&')}';
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform,
            (call) async {
          if (call.method == 'Clipboard.getData') return {'text': link};
          return null;
        });
        addTearDown(() {
          Get.delete<ParseController>(force: true);
          Get.reset();
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await tester.pumpWidget(GetMaterialApp(
          initialRoute: RoutePath.kTools,
          getPages: [
            GetPage(
                name: RoutePath.kTools,
                binding: BindingsBuilder(() {
                  Get.put(ParseController());
                }),
                page: () => const Scaffold(body: Text('链接解析'))),
            GetPage(
                name: RoutePath.kLiveRoomDetail,
                page: () => const Scaffold(body: Text('已进入直播间'))),
          ],
        ));
        await tester.pumpAndSettle();
        expect(find.text('检测到直播间链接'), findsOneWidget);
        final card = find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(Material))
            .first;
        final rect = tester.getRect(card);
        expect(rect.width, lessThanOrEqualTo(520));
        expect(rect.center.dx, closeTo(size.width / 2, 1));
        expect(rect.height, lessThanOrEqualTo(360));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
            link);
        final scroll = find
            .ancestor(
                of: find.byType(SelectableText),
                matching: find.byType(SingleChildScrollView))
            .first;
        expect(tester.getSize(scroll).height, lessThanOrEqualTo(144));
        await tester.drag(scroll, const Offset(0, -300));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(of: scroll, matching: find.byType(Scrollable))
            .first;
        expect(tester.state<ScrollableState>(scrollable).position.pixels,
            greaterThan(0));
        expect(find.text('留在此页'), findsOneWidget);
        expect(find.text('打开直播间'), findsOneWidget);
        if (action == 'outside') {
          final outside = rect.topLeft - const Offset(8, 8);
          await tester.tapAt(outside);
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tapAt(outside);
          await tester.pumpAndSettle();
          expect(find.text('已进入直播间'), findsNothing);
        } else if (action != 'buttons' || size.width == 1280) {
          if (action == 'buttons') {
            await tester.tap(find.text('打开直播间'));
          } else {
            final point = switch (action) {
              'title' => tester.getCenter(find.text('检测到直播间链接')),
              'link' => tester.getRect(scroll).topLeft + const Offset(30, 25),
              'topPadding' => rect.topLeft + const Offset(12, 12),
              _ => Offset(rect.center.dx, rect.bottom - 8),
            };
            // 右键双击不应触发；左键单击也不应导航。
            await tester.tapAt(point, buttons: kSecondaryMouseButton);
            await tester.pump(const Duration(milliseconds: 80));
            await tester.tapAt(point, buttons: kSecondaryMouseButton);
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            if (action == 'title') {
              await tester.tapAt(point);
              await tester.pump(const Duration(milliseconds: 400));
              expect(find.byType(AlertDialog), findsOneWidget);
            }
            await tester.tapAt(point);
            await tester.pump(const Duration(milliseconds: 80));
            expect(find.byType(AlertDialog), findsOneWidget);
            await tester.tapAt(point);
          }
          await tester.pumpAndSettle();
          expect(Get.parameters['roomId'], '531854687617');
          expect((Get.arguments as Site).id, 'douyin');
          expect(find.text('已进入直播间'), findsOneWidget);
          Get.back();
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('留在此页'));
          await tester.pumpAndSettle();
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(Get.currentRoute, RoutePath.kTools);
        Get.delete<ParseController>(force: true);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }
  }
}
