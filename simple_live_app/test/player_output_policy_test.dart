import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/player_output_policy.dart';

void main() {
  for (final platform in ['android', 'windows', 'ios', 'macos', 'linux']) {
    test('$platform 自动匹配视频和硬解，菜单不包含其他系统后端', () {
      final policy = PlayerOutputPolicy(platform);
      final config = policy.videoConfiguration(
          custom: true,
          compatibility: false,
          hardwareDecode: true,
          videoOutput: 'auto',
          hardwareDecoder: 'auto');
      expect(config.vo, isNull);
      expect(config.hwdec, isNull);
      expect(config.enableHardwareAcceleration, isTrue);
      expect(
          policy.videoOutputs.keys,
          platform == 'android'
              ? ['auto', 'gpu', 'mediacodec_embed']
              : ['auto', 'libmpv']);
      expect(policy.audioOutputs.containsKey('auto'), isTrue);
      expect(policy.hardwareDecoders.containsKey('auto'), isTrue);
    });
  }

  test('Android 接收电脑输出与硬解配置时回退自动，音频匹配 audiotrack', () {
    const policy = PlayerOutputPolicy('android');
    final config = policy.videoConfiguration(
        custom: true,
        compatibility: false,
        hardwareDecode: true,
        videoOutput: 'libmpv',
        hardwareDecoder: 'd3d11va');
    expect(config.vo, isNull);
    expect(config.hwdec, isNull);
    expect(policy.audioOutput('wasapi'), 'audiotrack');
    expect(policy.videoSelection('libmpv'), 'auto');
    expect(policy.decoderSelection('d3d11va'), 'auto');
  });

  test('Windows 不使用手机的兼容模式或 mediacodec 输出', () {
    const policy = PlayerOutputPolicy('windows');
    for (final custom in [false, true]) {
      final config = policy.videoConfiguration(
          custom: custom,
          compatibility: true,
          hardwareDecode: true,
          videoOutput: 'mediacodec_embed',
          hardwareDecoder: 'mediacodec');
      expect(config.vo, isNull);
      expect(config.hwdec, isNull);
    }
    expect(policy.audioOutput('audiotrack'), 'wasapi');
  });

  test('Android 保留合法手动配置，mediacodec_embed 必须匹配直出硬解', () {
    const policy = PlayerOutputPolicy('android');
    final manual = policy.videoConfiguration(
        custom: true,
        compatibility: false,
        hardwareDecode: true,
        videoOutput: 'gpu',
        hardwareDecoder: 'mediacodec-copy');
    expect(manual.vo, 'gpu');
    expect(manual.hwdec, 'mediacodec-copy');
    final embedded = policy.videoConfiguration(
        custom: true,
        compatibility: false,
        hardwareDecode: true,
        videoOutput: 'mediacodec_embed',
        hardwareDecoder: 'no');
    expect(embedded.vo, 'mediacodec_embed');
    expect(embedded.hwdec, 'mediacodec');
  });

  test('普通模式关闭硬解保留软解；兼容模式仅在 Android 生效', () {
    const policy = PlayerOutputPolicy('android');
    final software = policy.videoConfiguration(
        custom: false,
        compatibility: false,
        hardwareDecode: false,
        videoOutput: 'libmpv',
        hardwareDecoder: 'd3d11va');
    expect(software.enableHardwareAcceleration, isFalse);
    expect(software.vo, isNull);
    final compatible = policy.videoConfiguration(
        custom: false,
        compatibility: true,
        hardwareDecode: true,
        videoOutput: 'auto',
        hardwareDecoder: 'auto');
    expect(compatible.vo, 'mediacodec_embed');
    expect(compatible.hwdec, 'mediacodec');
  });

  test('空、未知或跨平台导入值回退自动，Apple 音频各自匹配', () {
    for (final platform in ['android', 'windows', 'macos', 'ios', 'linux']) {
      final policy = PlayerOutputPolicy(platform);
      for (final invalid in ['', 'null', 'not-a-driver']) {
        expect(policy.videoSelection(invalid), 'auto');
        expect(policy.decoderSelection(invalid), 'auto');
        expect(policy.audioSelection(invalid), 'auto');
      }
    }
    expect(const PlayerOutputPolicy('macos').audioOutput('auto'), 'coreaudio');
    expect(const PlayerOutputPolicy('ios').audioOutput('auto'), 'audiounit');
  });
}
