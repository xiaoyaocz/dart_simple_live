import 'dart:collection';

class LiveRepeatedDanmuSummary {
  final String text;
  final int count;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  const LiveRepeatedDanmuSummary({
    required this.text,
    required this.count,
    this.firstSeenAt,
    this.lastSeenAt,
  });

  String get displayText => "$text x$count";
}

class LiveRepeatedDanmuAggregator {
  final int minDisplayCount;
  final int maxDisplayItems;
  final Duration countWindow;
  final _counters = <String, _RepeatedDanmuCounter>{};
  int _sequence = 0;

  LiveRepeatedDanmuAggregator({
    this.minDisplayCount = 5,
    this.maxDisplayItems = 3,
    this.countWindow = const Duration(seconds: 30),
  }) : assert(minDisplayCount > 0),
       assert(maxDisplayItems > 0),
       assert(!countWindow.isNegative);

  LiveRepeatedDanmuSummary? add(String text, {DateTime? now}) {
    final value = _normalizeText(text);
    if (value.isEmpty) {
      return null;
    }
    final currentTime = now ?? DateTime.now();
    _pruneExpired(currentTime);
    final counter = _counters[value];
    if (counter == null) {
      final nextCounter = _RepeatedDanmuCounter(
        text: value,
        sequence: _sequence++,
      )..add(currentTime);
      _counters[value] = nextCounter;
      return _summaryForCounter(nextCounter);
    } else {
      counter.add(currentTime);
      return _summaryForCounter(counter);
    }
  }

  List<LiveRepeatedDanmuSummary> drain({
    DateTime? now,
    Duration? displayTtl,
  }) {
    final result = preview(now: now, displayTtl: displayTtl);
    clear();
    return result;
  }

  List<LiveRepeatedDanmuSummary> preview({
    DateTime? now,
    Duration? displayTtl,
  }) {
    final currentTime = now ?? DateTime.now();
    _pruneExpired(currentTime);
    return _buildSummaries(currentTime, displayTtl: displayTtl);
  }

  void clear() {
    _counters.clear();
    _sequence = 0;
  }

  List<LiveRepeatedDanmuSummary> _buildSummaries(
    DateTime now, {
    Duration? displayTtl,
  }) {
    final counters =
        _counters.values.where((item) {
          if (item.count < minDisplayCount) {
            return false;
          }
          if (displayTtl == null) {
            return true;
          }
          final lastSeenAt = item.lastSeenAt;
          if (lastSeenAt == null) {
            return false;
          }
          return now.difference(lastSeenAt).compareTo(displayTtl) <= 0;
        }).toList()
          ..sort((a, b) {
            final countCompare = b.count.compareTo(a.count);
            if (countCompare != 0) {
              return countCompare;
            }
            final lastSeenCompare = (b.lastSeenAt ?? DateTime(0)).compareTo(
              a.lastSeenAt ?? DateTime(0),
            );
            if (lastSeenCompare != 0) {
              return lastSeenCompare;
            }
            return a.sequence.compareTo(b.sequence);
          });
    return counters.take(maxDisplayItems).map(_summaryForCounter).toList();
  }

  String _normalizeText(String text) {
    return text.trim().replaceAll(RegExp(r"\s+"), " ");
  }

  LiveRepeatedDanmuSummary _summaryForCounter(_RepeatedDanmuCounter item) {
    return LiveRepeatedDanmuSummary(
      text: item.text,
      count: item.count,
      firstSeenAt: item.firstSeenAt,
      lastSeenAt: item.lastSeenAt,
    );
  }

  void _pruneExpired(DateTime now) {
    final removeKeys = <String>[];
    for (final entry in _counters.entries) {
      entry.value.prune(now, countWindow);
      if (entry.value.count <= 0) {
        removeKeys.add(entry.key);
      }
    }
    for (final key in removeKeys) {
      _counters.remove(key);
    }
  }
}

class _RepeatedDanmuCounter {
  final String text;
  final int sequence;
  final Queue<DateTime> _hitTimes = Queue<DateTime>();

  _RepeatedDanmuCounter({
    required this.text,
    required this.sequence,
  });

  int get count => _hitTimes.length;
  DateTime? get firstSeenAt => _hitTimes.isEmpty ? null : _hitTimes.first;
  DateTime? get lastSeenAt => _hitTimes.isEmpty ? null : _hitTimes.last;

  void add(DateTime time) {
    _hitTimes.addLast(time);
  }

  void prune(DateTime now, Duration countWindow) {
    while (_hitTimes.isNotEmpty &&
        now.difference(_hitTimes.first).compareTo(countWindow) > 0) {
      _hitTimes.removeFirst();
    }
  }
}
