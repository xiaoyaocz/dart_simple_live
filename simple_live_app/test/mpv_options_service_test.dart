import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';

class _TestSettingsController extends AppSettingsController {
  @override
  // These tests supply settings directly, without storage or platform setup.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Windows decoding and rendering', () {
    late AppSettingsController settings;

    setUp(() {
      settings = Get.put<AppSettingsController>(_TestSettingsController());
    });

    tearDown(Get.reset);

    test('disables hardware decoding while keeping GPU rendering enabled', () {
      settings.hardwareDecode.value = false;
      settings.videoRenderingAcceleration.value = true;

      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'no');
      expect(configuration.enableHardwareAcceleration, isTrue);
    });

    test('keeps copy-back hardware decoding with software rendering', () {
      settings.hardwareDecode.value = true;
      settings.videoRenderingAcceleration.value = false;

      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'd3d11va-copy');
      expect(configuration.enableHardwareAcceleration, isFalse);
    });

    test('supports both hardware paths disabled', () {
      settings.hardwareDecode.value = false;
      settings.videoRenderingAcceleration.value = false;

      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'no');
      expect(configuration.enableHardwareAcceleration, isFalse);
    });

    test('decode off takes priority over custom, advanced and imported config',
        () {
      settings.hardwareDecode.value = false;
      settings.customPlayerOutput.value = true;
      settings.videoHardwareDecoder.value = 'dxva2-copy';
      settings.mpvAdvancedOptions.value = 'hwdec=auto-safe\nscale=bilinear';
      settings.importedMpvConfPath.value =
          File('test/fixtures/windows_hwdec_priority.conf').absolute.path;

      final effective = MpvOptionsService.effectiveOptionsWithSource();
      final configuration = MpvOptionsService.videoControllerConfiguration();

      expect(configuration.hwdec, 'no');
      expect(effective.options['hwdec'], 'no');
      expect(effective.source['hwdec'], 'hardwareDecode:off');
      expect(effective.options['scale'], 'spline36');
      expect(effective.source['scale'], 'conf');
    });

    test('turning decoding on restores normal config priority', () {
      settings.customPlayerOutput.value = true;
      settings.videoHardwareDecoder.value = 'dxva2-copy';
      settings.mpvAdvancedOptions.value = 'hwdec=auto-safe';
      settings.importedMpvConfPath.value =
          File('test/fixtures/windows_hwdec_priority.conf').absolute.path;
      settings.hardwareDecode.value = false;
      expect(MpvOptionsService.videoControllerConfiguration().hwdec, 'no');

      settings.hardwareDecode.value = true;

      final effective = MpvOptionsService.effectiveOptionsWithSource();
      expect(MpvOptionsService.videoControllerConfiguration().hwdec, 'd3d11va');
      expect(effective.source['hwdec'], 'conf');
    });

    test('normalizes the decoder selected by advanced options after merging',
        () {
      settings.videoRenderingAcceleration.value = false;
      settings.customPlayerOutput.value = true;
      settings.videoHardwareDecoder.value = 'd3d11va';
      settings.mpvAdvancedOptions.value = 'hwdec=dxva2';

      final effective = MpvOptionsService.effectiveOptionsWithSource();

      expect(
          MpvOptionsService.videoControllerConfiguration().hwdec, 'dxva2-copy');
      expect(effective.source['hwdec'],
          'renderAcceleration:copy-back(requested=dxva2, source=advanced)');
    });

    test('normalizes the imported decoder after advanced options', () {
      settings.videoRenderingAcceleration.value = false;
      settings.mpvAdvancedOptions.value = 'hwdec=dxva2';
      settings.importedMpvConfPath.value =
          File('test/fixtures/windows_hwdec_priority.conf').absolute.path;

      final effective = MpvOptionsService.effectiveOptionsWithSource();

      expect(MpvOptionsService.videoControllerConfiguration().hwdec,
          'd3d11va-copy');
      expect(effective.source['hwdec'],
          'renderAcceleration:copy-back(requested=d3d11va, source=conf)');
    });

    test('exposes the requested decoder when software output needs a fallback',
        () {
      settings.videoRenderingAcceleration.value = false;
      settings.mpvAdvancedOptions.value = 'hwdec=unknown-decoder';

      final effective = MpvOptionsService.effectiveOptionsWithSource();

      expect(MpvOptionsService.videoControllerConfiguration().hwdec, 'no');
      expect(effective.source['hwdec'],
          'renderAcceleration:software-fallback(requested=unknown-decoder, source=advanced)');
      expect(MpvOptionsService.diagnosticsSummary(),
          contains('renderAcceleration:software-fallback'));
    });

    test('reports requested rendering and effective decoder separately', () {
      settings.hardwareDecode.value = false;
      settings.videoRenderingAcceleration.value = true;

      final summary = MpvOptionsService.diagnosticsSummary();

      expect(summary, contains('renderAccelerationRequested=true'));
      expect(summary, contains('hwdec=no(hardwareDecode:off)'));
    });
  }, skip: !Platform.isWindows);
}
