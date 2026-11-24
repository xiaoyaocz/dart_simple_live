import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/live_status_refresh_policy.dart';

void main() {
  group('LiveStatusRefreshPolicy', () {
    test('requires three consecutive offline results before ending a room', () {
      final policy = LiveStatusRefreshPolicy();

      expect(
        policy.confirmOffline(
          reportedLive: false,
          hasActivePlaybackEvidence: false,
        ),
        isFalse,
      );
      expect(policy.consecutiveOfflineCount, 1);
      expect(
        policy.confirmOffline(
          reportedLive: false,
          hasActivePlaybackEvidence: false,
        ),
        isFalse,
      );
      expect(
        policy.confirmOffline(
          reportedLive: false,
          hasActivePlaybackEvidence: false,
        ),
        isTrue,
      );
    });

    test('resets the offline streak when playback is still active', () {
      final policy = LiveStatusRefreshPolicy();
      policy.confirmOffline(
        reportedLive: false,
        hasActivePlaybackEvidence: false,
      );
      policy.confirmOffline(
        reportedLive: false,
        hasActivePlaybackEvidence: true,
      );

      expect(policy.consecutiveOfflineCount, 0);
      expect(
        policy.confirmOffline(
          reportedLive: false,
          hasActivePlaybackEvidence: false,
        ),
        isFalse,
      );
    });
  });
}
