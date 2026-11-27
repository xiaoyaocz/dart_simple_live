import 'dart:math' as math;

import 'package:media_kit/media_kit.dart';

/// Shared Windows high-quality video/audio defaults and physical FBO sizing.
class WindowsVideoQuality {
  static const Map<String, String> baseProperties = <String, String>{
    'audio-buffer': '0.5',
    'audio-resample-cutoff': '0.96',
    'scale': 'ewa_lanczossharp',
    'cscale': 'spline36',
    'dscale': 'mitchell',
    'correct-downscaling': 'yes',
    'linear-downscaling': 'yes',
    'sigmoid-upscaling': 'yes',
    'dither-depth': 'auto',
    'tone-mapping': 'bt.2446a',
    'hdr-compute-peak': 'yes',
    'deband': 'yes',
    'deband-iterations': '1',
    'deband-threshold': '35',
    'deband-range': '16',
    'deband-grain': '12',
  };

  /// Applies the shared Windows desktop quality baseline to [native].
  static Future<void> applyBaseProperties(NativePlayer native) async {
    for (final entry in baseProperties.entries) {
      await native.setProperty(entry.key, entry.value);
    }
  }

  /// Computes even physical FBO dimensions so mpv upscales directly to display pixels.
  static ({int width, int height})? computeOutputSize({
    required double viewportWidth,
    required double viewportHeight,
    required double devicePixelRatio,
    required int sourceWidth,
    required int sourceHeight,
    required int scaleMode,
  }) {
    if (!viewportWidth.isFinite ||
        !viewportHeight.isFinite ||
        !devicePixelRatio.isFinite ||
        viewportWidth <= 0 ||
        viewportHeight <= 0 ||
        devicePixelRatio <= 0 ||
        sourceWidth <= 0 ||
        sourceHeight <= 0) {
      return null;
    }

    final physW = viewportWidth * devicePixelRatio;
    final physH = viewportHeight * devicePixelRatio;
    double targetW;
    double targetH;
    if (scaleMode == 1) {
      targetW = physW;
      targetH = physH;
    } else {
      final aspect = switch (scaleMode) {
        3 => 16.0 / 9.0,
        4 => 4.0 / 3.0,
        _ => sourceWidth / sourceHeight,
      };
      if (physW / physH > aspect) {
        targetH = physH;
        targetW = physH * aspect;
      } else {
        targetW = physW;
        targetH = physW / aspect;
      }
    }

    if (targetW > 3840.0 || targetH > 2160.0) {
      final capScale = math.min(3840.0 / targetW, 2160.0 / targetH);
      targetW *= capScale;
      targetH *= capScale;
    }

    int evenClamped(double value, int minVal, int maxVal) {
      final even = value.round() & ~1;
      return even.clamp(minVal, maxVal);
    }

    return (
      width: evenClamped(targetW, 320, 3840),
      height: evenClamped(targetH, 180, 2160),
    );
  }
}
