import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/player_output_policy.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('playback-defaults-');
    Hive.init(directory.path);
    await Get.put(LocalStorageService()).init();
  });
  tearDown(() async {
    Get.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('新安装默认关闭屏幕弹幕，WiFi和蜂窝最高画质，不被高帧率优先覆盖', () {
    final settings = Get.put(AppSettingsController());
    expect(settings.danmuEnable.value, isFalse);
    expect(settings.qualityLevel.value, 2);
    expect(settings.qualityLevelCellular.value, 2);
    expect(settings.preferNativeFrameRate.value, isFalse);
  });

  test('升级保留用户保存过的弹幕和画质偏好', () async {
    final storage = LocalStorageService.instance;
    await storage.setValue(LocalStorageService.kDanmuEnable, true);
    await storage.setValue(LocalStorageService.kQualityLevel, 0);
    await storage.setValue(LocalStorageService.kQualityLevelCellular, 1);
    await storage.setValue(LocalStorageService.kPreferNativeFrameRate, true);
    final settings = Get.put(AppSettingsController());
    expect(settings.danmuEnable.value, isTrue);
    expect(settings.qualityLevel.value, 0);
    expect(settings.qualityLevelCellular.value, 1);
    expect(settings.preferNativeFrameRate.value, isTrue);
  });

  test('手机加载电脑导入配置自动回退，菜单不包含电脑驱动，不改写原存储', () async {
    final storage = LocalStorageService.instance;
    await storage.settingsBox.putAll({
      LocalStorageService.kCustomPlayerOutput: true,
      LocalStorageService.kVideoOutputDriver: 'libmpv',
      LocalStorageService.kAudioOutputDriver: 'wasapi',
      LocalStorageService.kVideoHardwareDecoder: 'd3d11va',
      'unrelated-preference': 'retain',
    });
    final settings = Get.put(AppSettingsController(
        outputPolicy: const PlayerOutputPolicy('android')));
    expect(settings.customPlayerOutput.value, isTrue);
    expect(settings.videoOutputDriver.value, 'auto');
    expect(settings.audioOutputDriver.value, 'auto');
    expect(settings.videoHardwareDecoder.value, 'auto');
    final menus = OtherSettingsController();
    expect(menus.videoOutputDrivers.containsKey('libmpv'), isFalse);
    expect(menus.audioOutputDrivers.containsKey('wasapi'), isFalse);
    expect(menus.hardwareDecoder.containsKey('d3d11va'), isFalse);
    expect(storage.settingsBox.get(LocalStorageService.kVideoOutputDriver),
        'libmpv');
    expect(storage.settingsBox.get('unrelated-preference'), 'retain');
  });

  test('电脑合法手动配置保留，非法新选择保存为自动', () async {
    final storage = LocalStorageService.instance;
    await storage.settingsBox.putAll({
      LocalStorageService.kVideoOutputDriver: 'libmpv',
      LocalStorageService.kAudioOutputDriver: 'wasapi',
      LocalStorageService.kVideoHardwareDecoder: 'd3d11va',
    });
    final settings = Get.put(AppSettingsController(
        outputPolicy: const PlayerOutputPolicy('windows')));
    expect(settings.videoOutputDriver.value, 'libmpv');
    expect(settings.audioOutputDriver.value, 'wasapi');
    expect(settings.videoHardwareDecoder.value, 'd3d11va');
    settings.setVideoOutputDriver('mediacodec_embed');
    settings.setAudioOutputDriver('audiotrack');
    settings.setVideoHardwareDecoder('mediacodec');
    await storage.settingsBox.flush();
    expect(storage.settingsBox.get(LocalStorageService.kVideoOutputDriver),
        'auto');
    expect(storage.settingsBox.get(LocalStorageService.kAudioOutputDriver),
        'auto');
    expect(storage.settingsBox.get(LocalStorageService.kVideoHardwareDecoder),
        'auto');
  });
}
