import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';

void main() {
  group('shouldUseAndroidPhoneOrientationPolicy', () {
    test('uses the phone policy only below the tablet breakpoint', () {
      expect(
        shouldUseAndroidPhoneOrientationPolicy(
          displayWidth: 1080,
          displayHeight: 2400,
          devicePixelRatio: 3,
        ),
        isTrue,
      );
      expect(
        shouldUseAndroidPhoneOrientationPolicy(
          displayWidth: 1600,
          displayHeight: 2560,
          devicePixelRatio: 2,
        ),
        isFalse,
      );
    });

    test('keeps the system policy when the display metrics are invalid', () {
      expect(
        shouldUseAndroidPhoneOrientationPolicy(
          displayWidth: 0,
          displayHeight: 2400,
          devicePixelRatio: 3,
        ),
        isFalse,
      );
    });
  });

  group('shouldRequestLandscapeForAndroidExternalWindow', () {
    test('requests landscape for an OEM multi-window floating window', () {
      expect(
        shouldRequestLandscapeForAndroidExternalWindow(
          inPip: false,
          inMultiWindow: true,
          isFreeform: false,
          playerFullscreen: true,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isTrue,
      );
    });

    test('requests landscape for a freeform window', () {
      expect(
        shouldRequestLandscapeForAndroidExternalWindow(
          inPip: false,
          inMultiWindow: false,
          isFreeform: true,
          playerFullscreen: true,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isTrue,
      );
    });

    test('keeps the system orientation policy on a tablet', () {
      expect(
        shouldRequestLandscapeForAndroidExternalWindow(
          inPip: false,
          inMultiWindow: true,
          isFreeform: false,
          playerFullscreen: true,
          isVerticalVideo: false,
          canLockOrientation: false,
        ),
        isFalse,
      );
    });

    test('does not rotate PiP, portrait video, or a non-fullscreen player', () {
      expect(
        shouldRequestLandscapeForAndroidExternalWindow(
          inPip: true,
          inMultiWindow: true,
          isFreeform: true,
          playerFullscreen: true,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isFalse,
      );
      expect(
        shouldRequestLandscapeForAndroidExternalWindow(
          inPip: false,
          inMultiWindow: true,
          isFreeform: false,
          playerFullscreen: true,
          isVerticalVideo: true,
          canLockOrientation: true,
        ),
        isFalse,
      );
      expect(
        shouldRequestLandscapeForAndroidExternalWindow(
          inPip: false,
          inMultiWindow: true,
          isFreeform: false,
          playerFullscreen: false,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isFalse,
      );
    });

  });

  group('shouldRestoreImmersiveAfterExternalWindowExit', () {
    test('restores immersive once the system window has expanded', () {
      expect(
        shouldRestoreImmersiveAfterExternalWindowExit(
          wasInExternalWindow: true,
          isInExternalWindow: false,
          playerFullscreen: true,
        ),
        isTrue,
      );
    });

    test('keeps the floating window untouched while still external', () {
      expect(
        shouldRestoreImmersiveAfterExternalWindowExit(
          wasInExternalWindow: true,
          isInExternalWindow: true,
          playerFullscreen: true,
        ),
        isFalse,
      );
    });

    test('does nothing after the player already left fullscreen', () {
      expect(
        shouldRestoreImmersiveAfterExternalWindowExit(
          wasInExternalWindow: true,
          isInExternalWindow: false,
          playerFullscreen: false,
        ),
        isFalse,
      );
    });
  });

  group('resolvePlayerFullscreenOrientationPolicy', () {
    test('maps stored values', () {
      expect(
        resolvePlayerFullscreenOrientationPolicy("landscape"),
        PlayerFullscreenOrientationPolicy.landscape,
      );
      expect(
        resolvePlayerFullscreenOrientationPolicy("system"),
        PlayerFullscreenOrientationPolicy.system,
      );
      expect(
        resolvePlayerFullscreenOrientationPolicy("smart"),
        PlayerFullscreenOrientationPolicy.smart,
      );
    });

    test('falls back to smart for missing or unknown values', () {
      expect(
        resolvePlayerFullscreenOrientationPolicy(null),
        PlayerFullscreenOrientationPolicy.smart,
      );
      expect(
        resolvePlayerFullscreenOrientationPolicy("bogus"),
        PlayerFullscreenOrientationPolicy.smart,
      );
    });
  });

  group('shouldRequestAndroidPlayerLandscape', () {
    bool resolve({
      required PlayerFullscreenOrientationPolicy policy,
      bool isVerticalVideo = false,
      bool isExternalWindow = false,
      bool isCompactDisplay = true,
    }) {
      return shouldRequestAndroidPlayerLandscape(
        policy: policy,
        isVerticalVideo: isVerticalVideo,
        isExternalWindow: isExternalWindow,
        isCompactDisplay: isCompactDisplay,
      );
    }

    test('smart keeps the historical phone/tablet split', () {
      expect(
        resolve(policy: PlayerFullscreenOrientationPolicy.smart),
        isTrue,
      );
      expect(
        resolve(
          policy: PlayerFullscreenOrientationPolicy.smart,
          isCompactDisplay: false,
        ),
        isFalse,
      );
      expect(
        resolve(
          policy: PlayerFullscreenOrientationPolicy.smart,
          isCompactDisplay: false,
          isExternalWindow: true,
        ),
        isFalse,
      );
    });

    test('landscape requests on any display, including external windows', () {
      expect(
        resolve(
          policy: PlayerFullscreenOrientationPolicy.landscape,
          isCompactDisplay: false,
        ),
        isTrue,
      );
      expect(
        resolve(
          policy: PlayerFullscreenOrientationPolicy.landscape,
          isCompactDisplay: false,
          isExternalWindow: true,
        ),
        isTrue,
      );
    });

    test('system never requests orientation', () {
      expect(
        resolve(policy: PlayerFullscreenOrientationPolicy.system),
        isFalse,
      );
      expect(
        resolve(
          policy: PlayerFullscreenOrientationPolicy.system,
          isCompactDisplay: false,
        ),
        isFalse,
      );
    });

    test('vertical video never requests landscape', () {
      for (final policy in PlayerFullscreenOrientationPolicy.values) {
        expect(
          resolve(policy: policy, isVerticalVideo: true),
          isFalse,
          reason: policy.name,
        );
      }
    });
  });
}
