import 'package:media_kit_video/media_kit_video.dart';

/// Choices supported by the app's embedded video backend, not every standalone
/// mpv output. In particular, Android JNI surfaces cannot use desktop libmpv VO.
class PlayerOutputPolicy {
  final String platform;
  const PlayerOutputPolicy(this.platform);

  Map<String, String> get videoOutputs => {
        'auto': '自动匹配（推荐）',
        if (platform == 'android') ...{
          'gpu': 'gpu',
          'mediacodec_embed': 'mediacodec_embed（硬解直出）',
        } else
          'libmpv': 'libmpv',
      };

  String get _defaultAudio => switch (platform) {
        'android' => 'audiotrack',
        'windows' => 'wasapi',
        'ios' => 'audiounit',
        'macos' => 'coreaudio',
        'linux' => 'pulse',
        _ => 'auto',
      };

  Map<String, String> get audioOutputs => {
        'auto': '自动匹配（推荐）',
        if (_defaultAudio != 'auto') _defaultAudio: _defaultAudio,
        if (platform == 'android') ...{
          'opensles': 'opensles',
          'aaudio': 'aaudio',
        },
        if (platform == 'windows') ...{
          'directsound': 'directsound',
          'winmm': 'winmm',
        },
        if (platform == 'linux') 'alsa': 'alsa',
      };

  Map<String, String> get hardwareDecoders => {
        'auto': '自动匹配（推荐）',
        for (final value in [
          'no',
          'yes',
          'auto-safe',
          'auto-copy',
          if (platform == 'android') ...['mediacodec', 'mediacodec-copy'],
          if (platform == 'windows') ...[
            'd3d11va',
            'd3d11va-copy',
            'dxva2',
            'dxva2-copy',
            'nvdec',
            'nvdec-copy',
          ],
          if (platform == 'ios' || platform == 'macos') ...[
            'videotoolbox',
            'videotoolbox-copy',
          ],
          if (platform == 'linux') ...[
            'vaapi',
            'vaapi-copy',
            'vdpau',
            'vdpau-copy',
            'nvdec',
            'nvdec-copy',
          ],
        ])
          value: value,
      };

  String videoSelection(String value) =>
      videoOutputs.containsKey(value) ? value : 'auto';
  String audioSelection(String value) =>
      audioOutputs.containsKey(value) ? value : 'auto';
  String decoderSelection(String value) =>
      hardwareDecoders.containsKey(value) ? value : 'auto';

  String audioOutput(String value) =>
      audioSelection(value) == 'auto' ? _defaultAudio : value;

  VideoControllerConfiguration videoConfiguration({
    required bool custom,
    required bool compatibility,
    required bool hardwareDecode,
    required String videoOutput,
    required String hardwareDecoder,
  }) {
    if (custom) {
      final vo = videoSelection(videoOutput);
      final hwdec = decoderSelection(hardwareDecoder);
      return VideoControllerConfiguration(
        vo: vo == 'auto' ? null : vo,
        // Direct MediaCodec output requires the matching non-copy decoder.
        hwdec: vo == 'mediacodec_embed'
            ? 'mediacodec'
            : hwdec == 'auto'
                ? null
                : hwdec,
      );
    }
    if (platform == 'android' && compatibility) {
      return const VideoControllerConfiguration(
          vo: 'mediacodec_embed', hwdec: 'mediacodec');
    }
    // Leave platform defaults to the installed media_kit_video implementation.
    return VideoControllerConfiguration(
        enableHardwareAcceleration: hardwareDecode);
  }
}
