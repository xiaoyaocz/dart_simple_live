import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/services/window_appearance_controller.dart';

/// 静态应用内仿材质，无逐帧模糊、壁纸读取或视频采样。
/// 内容保持同一父子路径，切换材质不销毁播放器状态。
class MobileMaterialBackground extends StatelessWidget {
  final WindowAppearanceController controller;
  final Widget child;
  const MobileMaterialBackground(
      {super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Obx(() {
      final material = controller.effective.value;
      final solid = material == WindowMaterial.solid;
      final dark = theme.brightness == Brightness.dark;
      final strength = switch (material) {
        WindowMaterial.lightAcrylic => dark ? 0.22 : 0.16,
        WindowMaterial.acrylic => dark ? 0.38 : 0.30,
        WindowMaterial.mica => dark ? 0.12 : 0.08,
        WindowMaterial.micaAlt => dark ? 0.26 : 0.20,
        WindowMaterial.solid => 0.0,
      };
      final surface = colors.surface;
      // 不对整个内容设置 Opacity，文字与直播画面始终保持不透明。
      return DecoratedBox(
        decoration: BoxDecoration(
          color: solid ? theme.scaffoldBackgroundColor : surface,
          gradient: solid
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, 0.45, 1],
                  colors: [
                    Color.lerp(surface, colors.primary, strength)!,
                    Color.lerp(surface, colors.tertiary, strength * 0.35)!,
                    Color.lerp(surface, colors.secondary, strength * 0.8)!,
                  ],
                ),
        ),
        child: child,
      );
    });
  }
}
