import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/api_danmaku_panel.dart';
import 'package:simple_live_app/modules/live_room/danmaku_composer.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/danmaku_sender.dart';
import 'package:simple_live_app/services/room_emoticons.dart';

class _Sender implements DanmakuSender {
  int calls = 0, disposals = 0, preparations = 0;
  String? lastText;
  Completer<DanmakuSendResult> result = Completer();
  @override
  void prepare() { preparations++; }
  @override
  Future<DanmakuSendResult> send(String text) {
    calls++;
    lastText = text;
    return result.future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  for (final site in ['bilibili', 'douyu', 'huya', 'douyin']) {
    testWidgets('$site Enter opens one lower-centered floating composer sharing draft and sender',
        (tester) async {
      final sender = _Sender();
      var requests = 0, factories = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return DesktopDanmakuShortcut(
          onCompose: () => setState(() => requests++),
          child: Scaffold(body: Column(children: [
            const Expanded(child: Center(child: Text('直播画面'))),
            ApiDanmakuPanel(siteId: site, roomId: '1', focusRequest: requests,
              resolveLoginView: () => null,
              senderFactory: (_) { factories++; return sender; }),
          ])),
        );
      })));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '共享草稿');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      final floating = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
      final field = tester.widget<TextField>(floating);
      expect(field.controller!.text, '共享草稿');
      expect(field.focusNode!.hasFocus, isTrue);
      final rect = tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(DanmakuComposer)));
      expect(rect.center.dx, 400);
      expect(rect.center.dy, greaterThan(400));
      expect(tester.getSize(find.byType(ApiDanmakuPanel)).height,
          tester.getSize(find.byType(DanmakuComposer).first).height,
          reason: 'no permanent status row below the inline input');
      expect(find.text('使用搜索网页的登录态发送'), findsNothing);
      expect(factories, 1, reason: 'no second platform session');
      rebuild(() => requests++);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget, reason: 'never stack composers');
      await tester.enterText(floating, '下一条');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(sender.lastText, '下一条');
      expect(sender.calls, 1);
      sender.result.complete(const DanmakuSendResult('rejected', '平台拒绝测试提示'));
      await tester.pumpAndSettle();
      expect(find.text('平台拒绝测试提示'), findsNothing);
      expect(find.descendant(of: find.byType(Dialog), matching: find.byTooltip('平台拒绝测试提示')), findsOneWidget);
      expect(field.controller!.text, '下一条');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '下一条');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      sender.result = Completer();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(sender.calls, 2);
      sender.result.complete(const DanmakuSendResult('sent', '平台已确认发送'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(sender.disposals, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$site continuous manual sends retain next draft and single flight',
        (tester) async {
      final sender = _Sender();
      final sent = <String>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApiDanmakuPanel(
        siteId: site, roomId: '1', focusRequest: 0,
        resolveLoginView: () => null, senderFactory: (_) => sender,
        onMessageSent: sent.add,
      ))));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      expect(sender.preparations, 1);
      await tester.enterText(find.byType(TextField), 'message 0');
      for (var i = 0; i < 12; i++) {
        sender.result = Completer();
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();
        expect(sender.lastText, 'message $i');
        await tester.enterText(find.byType(TextField), 'message ${i + 1}');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        expect(sender.calls, i + 1, reason: 'no implicit queue or parallel sends');
        sender.result.complete(const DanmakuSendResult('sent', '平台已确认发送'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
        expect(find.text('message ${i + 1}'), findsOneWidget);
      }
      expect(sent, List.generate(12, (i) => 'message $i'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(sender.disposals, 1);
    });
  }
  testWidgets('room change removes floating editor and emoji before releasing shared draft',
      (tester) async {
    final sender = _Sender();
    final sent = <String>[];
    var present = true, requests = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return Scaffold(body: present ? ApiDanmakuPanel(
        siteId: 'huya', roomId: '1', focusRequest: requests,
        resolveLoginView: () => null, senderFactory: (_) => sender,
        onMessageSent: sent.add,
      ) : const Text('新的直播间'));
    })));
    rebuild(() => requests++);
    await tester.pumpAndSettle();
    final floating = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(floating, '旧房间');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    final emoji = find.descendant(of: find.byType(Dialog), matching: find.byTooltip('表情'));
    await tester.tap(emoji);
    await tester.pump(const Duration(milliseconds: 300));
    rebuild(() => present = false);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('表情暂未就绪'), findsNothing);
    expect(find.text('新的直播间'), findsOneWidget);
    sender.result.complete(const DanmakuSendResult('sent', '旧结果'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(sender.disposals, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Huya common picker draft is encoded only for its own transport', (tester) async {
    final sender = _Sender();
    final emoticons = RoomEmoticons(platform:'huya',roomId:'1');
    addTearDown(emoticons.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ApiDanmakuPanel(
      siteId:'huya',roomId:'1',focusRequest:0,resolveLoginView:()=>null,
      emoticons:()=>emoticons,senderFactory:(_)=>sender))));
    await tester.enterText(find.byType(TextField),'你好[666]');
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    expect(sender.lastText,'你好/{66');
    sender.result.complete(const DanmakuSendResult('rejected','发送被拒绝'));
    await tester.pumpAndSettle();
    expect(find.text('你好[666]'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('API input never loads a live page and keeps drafts on failure',
      (tester) async {
    final sender = _Sender();
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ApiDanmakuPanel(
                siteId: 'bilibili',
                roomId: '1',
                focusRequest: 0,
                resolveLoginView: () => null,
                senderFactory: (_) => sender,
                onMessageSent: sent.add))));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    expect(sender.calls, 1);
    expect(sent, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    expect(sender.calls, 1);
    sender.result.complete(const DanmakuSendResult('login', '请登录'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('请登录'), findsNothing);
    expect(find.byTooltip('请登录'), findsOneWidget);
    expect(sent, isEmpty);
    sender.result = Completer();
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    sender.result.complete(const DanmakuSendResult('sent', '平台已确认发送'));
    await tester.pumpAndSettle();
    expect(sent, ['hello']);
    expect(find.text('hello'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(sender.disposals, 1);
  });
  testWidgets('close during submission ignores late completion',
      (tester) async {
    final sender = _Sender();
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ApiDanmakuPanel(
                siteId: 'douyu',
                roomId: '1',
                focusRequest: 0,
                resolveLoginView: () => null,
                senderFactory: (_) => sender,
                onMessageSent: sent.add))));
    await tester.enterText(find.byType(TextField), 'old room');
    await tester.tap(find.byTooltip('发送弹幕（Enter）'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    sender.result.complete(const DanmakuSendResult('sent', '平台已确认发送'));
    await tester.pump();
    expect(sent, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
