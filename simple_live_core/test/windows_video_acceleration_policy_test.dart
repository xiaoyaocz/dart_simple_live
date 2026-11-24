import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('Windows decoding and rendering policy', () {
    for (final decoding in [false, true]) {
      for (final rendering in [false, true]) {
        test('decoding=$decoding rendering=$rendering', () {
          final decision = WindowsVideoAccelerationPolicy.resolve(
            hardwareDecode: decoding,
            renderingAcceleration: rendering,
            requestedHwdec: 'd3d11va',
          );

          expect(
            decision.hwdec,
            decoding ? (rendering ? 'd3d11va' : 'd3d11va-copy') : 'no',
          );
          expect(
            decision.sourceOverride,
            !decoding
                ? 'hardwareDecode:off'
                : rendering
                ? isNull
                : 'renderAcceleration:copy-back',
          );
        });
      }
    }

    test('uses copy-back for known hardware decoders with software output', () {
      for (final decoder in ['d3d11va', 'dxva2', 'nvdec', 'cuda', 'vulkan']) {
        final decision = WindowsVideoAccelerationPolicy.resolve(
          hardwareDecode: true,
          renderingAcceleration: false,
          requestedHwdec: decoder,
        );

        expect(decision.hwdec, '$decoder-copy', reason: decoder);
      }
    });

    test(
      'automatic hardware decoding must also copy back for software output',
      () {
        for (final decoder in [null, '', 'auto', 'auto-safe', 'yes']) {
          final decision = WindowsVideoAccelerationPolicy.resolve(
            hardwareDecode: true,
            renderingAcceleration: false,
            requestedHwdec: decoder,
          );

          expect(decision.hwdec, 'auto-copy', reason: '$decoder');
        }
      },
    );

    test('preserves explicit software and compatible copy-back decoders', () {
      for (final decoder in [
        'no',
        'auto-copy',
        'd3d11va-copy',
        'dxva2-copy',
        'nvdec-copy',
      ]) {
        final decision = WindowsVideoAccelerationPolicy.resolve(
          hardwareDecode: true,
          renderingAcceleration: false,
          requestedHwdec: decoder,
        );

        expect(decision.hwdec, decoder);
        expect(decision.sourceOverride, isNull);
      }
    });

    test(
      'unknown or unsupported hardware falls back with a diagnostic reason',
      () {
        for (final decoder in ['unknown-decoder', 'vaapi', 'videotoolbox']) {
          final decision = WindowsVideoAccelerationPolicy.resolve(
            hardwareDecode: true,
            renderingAcceleration: false,
            requestedHwdec: decoder,
          );

          expect(decision.hwdec, 'no');
          expect(
            decision.sourceOverride,
            'renderAcceleration:software-fallback',
          );
        }
      },
    );

    test('keeps advanced decoder choices unchanged with GPU rendering', () {
      final decision = WindowsVideoAccelerationPolicy.resolve(
        hardwareDecode: true,
        renderingAcceleration: true,
        requestedHwdec: 'custom-decoder',
      );

      expect(decision.hwdec, 'custom-decoder');
      expect(decision.sourceOverride, isNull);
    });
  });
}
