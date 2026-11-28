import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/widgets/live_message_content.dart';
import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';
import 'package:simple_live_app/widgets/danmaku/utils/utils.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAFklEQVR4nGP8z8DwnwEPYMInOXwUAAASWwIOH0pJXQAAAABJRU5ErkJggg==');

Future<Set<String>> _colors(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    image.dispose();
    final result = <String>{};
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i] > 240 && bytes[i + 1] < 10 && bytes[i + 2] < 10)
        result.add('red');
      if (bytes[i] < 10 && bytes[i + 1] > 240 && bytes[i + 2] < 10)
        result.add('green');
    }
    return result;
  }))!;
}

void main() {
  test('image layout and rerasterization retain the selected danmaku font', () {
    final content = DanmakuContentItem('文字[看]', spans: [
      const DanmakuSpan.text('文字'),
      DanmakuSpan.image('[看]', MemoryImage(_png))
    ]);
    final item = DanmakuItem(
        content: content, width: 0, height: 0, fontFamily: 'monospace');
    item.drawParagraphIfNeeded(20, 4, 1.5, 1);
    final paragraph = DmUtils.generateParagraph(
        content: content, fontSize: 20, fontWeight: 4, fontFamily: 'monospace');
    expect(item.width, closeTo(paragraph.maxIntrinsicWidth + 1.5, 0.01));
    paragraph.dispose();
    item.dispose();
  });
  for (final scroll in [false, true]) {
    testWidgets(
        '${scroll ? 'scrolling canvas' : 'chat'} paints both frames of a real animated GIF',
        (tester) async {
      final key = GlobalKey();
      final bytes =
          File('test/fixtures/emoticons/animated.gif').readAsBytesSync();
      final provider = MemoryImage(bytes);
      DanmakuController? controller;
      final content = scroll
          ? DanmakuScreen(
              createdController: (c) => controller = c,
              option: const DanmakuOption(
                  safeArea: false, fontSize: 28, strokeWidth: 0))
          : LiveMessageContent(
              userName: 'u',
              parts: [
                LiveMessagePart.image(const LiveEmoticon(
                    text: '[看]', url: 'https://cdn.example/a.gif'))
              ],
              fontSize: 28,
              color: Colors.black,
              imageProvider: (_) => provider);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RepaintBoundary(
                  key: key, child: SizedBox.expand(child: content)))));
      if (scroll)
        controller!.addDanmaku(DanmakuContentItem('[看]',
            spans: [DanmakuSpan.image('[看]', provider)]));
      final colors = <String>{};
      for (var i = 0; i < 12 && colors.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
        colors.addAll(await _colors(tester, key));
      }
      expect(colors, containsAll(['red', 'green']));
      controller?.clear();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('chat displays native image mixed with text in original order',
      (tester) async {
    final e = LiveEmoticon(text: '[看]', url: 'https://cdn.example/watch.gif');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LiveMessageContent(
      userName: '用户',
      parts: [
        const LiveMessagePart.text('你好'),
        LiveMessagePart.image(e),
        const LiveMessagePart.text('🙂')
      ],
      fontSize: 18,
      color: Colors.black,
      imageProvider: (_) => MemoryImage(_png),
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final rich =
        tester.widget<Text>(find.byType(Text).first).textSpan! as TextSpan;
    expect(rich.toPlainText(includePlaceholders: false), '用户：你好🙂');
    expect(rich.children!.whereType<WidgetSpan>().length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed chat image keeps its exact original label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LiveMessageContent(
      userName: 'u',
      parts: [
        LiveMessagePart.image(
            const LiveEmoticon(text: '[打call]', url: 'https://cdn.example/x'))
      ],
      fontSize: 18,
      color: Colors.black,
      imageProvider: (_) => MemoryImage(Uint8List.fromList([1, 2, 3])),
    )));
    await tester.pumpAndSettle();
    expect(find.text('[打call]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('canvas placeholder measures the image aspect ratio, not bracket text',
      () {
    final content = DanmakuContentItem('[打call]', spans: [
      DanmakuSpan.image('[打call]', MemoryImage(_png), aspectRatio: 2)
    ]);
    final paragraph = DmUtils.generateParagraph(
        content: content, fontSize: 20, fontWeight: 4);
    expect(paragraph.getBoxesForPlaceholders().single.toRect().width,
        closeTo(46, 0.1));
    expect(paragraph.maxIntrinsicWidth, closeTo(46, 0.1));
    paragraph.dispose();
  });
  testWidgets('scrolling image obtains frames and releases listeners on clear',
      (tester) async {
    late DanmakuController controller;
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 800,
            height: 300,
            child: DanmakuScreen(
              createdController: (c) => controller = c,
              option: const DanmakuOption(safeArea: false),
            ))));
    controller.addDanmaku(DanmakuContentItem('[看]',
        spans: [DanmakuSpan.image('[看]', MemoryImage(_png))]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
    final item = controller.scrollDanmaku.single;
    expect(item.inlineImageCount, 1);
    expect(item.loadedInlineImageCount, 1);
    controller.clear();
    await tester.pump();
    expect(item.inlineImageCount, 0);
    expect(controller.scrollDanmaku, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
