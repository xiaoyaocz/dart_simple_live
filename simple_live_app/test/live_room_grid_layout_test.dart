import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/live_room_grid_layout.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test('keeps at least two cards on a phone-sized viewport', () {
    final layout = LiveRoomGridLayout.resolve(
      375,
      detailsExtent: 64,
    );

    expect(layout.crossAxisCount, 2);
    expect(layout.itemWidth, closeTo(169.5, 0.001));
    expect(
      layout.mainAxisExtent,
      closeTo(layout.itemWidth * 9 / 16 + 64, 0.001),
    );
  });

  test('adds columns as the available width grows', () {
    final tablet = LiveRoomGridLayout.resolve(
      1024,
      detailsExtent: 64,
    );
    final desktop = LiveRoomGridLayout.resolve(
      1920,
      detailsExtent: 64,
    );

    expect(tablet.crossAxisCount, 5);
    expect(desktop.crossAxisCount, 8);
    expect(desktop.itemWidth, greaterThan(tablet.itemWidth));
  });

  test('uses a finite fallback for unconstrained layouts', () {
    final layout = LiveRoomGridLayout.resolve(
      double.infinity,
      detailsExtent: 64,
    );

    expect(layout.crossAxisCount, 2);
    expect(layout.itemWidth, 176);
    expect(layout.mainAxisExtent, closeTo(163, 0.001));
  });

  testWidgets('room card keeps the title below a 16:9 cover', (tester) async {
    final site = Site(
      id: 'test',
      name: '测试平台',
      logo: 'assets/images/bilibili_2.png',
      liveSite: BiliBiliSite(),
    );
    final item = LiveRoomItem(
      roomId: '1',
      title: '直播标题',
      cover: '',
      userName: '主播名',
      online: 123,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200 / LiveRoomGridLayout.coverAspectRatio +
                  LiveRoomCard.detailsExtent,
              child: LiveRoomCard(site, item, onTap: () {}),
            ),
          ),
        ),
      ),
    );

    final cover = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(cover.aspectRatio, LiveRoomGridLayout.coverAspectRatio);
    expect(find.text('直播标题'), findsOneWidget);
    expect(find.text('主播名'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
