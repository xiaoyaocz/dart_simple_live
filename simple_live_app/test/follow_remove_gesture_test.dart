import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

FollowUser _user() => FollowUser(id: 'huya_1', roomId: '1', siteId: 'huya',
    userName: '测试主播', face: '', addTime: DateTime(2026));

class _Controller extends FollowUserController {
  int refreshes = 0;
  @override
  Future<void> refreshData() async { refreshes++; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Get.reset());

  Future<void> mount(WidgetTester tester, VoidCallback remove,
      {VoidCallback? open, TargetPlatform platform = TargetPlatform.windows}) async {
    await tester.pumpWidget(MaterialApp(theme: ThemeData(platform: platform), home: Scaffold(body: FollowUserItem(
        item: _user(), onRemove: remove, onTap: open))));
    await tester.pumpAndSettle();
  }

  testWidgets('电脑端左键单双击都不取消关注，也不进入直播间', (tester) async {
    var removed = 0, opened = 0;
    await mount(tester, () => removed++, open: () => opened++);
    final icon = find.byIcon(Remix.dislike_line);
    await tester.tap(icon);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(removed, 0);
    expect(opened, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('只有同一个取消图标的鼠标右键双击触发一次', (tester) async {
    var removed = 0, opened = 0;
    await mount(tester, () => removed++, open: () => opened++);
    final icon = find.byIcon(Remix.dislike_line);
    await tester.tap(icon, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 100));
    expect(removed, 0);
    await tester.tap(icon, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(removed, 1);
    expect(opened, 0);
  });
  testWidgets('间隔超时的两次右键单击不取消', (tester) async {
    var removed = 0;
    await mount(tester, () => removed++);
    final icon = find.byIcon(Remix.dislike_line);
    for (var i = 0; i < 2; i++) {
      await tester.tap(icon, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
    }
    expect(removed, 0);
  });
  testWidgets('手机端单击不操作，双击一次取消且不进入直播间', (tester) async {
    var removed = 0, opened = 0;
    await mount(tester, () => removed++, open: () => opened++, platform: TargetPlatform.android);
    await tester.tap(find.byIcon(Remix.dislike_line));
    await tester.pump(const Duration(milliseconds: 100));
    expect(removed, 0);
    await tester.tap(find.byIcon(Remix.dislike_line));
    await tester.pumpAndSettle();
    expect(removed, 1);
    expect(opened, 0);
  });
  test('免确认取消删除真实关注记录，并刷新列表', () async {
    final directory = await Directory.systemTemp.createTemp('follow-remove-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FollowUserAdapter());
    final box = await Hive.openBox<FollowUser>('follow');
    try {
      Get.put<DBService>(DBService()..followBox = box);
      final user = _user();
      await box.put(user.id, user);
      final controller = _Controller();
      await controller.removeItem(user, confirm: false);
      expect(box.containsKey(user.id), isFalse);
      expect(controller.refreshes, 1);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
