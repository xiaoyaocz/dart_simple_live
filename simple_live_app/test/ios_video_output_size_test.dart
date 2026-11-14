import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/ios_video_output_size.dart';

void main() {
  group('calculateIosVideoOutputSize', () {
    test('limits a 4K landscape stream to a landscape iPhone screen', () {
      final result = calculateIosVideoOutputSize(
        sourceWidth: 3840,
        sourceHeight: 2160,
        screenPhysicalWidth: 2796,
        screenPhysicalHeight: 1290,
      );

      expect(result, const IosVideoOutputSize(2292, 1290));
    });

    test('limits a 4K portrait stream to a portrait iPhone screen', () {
      final result = calculateIosVideoOutputSize(
        sourceWidth: 2160,
        sourceHeight: 3840,
        screenPhysicalWidth: 1290,
        screenPhysicalHeight: 2796,
      );

      expect(result, const IosVideoOutputSize(1290, 2292));
    });

    test('does not enlarge a 1080p stream', () {
      final result = calculateIosVideoOutputSize(
        sourceWidth: 1920,
        sourceHeight: 1080,
        screenPhysicalWidth: 2796,
        screenPhysicalHeight: 1290,
      );

      expect(result, const IosVideoOutputSize(1920, 1080));
    });

    test('returns null for incomplete or unusable dimensions', () {
      expect(
        calculateIosVideoOutputSize(
          sourceWidth: 0,
          sourceHeight: 2160,
          screenPhysicalWidth: 2796,
          screenPhysicalHeight: 1290,
        ),
        isNull,
      );
      expect(
        calculateIosVideoOutputSize(
          sourceWidth: 1,
          sourceHeight: 1,
          screenPhysicalWidth: 2796,
          screenPhysicalHeight: 1290,
        ),
        isNull,
      );
      expect(
        calculateIosVideoOutputSize(
          sourceWidth: 3840,
          sourceHeight: 2160,
          screenPhysicalWidth: double.nan,
          screenPhysicalHeight: 1290,
        ),
        isNull,
      );
    });

    test('recalculates against the current screen orientation', () {
      final landscape = calculateIosVideoOutputSize(
        sourceWidth: 3840,
        sourceHeight: 2160,
        screenPhysicalWidth: 2796,
        screenPhysicalHeight: 1290,
      );
      final portrait = calculateIosVideoOutputSize(
        sourceWidth: 3840,
        sourceHeight: 2160,
        screenPhysicalWidth: 1290,
        screenPhysicalHeight: 2796,
      );

      expect(landscape, const IosVideoOutputSize(2292, 1290));
      expect(portrait, const IosVideoOutputSize(1290, 724));
      expect(landscape, isNot(portrait));
    });
  });
}
