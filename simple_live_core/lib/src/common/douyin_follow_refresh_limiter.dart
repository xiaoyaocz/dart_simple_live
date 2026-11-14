import 'dart:async';

class DouyinFollowLimiterConfig {
  final int initialConcurrency;
  final Duration initialInterval;
  final Duration minInterval;
  final Duration maxInterval;

  const DouyinFollowLimiterConfig({
    required this.initialConcurrency,
    required this.initialInterval,
    required this.minInterval,
    this.maxInterval = const Duration(milliseconds: 1200),
  });
}

class DouyinFollowLimiterSummary {
  final int targetCount;
  final int successCount;
  final int limitedCount;
  final bool cooledDown;
  final Duration initialInterval;
  final Duration finalInterval;
  final int initialConcurrency;
  final Duration elapsed;

  const DouyinFollowLimiterSummary({
    required this.targetCount,
    required this.successCount,
    required this.limitedCount,
    required this.cooledDown,
    required this.initialInterval,
    required this.finalInterval,
    required this.initialConcurrency,
    required this.elapsed,
  });
}

class DouyinFollowRefreshLimiter {
  final DouyinFollowLimiterConfig config;
  final Stopwatch _stopwatch = Stopwatch()..start();

  final List<DateTime> _workerNextReadyAt = <DateTime>[];
  int _successCount = 0;
  int _limitedCount = 0;
  int _consecutiveSuccess = 0;
  Duration _currentInterval;
  DateTime? _pausedUntil;
  bool _cooledDown = false;

  DouyinFollowRefreshLimiter._(this.config)
    : _currentInterval = config.initialInterval {
    _workerNextReadyAt.addAll(
      List<DateTime>.filled(config.initialConcurrency, DateTime.now()),
    );
  }

  factory DouyinFollowRefreshLimiter.forTargetCount(int targetCount) {
    if (targetCount <= 20) {
      return DouyinFollowRefreshLimiter._(
        const DouyinFollowLimiterConfig(
          initialConcurrency: 4,
          initialInterval: Duration(milliseconds: 60),
          minInterval: Duration(milliseconds: 40),
        ),
      );
    }
    if (targetCount <= 100) {
      return DouyinFollowRefreshLimiter._(
        const DouyinFollowLimiterConfig(
          initialConcurrency: 3,
          initialInterval: Duration(milliseconds: 120),
          minInterval: Duration(milliseconds: 80),
        ),
      );
    }
    if (targetCount <= 300) {
      return DouyinFollowRefreshLimiter._(
        const DouyinFollowLimiterConfig(
          initialConcurrency: 2,
          initialInterval: Duration(milliseconds: 220),
          minInterval: Duration(milliseconds: 140),
        ),
      );
    }
    return DouyinFollowRefreshLimiter._(
      const DouyinFollowLimiterConfig(
        initialConcurrency: 1,
        initialInterval: Duration(milliseconds: 320),
        minInterval: Duration(milliseconds: 220),
      ),
    );
  }

  int get initialConcurrency => config.initialConcurrency;
  Duration get initialInterval => config.initialInterval;
  Duration get currentInterval => _currentInterval;
  int get successCount => _successCount;
  int get limitedCount => _limitedCount;
  bool get cooledDown => _cooledDown;

  Future<void> beforeRequest(int workerIndex) async {
    if (_workerNextReadyAt.isEmpty) {
      return;
    }
    final slotIndex = workerIndex >= 0
        ? workerIndex % _workerNextReadyAt.length
        : 0;
    while (true) {
      final now = DateTime.now();
      final pausedUntil = _pausedUntil;
      if (pausedUntil != null && now.isBefore(pausedUntil)) {
        await Future.delayed(pausedUntil.difference(now));
        continue;
      }
      final nextReadyAt = _workerNextReadyAt[slotIndex];
      if (now.isBefore(nextReadyAt)) {
        await Future.delayed(nextReadyAt.difference(now));
        continue;
      }
      _workerNextReadyAt[slotIndex] = DateTime.now().add(_currentInterval);
      return;
    }
  }

  void onSuccess() {
    _successCount += 1;
    _consecutiveSuccess += 1;
    if (_consecutiveSuccess >= 16) {
      _consecutiveSuccess = 0;
      _currentInterval = _decreaseInterval(_currentInterval);
    }
  }

  bool onLimited() {
    _limitedCount += 1;
    _consecutiveSuccess = 0;
    if (_limitedCount >= 2) {
      _cooledDown = true;
      return true;
    }
    _currentInterval = _increaseInterval(_currentInterval);
    _pausedUntil = DateTime.now().add(const Duration(seconds: 15));
    for (var i = 0; i < _workerNextReadyAt.length; i++) {
      _workerNextReadyAt[i] = _pausedUntil!;
    }
    return false;
  }

  DouyinFollowLimiterSummary finish(int targetCount) {
    _stopwatch.stop();
    return DouyinFollowLimiterSummary(
      targetCount: targetCount,
      successCount: _successCount,
      limitedCount: _limitedCount,
      cooledDown: _cooledDown,
      initialInterval: config.initialInterval,
      finalInterval: _currentInterval,
      initialConcurrency: config.initialConcurrency,
      elapsed: _stopwatch.elapsed,
    );
  }

  Duration _decreaseInterval(Duration value) {
    final next = value - const Duration(milliseconds: 20);
    if (next < config.minInterval) {
      return config.minInterval;
    }
    return next;
  }

  Duration _increaseInterval(Duration value) {
    final next = value + const Duration(milliseconds: 120);
    if (next > config.maxInterval) {
      return config.maxInterval;
    }
    return next;
  }
}
