import 'dart:collection';

/// 屏幕弹幕限流器：在高并发弹幕洪峰下保护主线程绘制帧率。
///
/// - 仅控制视频上方 Canvas 弹幕，不影响聊天区记录；
/// - 本人发送的弹幕（[selfSend]）始终放行，不计入限流配额。
class DanmakuThrottle {
  DanmakuThrottle({
    this.maxPerSecond = 24,
    this.maxActiveOnScreen = 120,
    this.window = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxPerSecond;
  final int maxActiveOnScreen;
  final Duration window;
  final DateTime Function() _now;
  final Queue<DateTime> _timestamps = Queue<DateTime>();

  bool allow({
    required int activeOnScreen,
    bool selfSend = false,
  }) {
    if (selfSend) return true;
    if (activeOnScreen >= maxActiveOnScreen) return false;

    final current = _now();
    final cutoff = current.subtract(window);
    while (_timestamps.isNotEmpty && !_timestamps.first.isAfter(cutoff)) {
      _timestamps.removeFirst();
    }
    if (_timestamps.length >= maxPerSecond) return false;

    _timestamps.addLast(current);
    return true;
  }

  void reset() {
    _timestamps.clear();
  }
}
