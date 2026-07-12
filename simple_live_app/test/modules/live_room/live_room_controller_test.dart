import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resumes danmaku after returning from the background', () {
    final controller = LiveRoomController(
      pSite: Site(
        id: 'test',
        name: 'Test',
        logo: '',
        liveSite: LiveSite(),
      ),
      pRoomId: '1',
    );
    var pauseCount = 0;
    var clearCount = 0;
    var resumeCount = 0;

    controller.initDanmakuController(
      DanmakuController(
        onAddDanmaku: (_) {},
        onUpdateOption: (_) {},
        onPause: () => pauseCount++,
        onResume: () => resumeCount++,
        onClear: () => clearCount++,
      ),
    );

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(controller.isBackground, isTrue);
    expect(pauseCount, 1);
    expect(clearCount, 1);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(controller.isBackground, isFalse);
    expect(resumeCount, 1);
  });
}
