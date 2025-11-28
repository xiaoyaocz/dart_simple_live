import 'dart:async';
import 'dart:isolate';
import 'dart:math';

// 通过滑动窗口、分桶、哈希去重的弹幕屏蔽器
// 原理类似于mask,单位时间内已有弹幕占据过滤矩阵，过滤重复弹幕
// 通过滑动窗口，实现弹幕time to live策略
// 直接使用会造成开屏时卡UI线程
class DanmakuMask {
  final int baseWindowMs;
  final int bucketCount;
  final bool useNormalization;
  final bool useFrequencyControl;
  final int maxFrequency;
  final bool adaptiveWindow;

  late int _windowMs;
  late int _bucketSizeMs;

  int _currentBucket = 0;
  int _lastShiftMs = 0;

  late final List<Set<int>> _buckets;
  final Map<int, int> _freqMap = {};

  DanmakuMask({
    this.baseWindowMs = 5000,
    this.bucketCount = 5,
    this.useNormalization = false,
    this.useFrequencyControl = false,
    this.maxFrequency = 3,
    this.adaptiveWindow = false,
  }) {
    _windowMs = baseWindowMs;
    _bucketSizeMs = _windowMs ~/ bucketCount;
    _buckets = List.generate(bucketCount, (_) => <int>{});
  }

  String _normalize(String text) {
    if (!useNormalization) return text;
    return text
        .trim()
        .replaceAll(RegExp(r"\s+"), "")
        .replaceAll(RegExp(r"[~!！?？,.，。]"), "")
        .toLowerCase();
  }

  void _shiftIfNeeded(int nowMs) {
    while (nowMs - _lastShiftMs >= _bucketSizeMs) {
      _lastShiftMs += _bucketSizeMs;

      _currentBucket = (_currentBucket + 1) % bucketCount;

      final expiredBucket = _buckets[_currentBucket];
      for (final hash in expiredBucket) {
        _freqMap[hash] = (_freqMap[hash] ?? 1) - 1;
        if (_freqMap[hash]! <= 0) {
          _freqMap.remove(hash);
        }
      }

      expiredBucket.clear();
    }
  }

  void _adaptWindow() {
    if (!adaptiveWindow) return;

    final totalItems = _buckets.fold<int>(0, (sum, b) => sum + b.length);

    if (totalItems > 300) {
      _windowMs = max(baseWindowMs ~/ 2, 1500);
    } else if (totalItems < 50) {
      _windowMs = baseWindowMs;
    }

    _bucketSizeMs = _windowMs ~/ bucketCount;
  }

  bool allow(String text, int nowMs) {
    text = _normalize(text);

    _shiftIfNeeded(nowMs);
    _adaptWindow();

    final hash = text.hashCode;

    // 去重
    for (final bucket in _buckets) {
      if (bucket.contains(hash)) return false;
    }

    // 高频词限制
    if (useFrequencyControl) {
      final freq = _freqMap[hash] ?? 0;
      if (freq >= maxFrequency) return false;
    }

    // 允许 --> 写入当前桶
    _buckets[_currentBucket].add(hash);
    _freqMap[hash] = (_freqMap[hash] ?? 0) + 1;

    return true;
  }

  void reset() {
    for (var b in _buckets) {
      b.clear();
    }
    _freqMap.clear();
    _currentBucket = 0;
    _lastShiftMs = 0;
    _windowMs = baseWindowMs;
    _bucketSizeMs = _windowMs ~/ bucketCount;
  }

  // 基于动态规划的 Levenshtein 距离 计算，用于文本相似度计算，暂时搁置
  int _editDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i < m + 1; i++) {
      for (int j = 1; j < n + 1; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + min(
            dp[i - 1][j - 1],
            min(dp[i][j - 1], dp[i - 1][j]),
          );
        }
      }
    }
    return dp[m][n];
  }
}

// Isolate
class IsolateDanmakuMask {
  late final SendPort _isolateSendPort;
  final _mainReceivePort = ReceivePort();
  late final Isolate _isolate;

  final Map<int, Completer<bool>> _pendingRequests = {};
  int _requestId = 0;

  IsolateDanmakuMask._();

  static Future<IsolateDanmakuMask> create({
    int baseWindowMs = 15000,
    int bucketCount = 5,
    bool useNormalization = false,
    bool useFrequencyControl = false,
    int maxFrequency = 3,
    bool adaptiveWindow = false,
  }) async {
    final mask = IsolateDanmakuMask._();
    await mask._init(
      baseWindowMs: baseWindowMs,
      bucketCount: bucketCount,
      useNormalization: useNormalization,
      useFrequencyControl: useFrequencyControl,
      maxFrequency: maxFrequency,
      adaptiveWindow: adaptiveWindow,
    );
    return mask;
  }
  Future<void> _init({
    required int baseWindowMs,
    required int bucketCount,
    required bool useNormalization,
    required bool useFrequencyControl,
    required int maxFrequency,
    required bool adaptiveWindow,
  }) async {
    final initCompleter = Completer<void>();

    _mainReceivePort.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        if (!initCompleter.isCompleted) {
          initCompleter.complete();
        }
      } else if (message is List) {
        final id = message[0] as int;
        final result = message[1] as bool;
        _pendingRequests.remove(id)?.complete(result);
      }
    });

    final params = {
      'baseWindowMs': baseWindowMs,
      'bucketCount': bucketCount,
      'useNormalization': useNormalization,
      'useFrequencyControl': useFrequencyControl,
      'maxFrequency': maxFrequency,
      'adaptiveWindow': adaptiveWindow,
    };

    _isolate = await Isolate.spawn(
      _danmakuIsolateEntryPoint,
      [_mainReceivePort.sendPort, params],
    );

    return initCompleter.future;
  }

  Future<bool> allow(String text, int nowMs) {
    final id = _requestId++;
    final completer = Completer<bool>();
    _pendingRequests[id] = completer;
    _isolateSendPort.send(['allow', id, text, nowMs]);
    return completer.future;
  }

  void reset() {
    _isolateSendPort.send(['reset']);
  }

  void dispose() {
    _isolateSendPort.send(['dispose']);
    _mainReceivePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

void _danmakuIsolateEntryPoint(List<dynamic> initialMessage) {
  final mainSendPort = initialMessage[0] as SendPort;
  final params = initialMessage[1] as Map<String, dynamic>;

  final danmakuMask = DanmakuMask(
    baseWindowMs: params['baseWindowMs'],
    bucketCount: params['bucketCount'],
    useNormalization: params['useNormalization'],
    useFrequencyControl: params['useFrequencyControl'],
    maxFrequency: params['maxFrequency'],
    adaptiveWindow: params['adaptiveWindow'],
  );

  final isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((message) {
    if (message is! List) return;

    final command = message[0] as String;
    switch (command) {
      case 'allow':
        final id = message[1] as int;
        final text = message[2] as String;
        final nowMs = message[3] as int;
        final bool allowed = danmakuMask.allow(text, nowMs);
        mainSendPort.send([id, allowed]);
        break;
      case 'reset':
        danmakuMask.reset();
        break;
      case 'dispose':
        isolateReceivePort.close();
        break;
    }
  });
}
