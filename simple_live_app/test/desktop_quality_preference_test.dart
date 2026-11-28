import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    Get.reset();
  });

  for (final preference in [0, 1, 2]) {
    test('桌面进入直播间使用画质偏好$preference，不触发原生网络检测', () async {
      final settings = Get.put<AppSettingsController>(_Settings());
      settings.qualityLevel.value = preference;
      settings.qualityLevelCellular.value = 99;
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls++;
        return ['mobile'];
      });
      // Only replace the external network API; use the real room quality path.
      final room =
          LiveRoomController(pSite: Sites.allSites['huya']!, pRoomId: '1');
      expect(await room.getQualityLevel(), preference);
      expect(await room.getQualityLevel(), preference);
      expect(nativeCalls, 0);
      room.scrollController.dispose();
    }, skip: Platform.isAndroid || Platform.isIOS);
  }
}
