import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';

class MpvOptionsService {
  static const Map<String, String> profileLabels = {
    "performance": "兼容",
    "balanced": "均衡",
    "quality": "高画质",
  };

  static const Map<String, Map<String, String>> profiles = {
    "performance": {
      "profile": "fast",
      "hwdec": "auto-safe",
      "vo": "gpu",
      "scale": "bilinear",
      "cscale": "bilinear",
      "dscale": "bilinear",
      "correct-downscaling": "no",
      "sigmoid-upscaling": "no",
      "deband": "no",
    },
    "balanced": {
      "profile": "gpu-hq",
      "hwdec": "auto-safe",
      "vo": "gpu",
      "scale": "spline36",
      "cscale": "spline36",
      "dscale": "mitchell",
      "deband": "no",
    },
    "quality": {
      "profile": "gpu-hq",
      "hwdec": "auto-safe",
      "vo": "gpu",
      "scale": "spline36",
      "cscale": "spline36",
      "dscale": "mitchell",
      "correct-downscaling": "yes",
      "sigmoid-upscaling": "yes",
      "deband": "yes",
    },
  };

  static Map<String, String> effectiveOptions() {
    final settings = AppSettingsController.instance;
    final profile = settings.mpvProfile.value;
    return <String, String>{
      ...profiles[profile] ?? profiles["balanced"]!,
    };
  }

  static VideoControllerConfiguration videoControllerConfiguration() {
    final settings = AppSettingsController.instance;
    if (settings.playerCompatMode.value && Platform.isAndroid) {
      return const VideoControllerConfiguration(
        vo: 'mediacodec_embed',
        hwdec: 'mediacodec',
      );
    }
    final options = effectiveOptions();
    if (!Platform.isAndroid) {
      return VideoControllerConfiguration(
        hwdec: options["hwdec"],
        enableHardwareAcceleration: settings.hardwareDecode.value,
      );
    }
    return VideoControllerConfiguration(
      vo: options["vo"],
      hwdec: options["hwdec"],
      enableHardwareAcceleration: settings.hardwareDecode.value,
      // Fix TV多开灰屏/Android全屏卡死: 延迟attach避免surface race condition
      androidAttachSurfaceAfterVideoParameters: true,
    );
  }

  static Future<void> applyToPlayer(Player player) async {
    if (player.platform is! NativePlayer) {
      return;
    }
    final options = Map<String, String>.from(effectiveOptions())
      ..remove("vo")
      ..remove("hwdec");
    for (final entry in options.entries) {
      try {
        await (player.platform as dynamic).setProperty(entry.key, entry.value);
      } catch (e) {
        Log.d("mpv option skipped: ${entry.key}=${entry.value} $e");
      }
    }
  }
}
