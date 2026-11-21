import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';

void main() {
  testWidgets('关闭手动配置时菜单不可打开，开启后保留原选择并可修改', (tester) async {
    var enabled = false;
    var value = 'auto';
    late StateSetter update;
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return SettingsMenu<String>(
          title: '视频输出驱动',
          value: value,
          valueMap: const {'auto': '自动匹配', 'libmpv': 'libmpv'},
          enabled: enabled,
          onChanged: (next) => update(() => value = next),
        );
      })),
    ));

    expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
    await tester.tap(find.text('视频输出驱动'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(value, 'auto');

    update(() => enabled = true);
    await tester.pump();
    await tester.tap(find.text('视频输出驱动'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('libmpv'));
    await tester.pumpAndSettle();
    expect(value, 'libmpv');

    update(() => enabled = false);
    await tester.pump();
    expect(value, 'libmpv');
    expect(find.text('libmpv'), findsOneWidget);
    await tester.tap(find.text('视频输出驱动'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('未指定 enabled 的原有菜单继续可用', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(
      body: SettingsMenu<String>(
        title: '音频输出',
        value: 'auto',
        valueMap: const {'auto': '自动匹配'},
        onChanged: (_) {},
      ),
    )));
    await tester.tap(find.text('音频输出'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
