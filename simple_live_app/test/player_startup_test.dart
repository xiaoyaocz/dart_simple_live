import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/live_room/player/windows_video_quality.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_app/services/windows_shader_assets.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Native implements NativePlayer {
  final properties = <String, String>{};
  int writes = 0;
  @override
  Future<void> setProperty(String property, String value,
      {bool waitForInitialization = true}) async {
    properties[property] = value;
    writes++;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
  @override
  final NativePlayer platform = _Native();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness with PlayerMixin {
  final _fake = _Player();
  @override
  Player get player => _fake;
}

class _AndroidHarness with PlayerMixin {
  final _fake = _Player();
  @override
  Player get player => _fake;
  @override
  bool get isWindowsPlayback => false;
  @override
  bool get isAndroidPlayback => true;
  @override
  bool get isIosPlayback => false;
  @override
  double get windowsDisplayHz => 120.0;
}

class _IosHarness with PlayerMixin {
  final _fake = _Player();
  @override
  Player get player => _fake;
  @override
  bool get isWindowsPlayback => false;
  @override
  bool get isAndroidPlayback => false;
  @override
  bool get isIosPlayback => true;
  @override
  double get windowsDisplayHz => 120.0;
}

class _AndroidMultiViewRuntime extends MultiViewTileRuntime {
  _AndroidMultiViewRuntime(super.index);
  @override
  bool get isWindowsPlayback => false;
  @override
  bool get isAndroidPlayback => true;
  @override
  bool get isIosPlayback => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.put<AppSettingsController>(_Settings());
    WindowsShaderAssets.testOverrideResolver = () => 'C:/shaders/FSRCNNX.glsl';
  });
  tearDown(() {
    WindowsShaderAssets.testOverrideResolver = null;
    Get.reset();
  });

  test('起播缓冲按平台配置，保留缓存上限与断流保护', () async {
    final controller = _Harness();
    await Future.wait([controller.initializePlayer(), controller.initializePlayer()]);
    final native = controller.player.platform as _Native;
    expect(native.properties['cache-pause-wait'], Platform.isWindows ? '0.5' : '0.8');
    expect(native.properties['cache-pause-initial'], 'yes');
    expect(native.properties['cache-pause'], 'yes');
    expect(native.properties['cache-secs'], Platform.isWindows ? '30' : '20');
    expect(native.properties['demuxer-max-back-bytes'],
        Platform.isWindows ? '16777216' : '8388608');
    expect(native.properties['cache-on-disk'], 'no');
    expect(native.properties['interpolation'], 'no');
    expect(native.properties['video-sync'], 'audio');
    expect(native.properties['audio-pitch-correction'], 'yes');
    expect(native.properties['audio-resample-cutoff'], '0.96');
    if (Platform.isWindows) {
      expect(native.properties['audio-buffer'], '0.5');
      expect(native.properties['scale'], 'ewa_lanczossharp');
      expect(native.properties['cscale'], 'spline36');
      expect(native.properties['dscale'], 'mitchell');
      expect(native.properties['correct-downscaling'], 'yes');
      expect(native.properties['linear-downscaling'], 'yes');
      expect(native.properties['sigmoid-upscaling'], 'yes');
      expect(native.properties['dither-depth'], 'auto');
      expect(native.properties['tone-mapping'], 'bt.2446a');
      expect(native.properties['hdr-compute-peak'], 'yes');
      expect(native.properties['deband'], 'yes');
      expect(native.properties['deband-iterations'], '1');
      expect(native.properties['deband-threshold'], '35');
      expect(native.properties['deband-range'], '16');
      expect(native.properties['deband-grain'], '12');
      expect(native.properties['glsl-shaders'], 'C:/shaders/FSRCNNX.glsl');
      expect(native.properties.containsKey('audio-exclusive'), isFalse);
      expect(native.properties.containsKey('ao'), isFalse);
    }
    expect(native.properties.containsKey('fps'), isFalse);
    expect(native.properties.containsKey('vf'), isFalse);
    expect(native.properties.containsKey('override-display-fps'), isFalse);
    final writes = native.writes;
    await controller.initializePlayer();
    expect(native.writes, writes);
  });

  test('Windows 增强开关可关闭超分、按需开启补帧与 WASAPI 独占', () async {
    if (!Platform.isWindows) return;
    final settings = AppSettingsController.instance;
    settings.windowsSuperResolution.value = false;
    settings.windowsInterpolation.value = true;
    settings.windowsAudioExclusive.value = true;

    final controller = _Harness();
    await controller.initializePlayer();
    final native = controller.player.platform as _Native;
    expect(native.properties['glsl-shaders'], '');
    expect(native.properties['video-sync'], 'display-resample');
    expect(native.properties['interpolation'], 'yes');
    expect(native.properties['tscale'], 'oversample');
    expect(native.properties['ao'], 'wasapi');
    expect(native.properties['audio-exclusive'], 'yes');
  });

  test('Windows 视口物理分辨率计算匹配 2K/4K/小窗与竖屏限制', () {
    expect(
      WindowsVideoQuality.computeOutputSize(
        viewportWidth: 1920,
        viewportHeight: 1080,
        devicePixelRatio: 1.3333333,
        sourceWidth: 1920,
        sourceHeight: 1080,
        scaleMode: 0,
      ),
      (width: 2560, height: 1440),
    );
    expect(
      WindowsVideoQuality.computeOutputSize(
        viewportWidth: 2560,
        viewportHeight: 1440,
        devicePixelRatio: 1.5,
        sourceWidth: 1920,
        sourceHeight: 1080,
        scaleMode: 0,
      ),
      (width: 3840, height: 2160),
    );
    expect(
      WindowsVideoQuality.computeOutputSize(
        viewportWidth: 640,
        viewportHeight: 360,
        devicePixelRatio: 1.0,
        sourceWidth: 1920,
        sourceHeight: 1080,
        scaleMode: 0,
      ),
      (width: 640, height: 360),
    );
    expect(
      WindowsVideoQuality.computeOutputSize(
        viewportWidth: 5120,
        viewportHeight: 2880,
        devicePixelRatio: 1.5,
        sourceWidth: 1920,
        sourceHeight: 1080,
        scaleMode: 0,
      ),
      (width: 3840, height: 2160),
    );
    expect(
      WindowsVideoQuality.computeOutputSize(
        viewportWidth: 1920,
        viewportHeight: 1080,
        devicePixelRatio: 1.0,
        sourceWidth: 1080,
        sourceHeight: 1920,
        scaleMode: 0,
      ),
      (width: 608, height: 1080),
    );
    expect(
      WindowsVideoQuality.computeOutputSize(
        viewportWidth: 1200,
        viewportHeight: 800,
        devicePixelRatio: 1.0,
        sourceWidth: 1920,
        sourceHeight: 1080,
        scaleMode: 1,
      ),
      (width: 1200, height: 800),
    );
  });

  test('多画面模式在 Windows 端对齐高画质缩放与去色带，不启用重着色器与独占音频', () async {
    final runtime = MultiViewTileRuntime(0);
    final fake = _Player();
    await runtime.configurePlayerForTest(fake);
    final native = fake.platform as _Native;
    expect(native.properties['interpolation'], 'no');
    expect(native.properties['video-sync'], 'audio');
    expect(native.properties['cache-secs'], Platform.isWindows ? '20' : '15');
    if (Platform.isWindows) {
      expect(native.properties['scale'], 'ewa_lanczossharp');
      expect(native.properties['cscale'], 'spline36');
      expect(native.properties['deband'], 'yes');
      expect(native.properties['audio-buffer'], '0.5');
      expect(native.properties['demuxer-max-back-bytes'], '8388608');
      expect(native.properties.containsKey('glsl-shaders'), isFalse);
      expect(native.properties.containsKey('audio-exclusive'), isFalse);
    }
  });

  test('Android 端应用轻量顶级画质基线、aaudio优先回退、0.8s起播与8MB回退缓冲', () async {
    final controller = _AndroidHarness();
    await controller.initializePlayer();
    final native = controller.player.platform as _Native;
    expect(native.properties['scale'], 'spline36');
    expect(native.properties['cscale'], 'spline36');
    expect(native.properties['dscale'], 'mitchell');
    expect(native.properties['correct-downscaling'], 'yes');
    expect(native.properties['linear-downscaling'], 'yes');
    expect(native.properties['dither-depth'], 'auto');
    expect(native.properties['tone-mapping'], 'bt.2446a');
    expect(native.properties['audio-buffer'], '0.3');
    expect(native.properties['audio-resample-cutoff'], '0.96');
    expect(native.properties['audio-pitch-correction'], 'yes');
    expect(native.properties['ao'], 'aaudio,audiotrack');
    expect(native.properties['deband'], 'yes');
    expect(native.properties['deband-iterations'], '1');
    expect(native.properties['deband-threshold'], '35');
    expect(native.properties['deband-range'], '16');
    expect(native.properties['deband-grain'], '12');
    expect(native.properties['interpolation'], 'no');
    expect(native.properties['video-sync'], 'audio');
    expect(native.properties['cache-pause-wait'], '0.8');
    expect(native.properties['cache-secs'], '20');
    expect(native.properties['demuxer-max-back-bytes'], '8388608');
    expect(native.properties['force-seekable'], 'yes');
    expect(native.properties.containsKey('glsl-shaders'), isFalse);
    expect(native.properties.containsKey('audio-exclusive'), isFalse);
    expect(native.properties.containsKey('override-display-fps'), isFalse);
  });

  test('iOS 端应用画质基线与去色带，不写入 Android 专属 ao/force-seekable', () async {
    final controller = _IosHarness();
    await controller.initializePlayer();
    final native = controller.player.platform as _Native;
    expect(native.properties['scale'], 'spline36');
    expect(native.properties['tone-mapping'], 'bt.2446a');
    expect(native.properties['deband'], 'yes');
    expect(native.properties['audio-buffer'], '0.3');
    expect(native.properties['cache-pause-wait'], '0.8');
    expect(native.properties['demuxer-max-back-bytes'], '8388608');
    expect(native.properties.containsKey('ao'), isFalse);
    expect(native.properties.containsKey('force-seekable'), isFalse);
  });

  test('手机端开关可关闭 Deband、开启与关闭高刷时间域平滑并复位帧率覆盖', () async {
    final settings = AppSettingsController.instance;
    settings.mobileDeband.value = false;
    settings.mobileInterpolation.value = true;
    final controller = _AndroidHarness();
    await controller.initializePlayer();
    final native = controller.player.platform as _Native;
    expect(native.properties['deband'], 'no');
    expect(native.properties['video-sync'], 'display-resample');
    expect(native.properties['interpolation'], 'yes');
    expect(native.properties['tscale'], 'oversample');
    expect(native.properties['override-display-fps'], '120.000');

    settings.mobileDeband.value = true;
    settings.mobileInterpolation.value = false;
    await controller.initializePlayer();
    // 已初始化情况下直接通过 Worker / 属性方法生效；新实例关闭平滑不保留 override-display-fps
    final disabled = _AndroidHarness();
    await disabled.initializePlayer();
    final native2 = disabled.player.platform as _Native;
    expect(native2.properties['deband'], 'yes');
    expect(native2.properties['interpolation'], 'no');
    expect(native2.properties['video-sync'], 'audio');
  });

  test('Android 多画面模式应用轻量画质与音频基线，保持4MB回退缓冲且不开去色带/补帧', () async {
    final runtime = _AndroidMultiViewRuntime(0);
    final fake = _Player();
    await runtime.configurePlayerForTest(fake);
    final native = fake.platform as _Native;
    expect(native.properties['scale'], 'spline36');
    expect(native.properties['cscale'], 'spline36');
    expect(native.properties['tone-mapping'], 'bt.2446a');
    expect(native.properties['audio-buffer'], '0.3');
    expect(native.properties['ao'], 'aaudio,audiotrack');
    expect(native.properties['interpolation'], 'no');
    expect(native.properties['video-sync'], 'audio');
    expect(native.properties['cache-secs'], '15');
    expect(native.properties['demuxer-max-back-bytes'], '4194304');
    expect(native.properties.containsKey('deband'), isFalse);
  });
}
