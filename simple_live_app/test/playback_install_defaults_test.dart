import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/player_output_policy.dart';

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

  test('升级保留弹幕偏好，播放按源码中的自动策略执行', () async {
    final storage = LocalStorageService.instance;
    await storage.setValue(LocalStorageService.kDanmuEnable, true);
    await storage.setValue(LocalStorageService.kQualityLevel, 0);
    await storage.setValue(LocalStorageService.kQualityLevelCellular, 1);
    await storage.setValue(LocalStorageService.kPreferNativeFrameRate, true);
    await storage.settingsBox.putAll({
      LocalStorageService.kHardwareDecode: false,
      LocalStorageService.kPlayerCompatMode: true,
      LocalStorageService.kPlayerBufferSize: 16,
      LocalStorageService.kPlayerBufferMode: 2,
      LocalStorageService.kLiveCatchupEnable: false,
      LocalStorageService.kAutoDowngradeQuality: true,
      LocalStorageService.kStreamRouteProbeEnable: false,
      LocalStorageService.kBackgroundAudioOnly: false,
      LocalStorageService.kPlayerForceHttps: true,
    });
    final settings = Get.put(AppSettingsController());
    expect(settings.danmuEnable.value, isTrue);
    expect(settings.qualityLevel.value, 2);
    expect(settings.qualityLevelCellular.value, 2);
    expect(settings.preferNativeFrameRate.value, isFalse);
    expect(settings.hardwareDecode.value, isTrue);
    expect(settings.playerCompatMode.value, isFalse);
    expect(settings.playerBufferSize.value, Platform.isWindows ? 128 : 64);
    expect(settings.playerBufferMode.value, 0);
    expect(settings.liveCatchupEnable.value, isTrue);
    expect(settings.streamRouteProbeEnable.value, isTrue);
    expect(settings.backgroundAudioOnly.value, isTrue);
    expect(settings.playerForceHttps.value, isFalse);
    expect(storage.settingsBox.get(LocalStorageService.kQualityLevel), 0);
  });

  test('手机加载电脑导入配置继续使用自动驱动，不改写原存储', () async {
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
    expect(settings.customPlayerOutput.value, isFalse);
    expect(settings.videoOutputDriver.value, 'auto');
    expect(settings.audioOutputDriver.value, 'auto');
    expect(settings.videoHardwareDecoder.value, 'auto');
    expect(storage.settingsBox.get(LocalStorageService.kVideoOutputDriver),
        'libmpv');
    expect(storage.settingsBox.get('unrelated-preference'), 'retain');
  });

  test('电脑也忽略旧版手动驱动配置', () async {
    final storage = LocalStorageService.instance;
    await storage.settingsBox.putAll({
      LocalStorageService.kCustomPlayerOutput: true,
      LocalStorageService.kVideoOutputDriver: 'libmpv',
      LocalStorageService.kAudioOutputDriver: 'wasapi',
      LocalStorageService.kVideoHardwareDecoder: 'd3d11va',
    });
    final settings = Get.put(AppSettingsController(
        outputPolicy: const PlayerOutputPolicy('windows')));
    expect(settings.customPlayerOutput.value, isFalse);
    expect(settings.videoOutputDriver.value, 'auto');
    expect(settings.audioOutputDriver.value, 'auto');
    expect(settings.videoHardwareDecoder.value, 'auto');
  });
}
