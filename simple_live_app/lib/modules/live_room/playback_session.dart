import 'dart:async';

typedef PlaybackOpenKey = (int, int, String, Map<String, String>?);

/// Owns the native command queue and the watchdogs for one room controller.
class PlaybackSession {
  int generation = 0;
  int openRevision = 0;
  Future<void> _settled = Future<void>.value();
  PlaybackOpenKey? _pendingKey;
  Future<void>? _pendingOpen;
  Object? recovery;
  Timer? bufferingTimer;
  Timer? failureTimer;
  Timer? shortBufferingTimer;
  Timer? startupProbeTimer;
  Duration? rebufferBurstStart;
  int rebufferBurstCount = 0;
  final rebufferWatch = Stopwatch();

  Future<void> get settled => _settled;

  int advance() {
    cancelWatchdogs();
    recovery = null;
    ++openRevision;
    _pendingKey = null;
    _pendingOpen = null;
    return ++generation;
  }

  void cancelWatchdogs() {
    bufferingTimer?.cancel();
    bufferingTimer = null;
    failureTimer?.cancel();
    failureTimer = null;
    shortBufferingTimer?.cancel();
    shortBufferingTimer = null;
    startupProbeTimer?.cancel();
    startupProbeTimer = null;
    rebufferBurstStart = null;
    rebufferBurstCount = 0;
    rebufferWatch
      ..stop()
      ..reset();
  }

  Future<void> enqueue(Future<void> Function() action) {
    final operation = _settled.then((_) => action());
    // The caller receives the error. The serial queue must remain usable.
    _settled =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> open(
      PlaybackOpenKey key, Future<void> Function(bool Function()) action) {
    if (_pendingKey == key) return _pendingOpen!;
    final revision = ++openRevision;
    bool isLatest() => revision == openRevision;
    final operation = enqueue(() async {
      try {
        if (isLatest()) await action(isLatest);
      } finally {
        if (isLatest()) {
          _pendingKey = null;
          _pendingOpen = null;
        }
      }
    });
    _pendingKey = key;
    _pendingOpen = operation;
    return operation;
  }
}
