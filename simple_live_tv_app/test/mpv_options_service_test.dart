import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';

class _TestSettingsController extends AppSettingsController {
  @override
  // These tests supply settings directly, without storage or platform setup.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Windows decoding and rendering', () {
    late AppSettingsController settings;

    setUp(() {
      settings = Get.put<AppSettingsController>(_TestSettingsController());
    });

    tearDown(Get.reset);

    test('turns hardware decoding off independently of GPU rendering', () {
      settings.hardwareDecode.value = false;
      settings.videoRenderingAcceleration.value = true;

      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'no');
      expect(configuration.enableHardwareAcceleration, isTrue);
    });

    test('uses copy-back hardware decoding with software rendering', () {
      settings.hardwareDecode.value = true;
      settings.videoRenderingAcceleration.value = false;

      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'auto-copy');
      expect(configuration.enableHardwareAcceleration, isFalse);
    });

    test('disables both hardware paths without changing the selected profile',
        () {
      settings.mpvProfile.value = 'quality';
      settings.hardwareDecode.value = false;
      settings.videoRenderingAcceleration.value = false;

      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'no');
      expect(configuration.enableHardwareAcceleration, isFalse);
      expect(MpvOptionsService.effectiveOptions()['scale'], 'spline36');
    });

    test('retains the original decoder when both hardware paths are enabled',
        () {
      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'auto-safe');
      expect(configuration.enableHardwareAcceleration, isTrue);
    });
  }, skip: !Platform.isWindows);
}
