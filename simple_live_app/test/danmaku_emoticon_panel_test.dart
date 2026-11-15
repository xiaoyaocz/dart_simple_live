import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/danmaku_emoticon_panel.dart';
import 'package:simple_live_app/services/room_emoticons.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  testWidgets(
      'image grid is multi-column, bounded and scrolls beyond the first screen',
      (tester) async {
    final catalog = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        fetch: () async => [
              for (var n = 0; n < 120; n++)
                LiveEmoticon(
                    text: '[表情$n]', url: 'https://fixture.example/$n.png')
            ]);
    addTearDown(catalog.dispose);
    await catalog.load();
    final image = MemoryImage(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='));
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                    width: 448,
                    height: 320,
                    child: DanmakuEmoticonPanel(
                        catalog: catalog,
                        imageProvider: (_) => image,
                        onSelected: (text) => selected = text))))));
    await tester.pumpAndSettle();
    final first = tester.getCenter(find.byTooltip('[表情0]'));
    final second = tester.getCenter(find.byTooltip('[表情1]'));
    expect(first.dy, second.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(find.byTooltip('[表情119]'), findsNothing);
    await tester.tap(find.byTooltip('[表情0]'));
    expect(selected, '[表情0]');
    await tester.drag(find.byType(GridView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('[表情119]'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Narrow/small windows still contain a grid rather than a tall list.
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 260,
                height: 180,
                child: DanmakuEmoticonPanel(
                    catalog: catalog,
                    imageProvider: (_) => image,
                    onSelected: (_) {})))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
