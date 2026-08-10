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

    test('re-applies fullscreen only after the system window has expanded', () {
      expect(
        shouldRestoreAndroidFullscreenAfterExternalWindowExit(
          wasInExternalWindow: true,
          isInExternalWindow: false,
          playerFullscreen: true,
          hasPendingLandscapeRequest: true,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isTrue,
      );
      expect(
        shouldRestoreAndroidFullscreenAfterExternalWindowExit(
          wasInExternalWindow: true,
          isInExternalWindow: true,
          playerFullscreen: true,
          hasPendingLandscapeRequest: true,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isFalse,
      );
      expect(
        shouldRestoreAndroidFullscreenAfterExternalWindowExit(
          wasInExternalWindow: true,
          isInExternalWindow: false,
          playerFullscreen: false,
          hasPendingLandscapeRequest: true,
          isVerticalVideo: false,
          canLockOrientation: true,
        ),
        isFalse,
      );
    });
  });
}
