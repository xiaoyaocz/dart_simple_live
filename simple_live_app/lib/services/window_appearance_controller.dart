import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

enum WindowMaterial {
  lightAcrylic('轻薄亚克力'),
  acrylic('标准亚克力'),
  mica('云母'),
  micaAlt('云母 Alt'),
  solid('纯色');

  const WindowMaterial(this.label);
  final String label;
}

/// Windows 原生材质及 Android 应用内材质，不修改播放器和系统壁纸。
class WindowAppearanceController extends GetxController {
  WindowAppearanceController({bool? isWindows, bool? isAndroid})
      : isWindows = isWindows ?? Platform.isWindows,
        isAndroid = isAndroid ?? Platform.isAndroid;
  final bool isWindows;
  final bool isAndroid;
  String get _materialKey => isAndroid ? 'AndroidWindowMaterial' : 'WindowMaterial';
  static const _channel = MethodChannel('simple_live/window');
  static Future<void>? _nativeReady;
  final selected = WindowMaterial.lightAcrylic.obs;
  final effective = WindowMaterial.solid.obs;
  final windowsBuild = 0.obs;
  Brightness _brightness = Brightness.light;
  Future<void> _operation = Future.value();
  String? _appliedKey;
  LocalStorageService get _storage => LocalStorageService.instance;

  Future<void> initialize() async {
    if (!isWindows && !isAndroid) return;
    final saved = _storage.getValue<Object>(_materialKey, 0);
    if (saved is int && saved >= 0 && saved < WindowMaterial.values.length) {
      selected.value = WindowMaterial.values[saved];
    }
    await apply();
  }

  Future<void> setMaterial(WindowMaterial material) async {
    await _storage.setValue(_materialKey, material.index);
    selected.value = material;
    await apply();
  }

  Future<void> apply({Brightness? brightness, bool force = false}) {
    if (isAndroid) {
      final previous = effective.value;
      effective.value = selected.value;
      if (previous != effective.value && Get.context != null) {
        Get.forceAppUpdate();
      }
      return Future.value();
    }
    if (!isWindows) return Future.value();
    final mode = _storage.getValue<int>(LocalStorageService.kThemeMode, 0);
    _brightness = brightness ??
        (mode == 1
            ? Brightness.light
            : mode == 2
                ? Brightness.dark
                : WidgetsBinding
                    .instance.platformDispatcher.platformBrightness);
    // Serialize native updates. Rapid selections must never leave an older effect last.
    _operation = _operation.then((_) async {
      final previous = effective.value;
      var material = selected.value;
      try {
        final caps = await _channel
            .invokeMapMethod<String, dynamic>('appearanceCapabilities');
        windowsBuild.value = caps?['build'] as int? ?? 0;
        if (caps?['transparency'] != true || windowsBuild.value < 17134) {
          material = WindowMaterial.solid;
        } else if ((material == WindowMaterial.mica &&
                windowsBuild.value < 22000) ||
            (material == WindowMaterial.micaAlt &&
                windowsBuild.value < 22523)) {
          material = WindowMaterial.acrylic;
        }
        final key = '${material.name}:${_brightness.name}:${windowsBuild.value}';
        // Native decoration can itself send theme notifications; do not feed them back forever.
        // DWM/window restoration can discard the native backdrop without any
        // preference changing. Only those invalidation events bypass this cache.
        if (!force && _appliedKey == key) return;
        await (_nativeReady ??= Window.initialize());
        final effect = switch (material) {
          WindowMaterial.lightAcrylic ||
          WindowMaterial.acrylic =>
            WindowEffect.acrylic,
          WindowMaterial.mica => WindowEffect.mica,
          WindowMaterial.micaAlt => WindowEffect.tabbed,
          WindowMaterial.solid => WindowEffect.solid,
        };
        final dark = _brightness == Brightness.dark;
        final base = dark ? const Color(0xff202226) : const Color(0xfffaf9fc);
        await Window.setEffect(
            effect: effect,
            dark: dark,
            color: material == WindowMaterial.solid
                ? base
                : base.withAlpha(
                    material == WindowMaterial.lightAcrylic ? 65 : 170));
        // Also clears persistent DWM backdrop state when returning to solid.
        await _channel.invokeMethod('appearanceStyle', {
          'dark': dark,
          'solid': material == WindowMaterial.solid,
        });
        effective.value = material;
        _appliedKey = key;
      } catch (error, stack) {
        _appliedKey = null;
        effective.value = WindowMaterial.solid;
        Log.e('窗口材质不可用，使用纯色：$error', stack);
      }
      // Restoring the same native effect must not rebuild the player or routes.
      if (previous != effective.value && Get.context != null) {
        Get.forceAppUpdate();
      }
    });
    return _operation;
  }

  Color tint(ThemeData theme) {
    if ((!isWindows && !isAndroid) || effective.value == WindowMaterial.solid) {
      return theme.scaffoldBackgroundColor;
    }
    final alpha = switch (effective.value) {
      WindowMaterial.lightAcrylic => 35,
      WindowMaterial.acrylic => 125,
      WindowMaterial.mica => 20,
      WindowMaterial.micaAlt => 32,
      WindowMaterial.solid => 255,
    };
    return theme.colorScheme.surface.withAlpha(alpha);
  }

  ThemeData theme(ThemeData base) {
    if ((!isWindows && !isAndroid) || effective.value == WindowMaterial.solid) {
      return base;
    }
    final colors = base.colorScheme;
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0),
      navigationRailTheme: base.navigationRailTheme.copyWith(
          backgroundColor: colors.surface.withAlpha(95),
          indicatorColor: colors.primaryContainer.withAlpha(200)),
      navigationBarTheme: base.navigationBarTheme.copyWith(
          backgroundColor: colors.surface.withAlpha(210), elevation: 0),
      cardTheme: base.cardTheme.copyWith(
          color: colors.surface.withAlpha(215),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant.withAlpha(100)))),
    );
  }
}
