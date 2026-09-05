import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_tv_app/modules/settings/follow_update_interval_options.dart';

void main() {
  group('FollowUpdateIntervalOptions', () {
    test('defines the Android TV follow update presets', () {
      expect(
        FollowUpdateIntervalOptions.presets,
        const [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240],
      );
    });

    test('formats minute and hour labels', () {
      expect(FollowUpdateIntervalOptions.format(5), '5分钟');
      expect(FollowUpdateIntervalOptions.format(60), '1小时');
      expect(FollowUpdateIntervalOptions.format(90), '1小时30分钟');
      expect(FollowUpdateIntervalOptions.format(240), '4小时');
    });

    test('normalizes old custom values to the nearest preset', () {
      expect(FollowUpdateIntervalOptions.normalizeToPreset(1), 5);
      expect(FollowUpdateIntervalOptions.normalizeToPreset(22), 20);
      expect(FollowUpdateIntervalOptions.normalizeToPreset(23), 25);
      expect(FollowUpdateIntervalOptions.normalizeToPreset(75), 90);
      expect(FollowUpdateIntervalOptions.normalizeToPreset(260), 240);
    });
  });
}
