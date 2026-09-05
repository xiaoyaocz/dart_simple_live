import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('LiveRepeatedDanmuAggregator', () {
    test('hides repeated text below the minimum display count', () {
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 4; i++) {
        aggregator.add('哈哈哈哈哈');
      }

      expect(aggregator.preview(), isEmpty);
    });

    test('shows the real repeated text once it reaches the minimum count', () {
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 5; i++) {
        aggregator.add('哈哈哈哈哈');
      }

      final summaries = aggregator.preview();
      expect(summaries, hasLength(1));
      expect(summaries.single.text, '哈哈哈哈哈');
      expect(summaries.single.count, 5);
      expect(summaries.single.displayText, '哈哈哈哈哈 x5');
    });

    test('keeps only the three most repeated texts in each preview', () {
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 30; i++) {
        aggregator.add('哈哈哈哈哈');
      }
      for (var i = 0; i < 20; i++) {
        aggregator.add('来了');
      }
      for (var i = 0; i < 10; i++) {
        aggregator.add('666');
      }
      for (var i = 0; i < 5; i++) {
        aggregator.add('来了来了');
      }

      final summaries = aggregator.preview();
      expect(summaries.map((item) => item.displayText), [
        '哈哈哈哈哈 x30',
        '来了 x20',
        '666 x10',
      ]);
      expect(aggregator.preview(), hasLength(3));
    });

    test('expires hits outside the rolling count window', () {
      final start = DateTime(2026, 6, 7, 12);
      final aggregator = LiveRepeatedDanmuAggregator(
        countWindow: const Duration(seconds: 30),
      );

      for (var i = 0; i < 4; i++) {
        aggregator.add('哈哈哈哈哈', now: start.add(Duration(seconds: i)));
      }
      aggregator.add('哈哈哈哈哈', now: start.add(const Duration(seconds: 35)));

      expect(
        aggregator.preview(now: start.add(const Duration(seconds: 35))),
        isEmpty,
      );
    });

    test('hides stale summaries after the display ttl', () {
      final start = DateTime(2026, 6, 7, 12);
      final aggregator = LiveRepeatedDanmuAggregator();

      for (var i = 0; i < 5; i++) {
        aggregator.add('哈哈哈哈哈', now: start.add(Duration(seconds: i)));
      }

      expect(
        aggregator.preview(
          now: start.add(const Duration(seconds: 12)),
          displayTtl: const Duration(seconds: 10),
        ),
        hasLength(1),
      );
      expect(
        aggregator.preview(
          now: start.add(const Duration(seconds: 15)),
          displayTtl: const Duration(seconds: 10),
        ),
        isEmpty,
      );
    });
  });
}
