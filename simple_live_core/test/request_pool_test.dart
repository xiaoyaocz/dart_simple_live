import 'dart:async';
import 'package:simple_live_core/src/common/request_pool.dart';
import 'package:test/test.dart';

void main() {
  test('强制刷新解除旧请求，新请求不被旧请求的迟到完成移除', () async {
    final pool = InFlightRequests<int>();
    final old = Completer<int>();
    final fresh = Completer<int>();
    final a = pool.run('1', () => old.future);
    pool.invalidate('1');
    final b = pool.run('1', () => fresh.future);
    old.complete(1);
    expect(await a, 1);
    final c = pool.run('1', () async => 99);
    fresh.complete(2);
    expect(await b, 2);
    expect(await c, 2);
  });
  test(
    'pending failed prefetch retries once for all waiting consumers',
    () async {
      final pool = PrefetchRequests<int>();
      final gate = Completer<int>();
      var loads = 0;
      Future<int> load() {
        loads++;
        return loads == 1 ? gate.future : Future.value(42);
      }

      pool.prefetch('room', load);
      final first = pool.take('room', load);
      final second = pool.take('room', load);
      final results = Future.wait([first, second]);
      gate.completeError(StateError('prefetch failed'));
      expect(await results, [42, 42]);
      expect(loads, 2);
    },
  );
  test(
    'handoff expires from request start and is only consumed once',
    () async {
      var now = DateTime(2026);
      final pool = PrefetchRequests<int>(now: () => now);
      var loads = 0;
      Future<int> load() async => ++loads;
      pool.prefetch('room', load);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 30));
      expect(await pool.take('room', load), 2);
      expect(await pool.take('room', load), 3);
    },
  );
  test('completed prefetch is shared once and refresh reloads', () async {
    final pool = PrefetchRequests<int>();
    var loads = 0;
    Future<int> load() async => ++loads;
    pool.prefetch('room', load);
    await Future<void>.delayed(Duration.zero);
    expect(
      await Future.wait([pool.take('room', load), pool.take('room', load)]),
      [1, 1],
    );
    expect(await pool.take('room', load), 2);
  });
  test('only eight prefetched responses are retained', () async {
    final pool = PrefetchRequests<int>();
    var loads = 0;
    Future<int> load() async => ++loads;
    for (var i = 0; i < 9; i++) {
      pool.prefetch('$i', load);
    }
    await Future<void>.delayed(Duration.zero);
    expect(await pool.take('1', load), 2);
    expect(await pool.take('0', load), 10);
  });
  test(
    'prefetch failure without consumers is handled and can be retried',
    () async {
      final pool = PrefetchRequests<int>();
      pool.prefetch('room', () => Future.error(StateError('network')));
      await Future<void>.delayed(Duration.zero);
      expect(await pool.take('room', () async => 42), 42);
    },
  );
  test(
    'in-flight failures are cleared; unrelated rooms run concurrently',
    () async {
      final pool = InFlightRequests<int>();
      final gate = Completer<int>();
      var loads = 0;
      Future<int> load() {
        loads++;
        return gate.future;
      }

      final first = pool.run('1', load);
      final second = pool.run('1', load);
      final errors = Future.wait([
        expectLater(first, throwsStateError),
        expectLater(second, throwsStateError),
      ]);
      expect(await pool.run('2', () async => 2), 2);
      expect(loads, 1);
      gate.completeError(StateError('network'));
      await errors;
      expect(await pool.run('1', () async => 3), 3);
    },
  );
}
