import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/home/home_platform_tab.dart';

void main() {
  testWidgets('单击切换，双击只发送一次当前平台刷新', (tester) async {
    var selected = 0, refreshed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomePlatformTab(
      onSelect: () => selected++,
      onRefresh: () => refreshed++,
      child: const Text('抖音'),
    ))));
    final tab = find.text('抖音');
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 350));
    expect(selected, 1);
    expect(refreshed, 0);
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 350));
    expect(selected, 1);
    expect(refreshed, 1);
  });
}
