import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/scrollable_sheet_body.dart';

Widget _app({required int itemCount, VoidCallback? onLastTap}) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.windows),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            constraints: const BoxConstraints(maxWidth: 600),
            builder: (_) => ScrollableSheetBody(
              showScrollbar: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  itemCount,
                  (index) => ListTile(
                    title: Text('item $index'),
                    onTap: index == itemCount - 1 ? onLastTap : () {},
                  ),
                ),
              ),
            ),
          ),
          child: const Text('open menu'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'mouse wheel reaches the last menu item in a short desktop window',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var tapped = false;
    await tester
        .pumpWidget(_app(itemCount: 16, onLastTap: () => tapped = true));
    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();

    expect(find.text('item 15').hitTestable(), findsNothing);
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isTrue);
    final position = tester.getCenter(find.byType(SingleChildScrollView));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: position);
    tester.binding.handlePointerEvent(PointerScrollEvent(
      position: position,
      scrollDelta: const Offset(0, 2000),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pumpAndSettle();

    expect(scrollbar.controller!.offset, greaterThan(0));
    expect(find.text('item 15').hitTestable(), findsOneWidget);
    await tester.tap(find.text('item 15'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    Navigator.of(tester.element(find.byType(ScrollableSheetBody))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ScrollableSheetBody), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'menu stays compact and adapts to resized windows and the keyboard',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(itemCount: 4));
    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();

    final scrollView = find.byType(SingleChildScrollView);
    expect(tester.getSize(scrollView).height, lessThan(300));
    expect(tester.getSize(scrollView).width, lessThanOrEqualTo(600));

    tester.view.physicalSize = const Size(400, 220);
    tester.view.viewInsets = const FakeViewPadding(bottom: 80);
    await tester.pumpAndSettle();
    expect(tester.getSize(scrollView).width, lessThanOrEqualTo(400));
    expect(tester.getBottomRight(scrollView).dy, lessThanOrEqualTo(140));
    expect(tester.takeException(), isNull);

    tester.view.resetViewInsets();
    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(scrollView).height, lessThan(300));
    expect(find.text('item 3').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
