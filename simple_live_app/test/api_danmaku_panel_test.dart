import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/api_danmaku_panel.dart';
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
    testWidgets('$site continuous manual sends retain next draft and single flight',
        (tester) async {
      final sender = _Sender();
      final sent = <String>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApiDanmakuPanel(
        siteId: site, roomId: '1', focusRequest: 1,
        resolveLoginView: () => null, senderFactory: (_) => sender,
        onMessageSent: sent.add,
      ))));
      await tester.pumpAndSettle();
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
    expect(find.text('请登录'), findsOneWidget);
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
