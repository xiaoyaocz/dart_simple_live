import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_core/simple_live_core.dart';

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
    final options = <String, String>{
      ...profiles[profile] ?? profiles["balanced"]!,
    };
    if (Platform.isWindows) {
      // 保留原档位的自动硬解；软件输出时由共享策略改用 copy-back。
      options["hwdec"] = WindowsVideoAccelerationPolicy.resolve(
        hardwareDecode: settings.hardwareDecode.value,
        renderingAcceleration: settings.videoRenderingAcceleration.value,
        requestedHwdec: options["hwdec"],
      ).hwdec!;
    }
    return options;
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
        enableHardwareAcceleration: Platform.isWindows
            ? settings.videoRenderingAcceleration.value
            : settings.hardwareDecode.value,
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

  /// 音频默认参数：扩大 mpv softvol 范围以支持 >100% 的音量增益档
  /// （media_kit 的 setVolume 直透 mpv volume 属性，上限由 volume-max 决定）。
  static const Map<String, String> audioDefaultOptions = {
    'volume-max': '300',
  };

  static Future<void> applyToPlayer(Player player) async {
    if (player.platform is! NativePlayer) {
      return;
    }
    final options = Map<String, String>.from(audioDefaultOptions)
      ..addAll(effectiveOptions())
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
