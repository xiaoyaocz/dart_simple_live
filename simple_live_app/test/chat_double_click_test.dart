import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

// Render the real chat area without starting playback or loading other tabs.
class _ChatPage extends LiveRoomPage {
  @override
  final LiveRoomController controller;

  const _ChatPage(this.controller);

  @override
  Widget buildFollowList() => const SizedBox();

  @override
  Widget buildSettings() => const SizedBox();
}

void main() {
  for (final target in ['message', 'padding']) {
    testWidgets('left double-click on $target resumes chat at latest',
        (tester) async {
      Get.put<AppSettingsController>(_Settings());
      final controller =
          LiveRoomController(pSite: Sites.allSites['douyin']!, pRoomId: 'test');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        controller.scrollController.dispose();
        Get.reset();
      });
      controller.messages.addAll(List.generate(
          100,
          (i) => LiveMessage(
              type: LiveMessageType.chat,
              userName: 'User',
              message: 'message $i',
              color: LiveMessageColor.white)));
      controller.disableAutoScroll.value = true;
      await tester.pumpWidget(GetMaterialApp(
        home: Scaffold(
            body: Column(children: [_ChatPage(controller).buildMessageArea()])),
      ));
      final list = find.byType(ListView);
      final position = target == 'message'
          ? tester.getCenter(find.text('User：message 0', findRichText: true))
          : tester.getTopLeft(list) + const Offset(2, 2);

      Future<void> click(int buttons) => tester.tapAt(position,
          kind: PointerDeviceKind.mouse, buttons: buttons);

      // A single left click and a right double-click must not resume scrolling.
      await click(kPrimaryButton);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.disableAutoScroll.value, isTrue);
      await click(kSecondaryButton);
      await tester.pump(const Duration(milliseconds: 80));
      await click(kSecondaryButton);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.disableAutoScroll.value, isTrue);

      await click(kPrimaryButton);
      await tester.pump(const Duration(milliseconds: 80));
      await click(kPrimaryButton);
      await tester.pumpAndSettle();
      expect(controller.disableAutoScroll.value, isFalse);
      expect(controller.scrollController.offset,
          controller.scrollController.position.maxScrollExtent);
      expect(find.text('最新'), findsNothing);
    });
  }
}
