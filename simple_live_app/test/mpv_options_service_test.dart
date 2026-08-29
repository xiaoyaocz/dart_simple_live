import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';

void main() {
  test('Windows allows disabling GPU texture to work around adapter mismatch',
      () {
    // Windows users can now disable GPU texture by disabling hardware decode
    // to work around D3D11 adapter mismatch issues (gray/white screen).
    expect(
      MpvOptionsService.useHardwareVideoTexture(
        isWindows: true,
        hardwareDecode: false,
      ),
      isFalse,
    );
    expect(
      MpvOptionsService.useHardwareVideoTexture(
        isWindows: true,
        hardwareDecode: true,
      ),
      isTrue,
    );
  });

  test('other desktop platforms keep following hardware decode setting', () {
    expect(
      MpvOptionsService.useHardwareVideoTexture(
        isWindows: false,
        hardwareDecode: true,
      ),
      isTrue,
    );
    expect(
      MpvOptionsService.useHardwareVideoTexture(
        isWindows: false,
        hardwareDecode: false,
      ),
      isFalse,
    );
  });

  test('Windows blocks hardware decoders that require a gpu video output', () {
    expect(
      MpvOptionsService.isHardwareDecoderAllowed(
        'd3d11va',
        isWindows: true,
      ),
      isFalse,
    );
    expect(
      MpvOptionsService.isHardwareDecoderAllowed(
        'd3d11va-copy',
        isWindows: true,
      ),
      isTrue,
    );
    expect(
      MpvOptionsService.isHardwareDecoderAllowed(
        'd3d11va',
        isWindows: false,
      ),
      isTrue,
    );
  });
}
