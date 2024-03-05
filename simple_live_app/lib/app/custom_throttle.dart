/// 这个类的目的是简化 throttle 的操作，以便更好的理解代码
/// 主要作用：节流，如果在很短时间内都会调用同一个方法，除了第一个方法有用以外
/// 剩下的方法将会被舍弃，在 [eachDelayMilli] 时间后，才会允许下一次调用
/// 会保存一个方法，在最后还会调用一次，和普通的 throttle 不太一样
class DelayedThrottle {
  bool isInvoking = false;
  int eachDelayMilli;
  Future Function()? storeFunc;

  DelayedThrottle(this.eachDelayMilli);

  void invoke(Future Function() longCostFunc) {
    if (isInvoking) {
      storeFunc = longCostFunc;
      return;
    }
    storeFunc = null;
    isInvoking = true;
    longCostFunc().then((value) {
      Future.delayed(Duration(milliseconds: eachDelayMilli), () {
        isInvoking = false;
        if (storeFunc != null) {
          invoke(storeFunc!);
        }
      });
    });
  }
}
