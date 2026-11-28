import 'dart:async';

/// Only pending work is shared: a later refresh always executes [load] again.
class InFlightRequests<T> {
  final _pending = <String, Future<T>>{};

  /// 解除旧轮的共享登记，不取消仍由旧调用者等待的请求。
  void invalidate(String key) => _pending.remove(key);

  Future<T> run(String key, Future<T> Function() load) {
    return _pending.putIfAbsent(key, () {
      // Convert synchronous loader errors too, so both paths release the key.
      late final Future<T> request;
      request = Future<T>.sync(load).then(
        (value) {
          if (identical(_pending[key], request)) _pending.remove(key);
          return value;
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_pending[key], request)) _pending.remove(key);
          Error.throwWithStackTrace(error, stack);
        },
      );
      return request;
    });
  }
}

/// A bounded, one-shot prefetch handoff, not a persistent response cache.
class PrefetchRequests<T> {
  PrefetchRequests({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _ttl = Duration(seconds: 30);
  static const _capacity = 8;
  final DateTime Function() _now;
  final _requests = InFlightRequests<T>();
  final _consumers = InFlightRequests<T>();
  final _prefetched = <String, (Future<T>, DateTime)>{};

  void _prune() {
    final now = _now();
    _prefetched.removeWhere((_, value) => now.difference(value.$2) >= _ttl);
  }

  void prefetch(String key, Future<T> Function() load) {
    _prune();
    if (_prefetched.containsKey(key)) return;
    if (_prefetched.length >= _capacity) {
      _prefetched.remove(_prefetched.keys.first);
    }
    final request = _requests.run(key, load);
    _prefetched[key] = (request, _now());
    request.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_prefetched[key]?.$1, request)) _prefetched.remove(key);
      },
    );
  }

  Future<T> take(String key, Future<T> Function() load) {
    return _consumers.run(key, () async {
      _prune();
      final prefetched = _prefetched.remove(key);
      if (prefetched != null) {
        try {
          return await prefetched.$1;
        } catch (_) {
          // A speculative failure must not fail the foreground request.
        }
      }
      return _requests.run(key, load);
    });
  }
}
