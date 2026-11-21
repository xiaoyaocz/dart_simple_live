import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native FPS priority defaults off and enabling survives storage reload',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('native-fps-preference-');
    Hive.init(directory.path);
    final storage = LocalStorageService();
    await storage.init();
    Get.put<LocalStorageService>(storage);
    try {
      final settings = AppSettingsController()..onInit();
      expect(settings.preferNativeFrameRate.value, isFalse);
      settings.setPreferNativeFrameRate(true);
      await storage.settingsBox.flush();
      expect((AppSettingsController()..onInit()).preferNativeFrameRate.value,
          isTrue);
    } finally {
      Get.reset();
      await Hive.close();
      if (!directory.absolute.path
          .startsWith(Directory.systemTemp.absolute.path)) {
        throw StateError('Test cleanup outside temp directory');
      }
      await directory.delete(recursive: true);
    }
  });
}
