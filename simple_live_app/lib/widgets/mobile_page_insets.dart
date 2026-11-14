import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/mobile_safe_insets.dart';

/// Applies device-local extra space to a normal mobile page, outside full-screen
/// video and PiP. Physical viewPadding and keyboard viewInsets stay intact.
class MobilePageInsets extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const MobilePageInsets({
    required this.child,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile || !enabled) {
      return child;
    }
    final systemData = MediaQuery.of(context);
    final settings = AppSettingsController.instance;
    return Obx(
      () => MediaQuery(
        data: mobilePageMediaQuery(
          systemData,
          topExtra: settings.mobileTopExtraInset.value,
          bottomExtra: settings.mobileBottomExtraInset.value,
          isMobile: true,
        ),
        child: child,
      ),
    );
  }
}
