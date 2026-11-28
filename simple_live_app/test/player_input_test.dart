import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('handlePlayerShortcut', () {
    test('Enter opens composer, key repeat and key up do not', () {
      var opens = 0;
      for (final event in [
        const KeyDownEvent(physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter, timeStamp: Duration.zero),
        const KeyRepeatEvent(physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter, timeStamp: Duration.zero),
        const KeyUpEvent(physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter, timeStamp: Duration.zero),
      ]) {
        handlePlayerShortcut(event, onToggleDanmaku: () {},
          onToggleFullscreen: () {}, onComposeDanmaku: () => opens++);
      }
      expect(opens, 1);
    });
    test('D toggles danmaku', () {
      var toggled = false;

      final result = handlePlayerShortcut(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: LogicalKeyboardKey.keyD,
          timeStamp: Duration.zero,
        ),
        onToggleDanmaku: () => toggled = true,
        onToggleFullscreen: () {},
      );

      expect(result, KeyEventResult.handled);
      expect(toggled, isTrue);
    });

    test('F toggles fullscreen', () {
      var toggled = false;

      final result = handlePlayerShortcut(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyF,
          logicalKey: LogicalKeyboardKey.keyF,
          timeStamp: Duration.zero,
        ),
        onToggleDanmaku: () {},
        onToggleFullscreen: () => toggled = true,
      );

      expect(result, KeyEventResult.handled);
      expect(toggled, isTrue);
    });

    test('other keys are ignored', () {
      final result = handlePlayerShortcut(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
        onToggleDanmaku: () {},
        onToggleFullscreen: () {},
      );

      expect(result, KeyEventResult.ignored);
    });
  });

  group('volumeAfterScroll', () {
    test('scrolling up increases volume by five', () {
      expect(volumeAfterScroll(50, -1), 55);
    });

    test('volume stays within zero and one hundred', () {
      expect(volumeAfterScroll(100, -1), 100);
      expect(volumeAfterScroll(0, 1), 0);
    });
  });
}
