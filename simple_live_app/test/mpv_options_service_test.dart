import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';

void main() {
  test('keeps direct d3d11va selection unchanged', () {
    expect(
      MpvOptionsService.parseOptions('--hwdec=d3d11va'),
      {'hwdec': 'd3d11va'},
    );
  });

  test('accepts an mpv-style decoder option line', () {
    expect(
      MpvOptionsService.parseOptions('--hwdec d3d11va'),
      {'hwdec': 'd3d11va'},
    );
  });

  test('uses the later option value for the same key', () {
    expect(
      MpvOptionsService.parseOptions(
        '--hwdec=auto-safe\n--hwdec=d3d11va',
      ),
      {'hwdec': 'd3d11va'},
    );
  });
}
