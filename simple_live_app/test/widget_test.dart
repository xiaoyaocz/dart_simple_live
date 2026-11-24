import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget harness renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Simple Live'))),
    );

    expect(find.text('Simple Live'), findsOneWidget);
  });
}
