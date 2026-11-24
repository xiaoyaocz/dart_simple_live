import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('danmaku only schedules animation frames while active', (
    tester,
  ) async {
    late DanmakuController controller;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 200,
          child: DanmakuScreen(
            createdController: (value) => controller = value,
            option: DanmakuOption(safeArea: false),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    controller.addDanmaku(DanmakuContentItem('第一条弹幕'));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    controller.pause();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    controller.resume();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    controller.clear();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    controller.addDanmaku(DanmakuContentItem('恢复后弹幕'));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
