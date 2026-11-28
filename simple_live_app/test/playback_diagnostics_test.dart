import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/playback_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'source FPS, filter output and drop counts remain separate; no invented renderer FPS',
      () async {
    final values = {
      'container-fps': '60',
      'estimated-vf-fps': '59.95',
      'frame-drop-count': '3',
      'decoder-frame-drop-count': '2',
      'hwdec-current': 'd3d11va',
      'demuxer-cache-duration': '1.4'
    };
    final monitor = PlaybackDiagnostics(read: (key) async => values[key] ?? '');
    await monitor.sample();
    final s = monitor.snapshot.value;
    expect(s.sourceFps, 60);
    expect(s.outputFps, 59.95);
    expect(s.voDrops, 3);
    expect(s.decoderDrops, 2);
    expect(s.hardwareDecoder, 'd3d11va');
    expect(s.renderFps, isNull);
    monitor.dispose();
  });
  test('missing counters stay unknown, not zero or Hz', () async {
    final monitor = PlaybackDiagnostics(read: (_) async => '');
    await monitor.sample();
    expect(monitor.snapshot.value.sourceFps, isNull);
    expect(monitor.snapshot.value.voDrops, isNull);
    expect(monitor.snapshot.value.renderFps, isNull);
    monitor.dispose();
  });
  test('non-overlapping samples and disposal ignore late completion', () async {
    final gate = Completer<String>();
    var reads = 0;
    final monitor = PlaybackDiagnostics(read: (_) {
      reads++;
      return gate.future;
    });
    final first = monitor.sample();
    await monitor.sample();
    monitor.dispose();
    gate.complete('120');
    await first;
    expect(reads, 6);
    expect(monitor.snapshot.value.sourceFps, isNull);
  });
  test(
      'sustained output loss triggers fallback; buffering and counter resets do not',
      () {
    final guard = PlaybackDropGuard();
    PlaybackSnapshot s(int drops) =>
        PlaybackSnapshot(sourceFps: 120, voDrops: drops, decoderDrops: 0);
    expect(guard.add(s(0), const Duration(seconds: 0)), isFalse);
    expect(guard.add(s(100), const Duration(seconds: 5)), isFalse);
    expect(guard.add(s(200), const Duration(seconds: 10)), isFalse);
    expect(guard.add(s(300), const Duration(seconds: 15)), isTrue);
    expect(guard.add(s(400), const Duration(seconds: 20), buffering: true),
        isFalse);
    expect(guard.add(s(0), const Duration(seconds: 25)), isFalse);
    expect(guard.add(s(1), const Duration(seconds: 30)), isFalse);
  });
}
