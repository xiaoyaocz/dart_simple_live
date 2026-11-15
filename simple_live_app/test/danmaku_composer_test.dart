import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/danmaku_composer.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/room_emoticons.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  testWidgets('removing the composer also dismisses its image popup',
      (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    late BuildContext context;
    late Route<void> route;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const Scaffold();
    })));
    final opened = showDanmakuComposer(context,
        draft: draft,
        send: () async => false,
        onRoute: (value) => route = value);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    Navigator.of(context).removeRoute(route);
    await tester.pumpAndSettle();
    await opened;
    expect(find.text('表情暂未就绪'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('platform image selection replaces the selection without sending',
      (tester) async {
    final draft = TextEditingController(text: 'abc')
      ..selection = const TextSelection(baseOffset: 1, extentOffset: 2);
    final catalog = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        fetch: () async => [
              const LiveEmoticon(
                  text: '[微笑]', url: 'https://fixture.example/smile.png')
            ]);
    addTearDown(draft.dispose);
    addTearDown(catalog.dispose);
    await catalog.load();
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: DanmakuComposer(
                    draft: draft,
                    emoticons: () => catalog,
                    send: () async {
                      sends++;
                      return false;
                    })))));
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    final panel =
        tester.getRect(find.byKey(const ValueKey('danmaku-emoticon-grid')));
    expect(panel.width, 448);
    expect(panel.height, 320);
    expect(panel.bottom, lessThan(tester.getRect(find.byType(TextField)).top));
    await tester.tap(find.byTooltip('[微笑]'));
    await tester.pumpAndSettle();
    expect(draft.text, 'a[微笑]c');
    expect(sends, 0);
    expect(find.byKey(const ValueKey('danmaku-emoticon-grid')), findsNothing);
    expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>(),
        isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('emoji menu has no separate login or account switch',
      (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DanmakuComposer(draft: draft, send: () async => false))));
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    expect(find.text('网页登录 / 切换账号'), findsNothing);
    expect(find.text('表情暂未就绪'), findsOneWidget);
  });
  testWidgets('Enter reopens after outside click, but not over another dialog',
      (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return DesktopDanmakuShortcut(
          onCompose: () => showDanmakuComposer(context,
              draft: draft, send: () async => false),
          child: const Scaffold(body: Center(child: Text('直播画面'))));
    })));
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(DanmakuComposer), findsOneWidget);
      await tester.enterText(find.byType(TextField), '草稿');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(DanmakuComposer), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(DanmakuComposer), findsNothing);
      await tester.tap(find.text('直播画面'));
      await tester.pump();
    }
    final other = showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('其他窗口')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuComposer), findsNothing);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await other;
  });
  testWidgets(
      'new draft typed while sending is kept and floating editor stays open',
      (tester) async {
    final draft = TextEditingController(text: 'first');
    addTearDown(draft.dispose);
    final result = Completer<bool>();
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const Scaffold();
    })));
    final composer =
        showDanmakuComposer(context, draft: draft, send: () => result.future);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'next');
    result.complete(true);
    await tester.pumpAndSettle();
    expect(draft.text, 'next');
    expect(find.byType(Dialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await composer;
  });
  testWidgets(
      'send completion closes its composer, not another dialog above it',
      (tester) async {
    final draft = TextEditingController(text: 'hello');
    addTearDown(draft.dispose);
    final result = Completer<bool>();
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const Scaffold();
    })));
    final composer =
        showDanmakuComposer(context, draft: draft, send: () => result.future);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    final other = showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('网页登录窗口')));
    await tester.pump(const Duration(milliseconds: 500));
    result.complete(true);
    await tester.pumpAndSettle();
    await composer;
    expect(find.text('网页登录窗口'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await other;
  });
  testWidgets('IME composition and empty draft do not submit', (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DanmakuComposer(
      draft: draft,
      send: () async {
        sends++;
        return true;
      },
    ))));
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    draft.value = const TextEditingValue(
        text: 'nihao', composing: TextRange(start: 0, end: 5));
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    expect(sends, 0);
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sends, 0, reason: 'IME提交动作不应被当作发送');
    draft.value = const TextEditingValue(text: '你好');
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pumpAndSettle();
    expect(sends, 1);
  });
  testWidgets('floating composer is lower centered without dimming the video',
      (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    var sends = 0;
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const Scaffold();
    })));
    final first = showDanmakuComposer(context, draft: draft, send: () async {
      sends++;
      return false;
    });
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byType(DanmakuComposer)).dx, 400);
    expect(tester.getCenter(find.byType(DanmakuComposer)).dy, greaterThan(420));
    expect(tester.getRect(find.byType(DanmakuComposer)).bottom,
        lessThanOrEqualTo(576));
    final barrier = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((barrier) => barrier.color != null);
    expect(barrier.every((barrier) => barrier.color!.a == 0), isTrue);
    await tester.enterText(find.byType(TextField), 'dfqq');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(sends, 1);
    expect(draft.text, 'dfqq');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await first;
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
      'success clears only sent draft; compact composer does not overflow',
      (tester) async {
    final draft = TextEditingController(text: 'hello');
    addTearDown(draft.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
          width: 280,
          child: DanmakuComposer(
            draft: draft,
            send: () async => true,
          )),
    ))));
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pumpAndSettle();
    expect(draft.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
