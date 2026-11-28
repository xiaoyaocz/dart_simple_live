import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';

class _Completer extends ImageStreamCompleter {}

class _StreamProvider extends ImageProvider<_StreamProvider> {
  var completer = _Completer();
  @override
  Future<_StreamProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream,
      _StreamProvider key, ImageErrorListener handleError) {
    completer = _Completer();
    stream.setCompleter(completer);
  }
}

class _CountingContent extends DanmakuContentItem {
  int spanReads = 0;
  _CountingContent(ImageProvider provider)
      : super('[看]', spans: [DanmakuSpan.image('[看]', provider)]);
  @override
  List<DanmakuSpan>? get spans {
    spanReads++;
    return super.spans;
  }
}

void main() {
  testWidgets(
      'pause detaches animated streams; resume reconnects; clear releases',
      (tester) async {
    final provider = _StreamProvider();
    late DanmakuController controller;
    await tester.pumpWidget(MaterialApp(
        home: DanmakuScreen(
            createdController: (c) => controller = c,
            option: const DanmakuOption(safeArea: false))));
    controller.addDanmaku(
        DanmakuContentItem('[看]', spans: [DanmakuSpan.image('[看]', provider)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(provider.completer.hasListeners, isTrue);
    controller.pause();
    await tester.pump();
    expect(provider.completer.hasListeners, isFalse);
    controller.resume();
    await tester.pump();
    expect(provider.completer.hasListeners, isTrue);
    controller.clear();
    await tester.pump();
    expect(provider.completer.hasListeners, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('messages added while paused do not start image streams',
      (tester) async {
    final provider = _StreamProvider();
    late DanmakuController controller;
    await tester.pumpWidget(MaterialApp(
        home: DanmakuScreen(
            createdController: (c) => controller = c,
            option: const DanmakuOption(safeArea: false))));
    controller.pause();
    controller.addDanmaku(DanmakuContentItem('[看]',
        type: DanmakuItemType.top,
        spans: [DanmakuSpan.image('[看]', provider)]));
    await tester.pump();
    // A settings/parent repaint must not restart streams in a paused room.
    controller.updateOption(controller.option.copyWith(fontSize: 30));
    await tester.pump();
    expect(provider.completer.hasListeners, isFalse);
    controller.resume();
    await tester.pump();
    expect(provider.completer.hasListeners, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(provider.completer.hasListeners, isFalse);
  });
  testWidgets(
      'inactive TickerMode releases image streams without changing manual pause',
      (tester) async {
    final provider = _StreamProvider();
    late DanmakuController controller;
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, value, child) =>
                TickerMode(enabled: value, child: child!),
            child: DanmakuScreen(
                createdController: (c) => controller = c,
                option: const DanmakuOption(safeArea: false)))));
    controller.addDanmaku(
        DanmakuContentItem('[看]', spans: [DanmakuSpan.image('[看]', provider)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(provider.completer.hasListeners, isTrue);
    enabled.value = false;
    await tester.pump();
    expect(provider.completer.hasListeners, isFalse);
    expect(controller.running, isTrue);
    enabled.value = true;
    await tester.pump();
    expect(provider.completer.hasListeners, isTrue);
    controller.pause();
    enabled.value = false;
    await tester.pump();
    enabled.value = true;
    await tester.pump();
    expect(provider.completer.hasListeners, isFalse);
    expect(controller.running, isFalse);
    await tester.pumpWidget(const SizedBox());
    enabled.dispose();
  });
  testWidgets(
      'first and repeated paints reuse the admitted image placeholder layout',
      (tester) async {
    late DanmakuController controller;
    await tester.pumpWidget(MaterialApp(
        home: DanmakuScreen(
            createdController: (c) => controller = c,
            option: const DanmakuOption(safeArea: false))));
    final content = _CountingContent(_StreamProvider());
    controller.addDanmaku(content);
    final admissionReads = content.spanReads;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.scrollDanmaku.single.inlineImageCount, 1);
    expect(content.spanReads, admissionReads,
        reason: 'painting must not traverse and lay out the spans again');
    await tester.pump(const Duration(milliseconds: 50));
    expect(content.spanReads, admissionReads);
    await tester.pumpWidget(const SizedBox());
  });
  for (final paused in [false, true]) {
    testWidgets(
        'burst has a shared active-item cap${paused ? ' while paused' : ''}',
        (tester) async {
      late DanmakuController controller;
      await tester.pumpWidget(MaterialApp(
          home: DanmakuScreen(
              createdController: (c) => controller = c,
              option:
                  const DanmakuOption(safeArea: false, massiveMode: true))));
      if (paused) controller.pause();
      controller
          .addDanmaku(DanmakuContentItem('top', type: DanmakuItemType.top));
      controller.addDanmaku(
          DanmakuContentItem('bottom', type: DanmakuItemType.bottom));
      controller.addDanmaku(SpecialDanmakuContentItem('special',
          duration: 10000,
          color: Colors.white,
          fontSize: 16,
          translateXTween: Tween<double>(begin: 0, end: 1),
          translateYTween: Tween<double>(begin: 0, end: 1)));
      for (var i = 0; i < 1500; i++) {
        controller.addDanmaku(DanmakuContentItem('burst $i', selfSend: i == 0));
      }
      expect(controller.staticDanmaku.length, 2);
      expect(controller.specialDanmaku.length, 1);
      expect(controller.scrollDanmaku.length, 997);
      expect(controller.scrollDanmaku.first.content.selfSend, isTrue);
      final rejected = _CountingContent(_StreamProvider());
      controller.addDanmaku(rejected);
      expect(rejected.spanReads, 0,
          reason: 'reject before layout/image allocation');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
          controller.scrollDanmaku.length +
              controller.staticDanmaku.length +
              controller.specialDanmaku.length,
          1000);
      controller.clear();
      controller.addDanmaku(DanmakuContentItem('after clear', selfSend: true));
      expect(controller.scrollDanmaku.length, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
