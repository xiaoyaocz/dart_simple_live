import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/compact_player_bar.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0, 280.0, 240.0, 160.0]) {
    testWidgets('keeps fullscreen and more actions reachable at ${width}dp',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var fullscreens = 0;
      var pauses = 0;
      var danmaku = 0;
      var volumes = 0;
      String? selection;
      const scrollKey = Key('primary-scroll');
      const volumeKey = Key('volume');
      const fullscreenKey = Key('fullscreen');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ColoredBox(
              color: Colors.black,
              child: CompactPlayerBar(
                scrollAreaKey: scrollKey,
                duration: '00:00:00',
                primaryActions: [
                  IconButton(
                    tooltip: 'Pause',
                    onPressed: () => pauses++,
                    icon: const Icon(Icons.pause),
                  ),
                  IconButton(
                    tooltip: 'Danmaku',
                    onPressed: () => danmaku++,
                    icon: const Icon(Icons.chat),
                  ),
                  IconButton(
                    key: volumeKey,
                    tooltip: 'Volume',
                    onPressed: () => volumes++,
                    icon: const Icon(Icons.volume_up),
                  ),
                ],
                overflowAction: PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (value) => selection = value,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                    PopupMenuItem(
                        value: 'settings', child: Text('Danmaku settings')),
                    PopupMenuItem(value: 'mute', child: Text('Mute')),
                  ],
                ),
                fullscreenAction: IconButton(
                  key: fullscreenKey,
                  tooltip: 'Fullscreen',
                  onPressed: () => fullscreens++,
                  icon: const Icon(Icons.fullscreen),
                ),
              ),
            ),
          ),
        ),
      ));

      final fullscreenRect = tester.getRect(find.byKey(fullscreenKey));
      expect(fullscreenRect.right, closeTo(width, 0.1));
      expect(fullscreenRect.width, 48);
      expect(fullscreenRect.height, 48);
      await tester.tap(find.byKey(fullscreenKey));
      expect(fullscreens, 1);
      await tester.tap(find.byTooltip('Pause'));
      expect(pauses, 1);
      if (width < 240) {
        await tester.drag(find.byKey(scrollKey), const Offset(-100, 0));
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.byTooltip('Danmaku'));
        expect(danmaku, 1);
      }
      await tester.tap(find.byKey(volumeKey));
      expect(volumes, 1);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Danmaku settings'), findsOneWidget);
      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      expect(selection, 'mute');
      if (width >= 393) {
        expect(find.text('00:00:00'), findsOneWidget);
      } else if (width <= 280) {
        expect(find.text('00:00:00'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hides duration for larger text without losing fullscreen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: CompactPlayerBar(
            duration: '123:45:56',
            primaryActions: [
              Icon(Icons.pause),
              Icon(Icons.chat),
              Icon(Icons.volume_up)
            ],
            overflowAction: Icon(Icons.more_horiz),
            fullscreenAction: Icon(Icons.fullscreen),
          ),
        ),
      ),
    ));
    expect(find.text('123:45:56'), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
