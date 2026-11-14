import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/mobile_safe_insets.dart';

void main() {
  const systemData = MediaQueryData(
    size: Size(400, 800),
    padding: EdgeInsets.fromLTRB(11, 60, 13, 24),
    viewPadding: EdgeInsets.fromLTRB(11, 60, 13, 24),
    systemGestureInsets: EdgeInsets.only(left: 16, right: 16, bottom: 24),
  );

  test('keeps a tall cutout and all system insets when extra space is zero',
      () {
    final result = mobilePageMediaQuery(
      systemData,
      topExtra: 0,
      bottomExtra: 0,
      isMobile: true,
    );
    expect(result, same(systemData));
    expect(result.padding.top, 60);
  });

  test('adds bounded page padding without changing physical or side insets',
      () {
    final result = mobilePageMediaQuery(
      systemData,
      topExtra: 80,
      bottomExtra: 80,
      isMobile: true,
    );
    expect(result.padding, const EdgeInsets.fromLTRB(11, 140, 13, 104));
    expect(result.viewPadding, systemData.viewPadding);
    expect(result.viewInsets, systemData.viewInsets);
    expect(result.systemGestureInsets, systemData.systemGestureInsets);
    expect(result.size, systemData.size);
    expect(systemData.padding.top, 60);

    final clamped = mobilePageMediaQuery(
      systemData,
      topExtra: -8,
      bottomExtra: 160,
      isMobile: true,
    );
    expect(clamped.padding, const EdgeInsets.fromLTRB(11, 60, 13, 104));
  });

  test('preserves landscape cutout padding on both sides', () {
    final landscape = systemData.copyWith(
      size: const Size(800, 400),
      padding: const EdgeInsets.fromLTRB(60, 0, 40, 24),
      viewPadding: const EdgeInsets.fromLTRB(60, 0, 40, 24),
    );
    final result = mobilePageMediaQuery(
      landscape,
      topExtra: 12,
      bottomExtra: 8,
      isMobile: true,
    );
    expect(result.padding, const EdgeInsets.fromLTRB(60, 12, 40, 32));
    expect(result.viewPadding, landscape.viewPadding);
  });

  test('does not add navigation space above the keyboard', () {
    final keyboardData = systemData.copyWith(
      padding: systemData.padding.copyWith(bottom: 0),
      viewInsets: const EdgeInsets.only(bottom: 300),
    );
    final result = mobilePageMediaQuery(
      keyboardData,
      topExtra: 12,
      bottomExtra: 80,
      isMobile: true,
    );
    expect(result.padding.top, 72);
    expect(result.padding.bottom, 0);
    expect(result.viewPadding.bottom, 24);
    expect(result.viewInsets.bottom, 300);
  });

  test('bypasses extra space for desktop or a video-only page', () {
    expect(
      mobilePageMediaQuery(
        systemData,
        topExtra: 80,
        bottomExtra: 80,
        isMobile: false,
      ),
      same(systemData),
    );
    const immersiveData = MediaQueryData(size: Size(800, 400));
    expect(
      mobilePageMediaQuery(
        immersiveData,
        topExtra: 80,
        bottomExtra: 80,
        isMobile: true,
        enabled: false,
      ),
      same(immersiveData),
    );
  });

  test('keeps iOS action-bar compaction separate from user compensation', () {
    final result = mobilePageMediaQuery(
      systemData,
      topExtra: 0,
      bottomExtra: 80,
      isMobile: true,
    );
    expect(mobileBottomActionInset(systemData, isIOS: true), 16);
    expect(mobileBottomActionInset(result, isIOS: true), 96);
    expect(mobileBottomActionInset(result, isIOS: false), 104);
    expect(
      mobileBottomActionInset(
        result.copyWith(size: const Size(800, 400)),
        isIOS: true,
      ),
      80,
    );
  });

  testWidgets('AppBar and NavigationBar consume extra space once',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const contentKey = Key('content');
    const searchKey = Key('search');
    const navigationKey = Key('navigation');
    var searchTaps = 0;
    final data = mobilePageMediaQuery(
      systemData,
      topExtra: 80,
      bottomExtra: 80,
      isMobile: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: data,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Rooms'),
            actions: [
              IconButton(
                key: searchKey,
                onPressed: () => searchTaps++,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          body: const SafeArea(child: SizedBox.expand(key: contentKey)),
          bottomNavigationBar: NavigationBar(
            height: 56,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home, key: navigationKey),
                label: 'Home',
              ),
              NavigationDestination(icon: Icon(Icons.favorite), label: 'Saved'),
            ],
          ),
        ),
      ),
    ));

    expect(tester.getCenter(find.byKey(searchKey)).dy, closeTo(168, 0.1));
    expect(tester.getTopLeft(find.byKey(contentKey)), const Offset(11, 196));
    expect(tester.getCenter(find.byKey(navigationKey)).dy, closeTo(668, 0.1));
    await tester.tap(find.byKey(searchKey));
    expect(searchTaps, 1);
    expect(tester.takeException(), isNull);
  });
}
