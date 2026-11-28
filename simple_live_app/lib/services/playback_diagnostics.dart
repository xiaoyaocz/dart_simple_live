import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class PlaybackSnapshot {
  final double? sourceFps, outputFps, cacheSeconds;
  final int? voDrops, decoderDrops;
  final String hardwareDecoder;
  final Duration elapsed;
  // The current mpv embedding has no presentation-frame counter. Never use
  // estimated-vf-fps or display Hz as a substitute for measured rendering FPS.
  double? get renderFps => null;
  const PlaybackSnapshot(
      {this.sourceFps,
      this.outputFps,
      this.cacheSeconds,
      this.voDrops,
      this.decoderDrops,
      this.hardwareDecoder = '',
      this.elapsed = Duration.zero});
}

/// Six read-only mpv queries/second, never per-frame Dart callbacks.
class PlaybackDiagnostics with WidgetsBindingObserver {
  final Future<String> Function(String) read;
  final void Function(PlaybackSnapshot)? onSample;
  PlaybackDiagnostics({required this.read, this.onSample});
  final snapshot = const PlaybackSnapshot().obs;
  final _clock = Stopwatch()..start();
  Timer? _timer;
  bool _closed = false,
      _busy = false,
      _playing = false,
      _foreground = true,
      _observing = false;
  int _generation = 0;

  void setPlaying(bool playing) {
    if (_closed) return;
    _playing = playing;
    ++_generation;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_closed || !_playing || !_foreground) return;
    unawaited(sample());
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => unawaited(sample()));
  }

  Future<void> sample() async {
    if (_closed || _busy || !_foreground) return;
    _busy = true;
    final generation = _generation;
    try {
      final values = await Future.wait([
        'container-fps',
        'estimated-vf-fps',
        'frame-drop-count',
        'decoder-frame-drop-count',
        'hwdec-current',
        'demuxer-cache-duration',
      ].map((key) async {
        try {
          return await read(key).timeout(const Duration(seconds: 1));
        } on Exception {
          return '';
        } on AssertionError {
          // The player may have been destroyed while a sample was pending.
          return '';
        }
      }));
      if (_closed || !_foreground || generation != _generation) return;
      double? number(int i, {bool positive = false}) {
        final n = double.tryParse(values[i]);
        return n != null && n.isFinite && (positive ? n > 0 : n >= 0)
            ? n
            : null;
      }

      final value = PlaybackSnapshot(
          elapsed: _clock.elapsed,
          sourceFps: number(0, positive: true),
          outputFps: number(1, positive: true),
          voDrops: number(2)?.toInt(),
          decoderDrops: number(3)?.toInt(),
          hardwareDecoder: values[4],
          cacheSeconds: number(5));
      snapshot.value = value;
      onSample?.call(value);
    } finally {
      _busy = false;
    }
  }

  void reset() {
    ++_generation;
    snapshot.value = const PlaybackSnapshot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    ++_generation;
    _schedule();
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    ++_generation;
    _timer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
  }
}

/// Conservative overload signal: three five-second windows each lose >10%.
/// Unknown counters, buffering, seeks and stream changes cannot trigger it.
class PlaybackDropGuard {
  Duration? _at;
  int? _vo, _decoder;
  int _badWindows = 0;
  void reset() {
    _at = null;
    _vo = _decoder = null;
    _badWindows = 0;
  }

  bool add(PlaybackSnapshot sample, Duration now, {bool buffering = false}) {
    final vo = sample.voDrops, decoder = sample.decoderDrops;
    final fps = sample.sourceFps;
    if (buffering || vo == null || decoder == null || fps == null || fps <= 0) {
      reset();
      return false;
    }
    if (_at == null || vo < _vo! || decoder < _decoder!) {
      _at = now;
      _vo = vo;
      _decoder = decoder;
      _badWindows = 0;
      return false;
    }
    final seconds = (now - _at!).inMicroseconds / 1000000;
    if (seconds < 5) return false;
    final drops = vo - _vo! + decoder - _decoder!;
    _at = now;
    _vo = vo;
    _decoder = decoder;
    _badWindows = drops > fps * seconds * 0.10 ? _badWindows + 1 : 0;
    return _badWindows >= 3;
  }
}
