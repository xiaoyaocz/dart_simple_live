import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/live_message_content.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test('trial nickname comes from the build parameter, empty builds do not highlight', () {
    const configured = String.fromEnvironment('SELF_CHAT_NICKNAME');
    expect(SelfChatHighlight.matches(configured), configured.isNotEmpty);
    expect(SelfChatHighlight.matches('$configured-其他人'), isFalse);
  });
  test('only the confirmed complete nickname matches, never message text or a partial name', () {
    expect(SelfChatHighlight.matches('萧风', ownNickname: '萧风'), isTrue);
    expect(SelfChatHighlight.matches('其他萧风', ownNickname: '萧风'), isFalse);
    expect(SelfChatHighlight.matches('萧风2', ownNickname: '萧风'), isFalse);
    expect(SelfChatHighlight.matches('其他人', ownNickname: '萧风'), isFalse);
    expect(SelfChatHighlight.matches('', ownNickname: ''), isFalse);
    expect(SelfChatHighlight.matches('抖音昵称', ownNickname: '', extraNicknames: ['抖音昵称']), isTrue);
    expect(SelfChatHighlight.matches('其他人', ownNickname: '', extraNicknames: ['抖音昵称', '']), isFalse);
    expect(SelfChatHighlight.matches('', ownNickname: '', extraNicknames: ['']), isFalse);
  });
  for (final brightness in Brightness.values) {
    testWidgets('$brightness own message has soft rounded highlight and normal-sized body without animations', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness),
          home: const Scaffold(body: SizedBox(width: 300,
              child: SelfChatHighlight(child: LiveMessageContent(
                  userName: '萧风', parts: [LiveMessagePart.text('测试弹幕')],
                  fontSize: 18, color: Colors.black, isSelf: true))))));
      expect(find.text('我'), findsOneWidget);
      final rich = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.textSpan != null));
      final span = rich.textSpan! as TextSpan;
      final name = span.children!.whereType<TextSpan>().first;
      final body = span.children!.whereType<TextSpan>().last;
      expect(name.style!.fontWeight, FontWeight.w600);
      expect(body.style!.fontWeight, FontWeight.normal);
      expect(span.style!.fontSize, 18);
      final box = tester.widget<DecoratedBox>(find.byKey(const ValueKey('self-chat-highlight')));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(10));
      expect(
        (decoration.gradient! as LinearGradient).colors,
        brightness == Brightness.light
            ? const [Color(0xFFEAF2FF), Color(0xFFF3ECFF)]
            : const [Color(0xFF1B2E45), Color(0xFF252440)],
      );
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('ordinary messages have neither own label nor bold nickname', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LiveMessageContent(
        userName: '其他人', parts: [LiveMessagePart.text('萧风你好')], fontSize: 18, color: Colors.black)));
    expect(find.text('我'), findsNothing);
    expect(find.byKey(const ValueKey('self-chat-highlight')), findsNothing);
    final rich = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.textSpan != null));
    final span = rich.textSpan! as TextSpan;
    expect((span.children!.last as TextSpan).style!.fontWeight, isNull,
        reason: 'Ordinary messages keep their original inherited font weight');
  });
}
