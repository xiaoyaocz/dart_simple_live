import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';

class _DelayedSubtitleEngine implements LiveSubtitleEngine {
  final stopped = Completer<void>();

  @override
  Future<void> start(
      {required String modelPath, required String language}) async {}

  @override
  Future<void> stop() => stopped.future;

  @override
  Stream<String> get textStream => const Stream<String>.empty();
}

class _TestSettingsController extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _QueuedSubtitleEngine implements LiveSubtitleEngine {
  final stops = <Completer<void>>[];
  int starts = 0;

  @override
  Future<void> start(
      {required String modelPath, required String language}) async {
    starts += 1;
  }

  @override
  Future<void> stop() {
    final stopped = Completer<void>();
    stops.add(stopped);
    return stopped.future;
  }

  @override
  Stream<String> get textStream => const Stream<String>.empty();
}

class _ControlledSubtitleService extends LiveSubtitleService {
  final inspections = <Completer<LiveSubtitleModelInfo?>>[];

  @override
  Future<LiveSubtitleModelInfo?> inspectModelPath(String path) {
    final inspected = Completer<LiveSubtitleModelInfo?>();
    inspections.add(inspected);
    return inspected.future;
  }
}

const _model = LiveSubtitleModelInfo(
  type: 'test',
  title: 'test',
  directory: 'models',
  keyFilePath: 'models/test.onnx',
  recommendedKeyFileName: 'test.onnx',
  requiredFileNames: [],
  missingFileNames: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('handoff waits for every sync even when the latest one finishes first',
      () async {
    final settings = Get.put<AppSettingsController>(_TestSettingsController());
    settings.liveSubtitleEnable.value = true;
    settings.liveSubtitleModelPath.value = 'models/test.onnx';
    final engine = _QueuedSubtitleEngine();
    final service = _ControlledSubtitleService()..setEngine(engine);
    final older = service.syncPreviewFromSettings(mediaUrl: 'first');
    final newer = service.syncPreviewFromSettings(mediaUrl: 'second');
    service.inspections[1].complete(_model);
    await newer;
    expect(engine.starts, 1);

    var closed = false;
    final closing = service.stopAndWait().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    expect(engine.stops, isEmpty);
    // No new settings task may enter the old shared engine during handoff.
    expect(await service.syncPreviewFromSettings(mediaUrl: 'late'), isFalse);
    expect(service.inspections.length, 2);

    service.inspections[0].complete(_model);
    await older;
    await Future<void>.delayed(Duration.zero);
    expect(engine.starts, 2);
    expect(engine.stops.length, 1);
    expect(closed, isFalse);
    engine.stops.single.complete();
    await closing;
    expect(closed, isTrue);
    expect(service.running.value, isFalse);
  });

  test('handoff includes a previously detached stop finishing out of order',
      () async {
    final engine = _QueuedSubtitleEngine();
    final service = LiveSubtitleService()..setEngine(engine);
    service.stop();
    expect(engine.stops.length, 1);
    var closed = false;
    final closing = service.stopAndWait().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(engine.stops.length, 2);
    engine.stops[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    engine.stops[0].complete();
    await closing;
    expect(closed, isTrue);
  });

  test('room handoff awaits the previous subtitle engine stop', () async {
    final engine = _DelayedSubtitleEngine();
    final service = LiveSubtitleService()..setEngine(engine);
    service.running.value = true;
    service.subtitleText.value = 'previous room';
    var finished = false;
    final stopping = service.stopAndWait().then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(service.running.value, isFalse);
    expect(service.subtitleText.value, isEmpty);
    expect(finished, isFalse);
    engine.stopped.complete();
    await stopping;
    expect(finished, isTrue);
  });
}
