import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/live_message_content.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  // The app has no counter: exercise real chat through repeated parent rebuilds.
  testWidgets('聊天在父组件反复重建和深浅主题变化后仍完整显示', (tester) async {
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    await tester.pumpWidget(ValueListenableBuilder<int>(
      valueListenable: revision,
      builder: (context, value, child) => MaterialApp(
        theme: value.isEven ? ThemeData.light() : ThemeData.dark(),
        home: Scaffold(body: LiveMessageContent(
          userName: '主播',
          parts: const [LiveMessagePart.text('直播消息 [未知表情]')],
          fontSize: 14,
          color: value.isEven ? Colors.black : Colors.white,
        )),
      ),
    ));
    for (var i = 1; i <= 50; i++) {
      revision.value = i;
      await tester.pump();
      expect(find.text('主播：直播消息 [未知表情]', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
