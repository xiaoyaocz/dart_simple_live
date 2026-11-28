import '../model/live_play_quality.dart';

/// Only numeric FPS metadata is accepted, never bitrate or marketing labels.
double? nativeFrameRate(Object? value) {
  double? fps;
  if (value is num) {
    fps = value.toDouble();
  } else if (value is String) {
    final parts = value.split('/');
    if (parts.length == 2) {
      final n = double.tryParse(parts[0]), d = double.tryParse(parts[1]);
      if (n != null && d != null && d > 0) fps = n / d;
    } else {
      fps = double.tryParse(value);
    }
  }
  return fps != null && fps.isFinite && fps > 0 && fps <= 1000 ? fps : null;
}

double? metadataFrameRate(dynamic metadata) {
  if (metadata is! Map) return null;
  for (final key in [
    'fps',
    'frame_rate',
    'frameRate',
    'FrameRate',
    'iFrameRate',
  ]) {
    final fps = nativeFrameRate(metadata[key]);
    if (fps != null) return fps;
  }
  return null;
}

/// O(n), stable tie-break preserves platform resolution/bitrate preference.
/// Unknown rates retain the existing choice when no FPS evidence is available.
int preferredNativeQuality(
  List<LivePlayQuality> qualities, {
  required int fallback,
  double displayHz = 0,
}) {
  var best = fallback;
  var bestFps = 0.0;
  final known = qualities.where((q) => nativeFrameRate(q.frameRate) != null);
  final canFit =
      displayHz > 0 && known.any((q) => q.frameRate! <= displayHz + 1);
  for (var i = 0; i < qualities.length; i++) {
    final fps = nativeFrameRate(qualities[i].frameRate);
    if (fps == null || (canFit && fps > displayHz + 1)) continue;
    if (fps > bestFps + 0.01) {
      bestFps = fps;
      best = i;
    }
  }
  return best;
}

class NativeHlsVariant {
  final Uri uri;
  final double frameRate;
  final int pixels, bandwidth;
  NativeHlsVariant(this.uri, this.frameRate, this.pixels, this.bandwidth);
}

/// HLS FRAME-RATE is advertised metadata; the decoder still verifies the input.
/// External audio/subtitles stay with the master to preserve track association.
List<NativeHlsVariant> nativeHlsVariants(Uri base, String text) {
  if (!text.trimLeft().startsWith('#EXTM3U')) return [];
  final variants = <NativeHlsVariant>[];
  Map<String, String>? pending;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      pending = {
        for (final m in RegExp(
          r'([A-Z0-9-]+)=("[^"]*"|[^,]*)',
        ).allMatches(line.substring(18)))
          m[1]!: m[2]!.replaceAll('"', ''),
      };
      if (pending.containsKey('AUDIO') ||
          pending.containsKey('SUBTITLES') ||
          pending.containsKey('VIDEO')) {
        return [];
      }
    } else if (line.isNotEmpty && !line.startsWith('#') && pending != null) {
      final fps = nativeFrameRate(pending['FRAME-RATE']);
      final uri = base.resolve(line);
      final size = (pending['RESOLUTION'] ?? '').split('x');
      final pixels = size.length == 2
          ? (int.tryParse(size[0]) ?? 0) * (int.tryParse(size[1]) ?? 0)
          : 0;
      if (fps != null && ['http', 'https'].contains(uri.scheme)) {
        variants.add(
          NativeHlsVariant(
            uri,
            fps,
            pixels,
            int.tryParse(
                  pending['AVERAGE-BANDWIDTH'] ?? pending['BANDWIDTH'] ?? '',
                ) ??
                0,
          ),
        );
      }
      pending = null;
    }
  }
  return variants;
}

NativeHlsVariant? preferredHlsVariant(
  Uri base,
  String text, {
  double displayHz = 0,
  double? maxFrameRate,
}) => chooseNativeHlsVariant(
  nativeHlsVariants(base, text),
  displayHz: displayHz,
  maxFrameRate: maxFrameRate,
);

NativeHlsVariant? chooseNativeHlsVariant(
  List<NativeHlsVariant> input, {
  double displayHz = 0,
  double? maxFrameRate,
}) {
  final variants = input
      .where((v) => maxFrameRate == null || v.frameRate <= maxFrameRate + 0.01)
      .toList();
  if (variants.isEmpty) return null;
  final fitting = variants
      .where((v) => displayHz <= 0 || v.frameRate <= displayHz + 1)
      .toList();
  final candidates = fitting.isEmpty ? variants : fitting;
  candidates.sort((a, b) {
    final fps = b.frameRate.compareTo(a.frameRate);
    if (fps != 0) return fps;
    final resolution = b.pixels.compareTo(a.pixels);
    return resolution != 0 ? resolution : b.bandwidth.compareTo(a.bandwidth);
  });
  return candidates.first;
}
