import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:media_kit/media_kit.dart';

Uint8List words(List<int> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setUint32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List chunk(String tag, List<int> bytes) => (BytesBuilder()
  ..add(ascii.encode(tag))..add(words([bytes.length]))..add(bytes)
  ..add(bytes.length.isOdd ? [0] : [])).takeBytes();

/// Plain uncompressed AVI keeps the fixture independent of external encoders.
Uint8List sourceAvi(int fps) {
  const size = 128 * 72 * 3;
  final stream = BytesBuilder()..add(ascii.encode('vidsDIB '))
    ..add(words([0, 0, 0, 1, fps, 0, fps * 3, size, 0xffffffff, 0]))
    ..add([0, 0, 0, 0, 128, 0, 72, 0]);
  final bitmap = BytesBuilder()..add(words([40, 128, 72]))
    ..add([1, 0, 24, 0])..add(words([0, size, 0, 0, 0, 0]));
  final hdrl = BytesBuilder()..add(ascii.encode('hdrl'))
    ..add(chunk('avih', words([1000000 ~/ fps, size * fps, 0, 0, fps * 3,
      0, 1, size, 128, 72, 0, 0, 0, 0])))
    ..add(chunk('LIST', (BytesBuilder()..add(ascii.encode('strl'))
      ..add(chunk('strh', stream.takeBytes()))
      ..add(chunk('strf', bitmap.takeBytes()))).takeBytes()));
  final frames = BytesBuilder()..add(ascii.encode('movi'));
  for (var frame = 0; frame < fps * 3; frame++) {
    final pixels = Uint8List(size)..fillRange(0, size, frame % 256);
    frames.add(chunk('00db', pixels));
  }
  return chunk('RIFF', (BytesBuilder()..add(ascii.encode('AVI '))
    ..add(chunk('LIST', hdrl.takeBytes()))
    ..add(chunk('LIST', frames.takeBytes()))).takeBytes());
}

/// Deterministic original-frame input test. VO:null is NOT a screen/GPU FPS test.
Future<void> main() async {
  MediaKit.ensureInitialized(libmpv: File(
      'simple_live_app/build/windows/x64/runner/Release/libmpv-2.dll').absolute.path);
  final directory = await Directory.systemTemp.createTemp('simple-live-native-fps-');
  final results = <Map<String, Object?>>[];
  try {
    for (final fps in [60, 90, 120]) {
      final input = File('${directory.path}/source-$fps.avi');
      await input.writeAsBytes(sourceAvi(fps));
      final player = Player(configuration: const PlayerConfiguration(vo: 'null', logLevel: MPVLogLevel.info));
      final native = player.platform as NativePlayer;
      await native.setProperty('vid', 'auto');
      await native.setProperty('ao', 'null');
      await native.setProperty('interpolation', 'no');
      await native.setProperty('video-sync', 'audio');
      final completed = Completer<void>();
      final errors = player.stream.error.listen(stderr.writeln);
      final logs = player.stream.log.listen((l) {
        if (l.text.contains('Video') || l.text.contains('Failed') || l.text.contains('VO:')) stderr.writeln(l.text);
      });
      final sub = player.stream.completed.listen((end) {
        if (end && !completed.isCompleted) completed.complete();
      });
      try {
        await player.open(Media(input.path));
        try {
          await completed.future.timeout(const Duration(seconds: 6));
        } on TimeoutException {
          stderr.writeln('state=${player.state.position} completed=${player.state.completed} buffering=${player.state.buffering} paused=${await native.getProperty('pause')} vid=${await native.getProperty('vid')}');
          rethrow;
        }
        final actual = double.parse(await native.getProperty('container-fps'));
        final dropped = int.parse(await native.getProperty('frame-drop-count'));
        final decoderDropped = int.parse(await native.getProperty('decoder-frame-drop-count'));
        final result = <String, Object?>{'sourceFps': fps, 'reportedFps': actual,
          'inputFrames': fps * 3, 'voDropped': dropped, 'decoderDropped': decoderDropped,
          'interpolation': await native.getProperty('interpolation'),
          'status': actual == fps && dropped == 0 && decoderDropped == 0 ? 'passed' : 'failed',
          'scope': 'headless raw-video decode; not physical presentation or hardware-decoder verification'};
        results.add(result);
        stdout.writeln(jsonEncode(result));
      } finally {
        await sub.cancel();
        await errors.cancel();
        await logs.cancel();
        await player.dispose();
        await input.delete();
      }
    }
  } finally {
    await directory.delete();
  }
  exit(results.every((r) => r['status'] == 'passed') ? 0 : 1);
}
