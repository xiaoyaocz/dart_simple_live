import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/room_entry_warmup.dart';
import 'room_startup_cache_test.dart' show Source;

void main() {
  Widget widget(Source source) => MaterialApp(
      home: Center(
          child: RoomEntryWarmup(
              source: source,
              roomId: '1',
              child: const SizedBox(width: 100, height: 100))));
  testWidgets('停留180毫秒才预取，离开后取消，不因普通构建加载', (tester) async {
    final source = Source();
    await tester.pumpWidget(widget(source));
    expect(source.calls, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(source.calls, 0);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 200));
    expect(source.calls, 0);
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 180));
    expect(source.calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(source.calls, 1);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('销毁后取消预取计时器，按下卡片立即准备', (tester) async {
    final source = Source();
    await tester.pumpWidget(widget(source));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(400, 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(source.calls, 0);
    await mouse.removePointer();
    await tester.pumpWidget(widget(source));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(source.calls, 0); // 触屏滑动/按下不预取。
    final click = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await click.down(const Offset(400, 300));
    await click.up();
    await click.removePointer();
    await tester.pump();
    expect(source.calls, 1);
  });
}
