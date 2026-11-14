import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/desktop_startup_args.dart';

void main() {
  tearDown(() {
    DesktopStartupArgs.initialize(const []);
  });

  test('accepts the desktop minimum window size', () {
    DesktopStartupArgs.initialize(const [
      '--simple-live-window-left=10',
      '--simple-live-window-top=20',
      '--simple-live-window-width=200',
      '--simple-live-window-height=150',
    ]);

    final bounds = DesktopStartupArgs.startupWindowBounds;

    expect(bounds, isNotNull);
    expect(bounds!.width, 200);
    expect(bounds.height, 150);
  });

  test('rejects startup window sizes below the desktop minimum', () {
    DesktopStartupArgs.initialize(const [
      '--simple-live-window-left=10',
      '--simple-live-window-top=20',
      '--simple-live-window-width=199',
      '--simple-live-window-height=149',
    ]);

    expect(DesktopStartupArgs.startupWindowBounds, isNull);
  });
}
