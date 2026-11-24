import 'package:flutter/widgets.dart';

const int mobileExtraInsetMax = 80;

/// Adds page layout space without replacing the physical display or IME insets.
/// AppBar, NavigationBar and SafeArea consume [MediaQueryData.padding] once.
MediaQueryData mobilePageMediaQuery(
  MediaQueryData systemData, {
  required int topExtra,
  required int bottomExtra,
  required bool isMobile,
  bool enabled = true,
}) {
  if (!isMobile || !enabled) {
    return systemData;
  }
  final top = topExtra.clamp(0, mobileExtraInsetMax).toDouble();
  // Do not reserve navigation-bar space above an already visible keyboard.
  final bottom = systemData.viewInsets.bottom > 0
      ? 0.0
      : bottomExtra.clamp(0, mobileExtraInsetMax).toDouble();
  if (top == 0 && bottom == 0) {
    return systemData;
  }
  return systemData.copyWith(
    padding: systemData.padding.copyWith(
      top: systemData.padding.top + top,
      bottom: systemData.padding.bottom + bottom,
    ),
  );
}

/// Keeps the existing compact iOS action bar while respecting extra page space.
double mobileBottomActionInset(MediaQueryData data, {required bool isIOS}) {
  final safeInset = data.viewPadding.bottom > data.padding.bottom
      ? data.viewPadding.bottom
      : data.padding.bottom;
  if (!isIOS) {
    return safeInset;
  }
  final extraInset = (safeInset - data.viewPadding.bottom)
      .clamp(0.0, double.infinity)
      .toDouble();
  if (data.orientation == Orientation.landscape) {
    return extraInset;
  }
  return (safeInset - extraInset).clamp(0.0, 16.0).toDouble() + extraInset;
}
