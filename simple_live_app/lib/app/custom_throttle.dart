import 'dart:async';

/// 这个类的目的是简化 throttle 的操作，以便更好的理解代码
/// 主要作用：节流，如果在很短时间内都会调用同一个方法，除了第一个方法有用以外
/// 剩下的方法将会被舍弃，在 [eachDelayMilli] 时间后，才会允许下一次调用
/// 会保存一个方法，在最后还会调用一次，和普通的 throttle 不太一样
class DelayedThrottle {
  bool isInvoking = false;
  int eachDelayMilli;
  Future Function()? storeFunc;
  Timer? _timer;
  int _generation = 0;
  final void Function(Object error, StackTrace stackTrace)? onError;

  DelayedThrottle(this.eachDelayMilli, {this.onError});

  void cancel() {
    _generation += 1;
    _timer?.cancel();
    _timer = null;
    isInvoking = false;
    storeFunc = null;
  }

  void invoke(Future Function() longCostFunc) {
    if (isInvoking) {
      storeFunc = longCostFunc;
      return;
    }
    storeFunc = null;
    isInvoking = true;
    final generation = _generation;
    unawaited(_run(longCostFunc, generation));
  }

  Future<void> _run(Future Function() longCostFunc, int generation) async {
    try {
      try {
        await longCostFunc();
      } catch (error, stackTrace) {
        final handler = onError;
        if (handler == null) {
          Zone.current.handleUncaughtError(error, stackTrace);
        } else {
          try {
            handler(error, stackTrace);
          } catch (handlerError, handlerStackTrace) {
            Zone.current.handleUncaughtError(handlerError, handlerStackTrace);
          }
        }
      }
    } finally {
      _scheduleNext(generation);
    }
  }

  void _scheduleNext(int generation) {
    if (generation != _generation) {
      return;
    }
    _timer = Timer(Duration(milliseconds: eachDelayMilli), () {
      _timer = null;
      if (generation != _generation) {
        return;
      }
      isInvoking = false;
      final pending = storeFunc;
      storeFunc = null;
      if (pending != null) {
        invoke(pending);
      }
    });
  }
}
