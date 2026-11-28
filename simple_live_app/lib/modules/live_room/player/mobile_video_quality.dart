import 'package:media_kit/media_kit.dart';

/// Shared mobile (Android / iOS) high-quality video/audio defaults.
class MobileVideoQuality {
  static const String androidAudioOutput = 'aaudio,audiotrack';

  static const Map<String, String> baseProperties = <String, String>{
    'audio-buffer': '0.3',
    'audio-resample-cutoff': '0.96',
    'scale': 'spline36',
    'cscale': 'spline36',
    'dscale': 'mitchell',
    'correct-downscaling': 'yes',
    'linear-downscaling': 'yes',
    'dither-depth': 'auto',
    'tone-mapping': 'bt.2446a',
  };

  static const Map<String, String> debandProperties = <String, String>{
    'deband': 'yes',
    'deband-iterations': '1',
    'deband-threshold': '35',
    'deband-range': '16',
    'deband-grain': '12',
  };

  /// Applies the shared mobile video/audio baseline to [native].
  static Future<void> applyBaseProperties(
    NativePlayer native, {
    bool isAndroid = false,
  }) async {
    for (final entry in baseProperties.entries) {
      await native.setProperty(entry.key, entry.value);
    }
    if (isAndroid) {
      await native.setProperty('ao', androidAudioOutput);
    }
  }

  /// Enables or disables lightweight debanding on mobile.
  static Future<void> applyDeband(
    NativePlayer native, {
    required bool enabled,
  }) async {
    if (!enabled) {
      await native.setProperty('deband', 'no');
      return;
    }
    for (final entry in debandProperties.entries) {
      await native.setProperty(entry.key, entry.value);
    }
  }
}
