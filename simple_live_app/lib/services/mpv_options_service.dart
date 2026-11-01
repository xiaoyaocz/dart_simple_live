import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';

class MpvOptionsService {
  static const Map<String, String> profileLabels = {
    "performance": "流畅",
    "balanced": "均衡",
    "quality": "画质",
  };

  static const Map<String, Map<String, String>> desktopProfiles = {
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
    "balanced": <String, String>{},
    "balancedDesktop": {
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
      "vo": "gpu-next",
      "scale": "ewa_lanczossharp",
      "cscale": "ewa_lanczossoft",
      "dscale": "mitchell",
      "correct-downscaling": "yes",
      "sigmoid-upscaling": "yes",
      "deband": "yes",
    },
    // 省电模式下的画质档替代：spline36 缩放，避开 gpu-next 与
    // EWA/sigmoid/deband 等每帧额外着色器 pass
    "qualityPowerSave": {
      "hwdec": "auto-safe",
      "vo": "gpu",
      "scale": "spline36",
      "cscale": "spline36",
      "dscale": "mitchell",
      "correct-downscaling": "no",
      "sigmoid-upscaling": "no",
      "deband": "no",
    },
  };

  static Map<String, String> effectiveOptions() {
    return effectiveOptionsWithSource().options;
  }

  static MpvEffectiveOptions effectiveOptionsWithSource() {
    final settings = AppSettingsController.instance;
    final profile = settings.mpvProfile.value;
    final profileOptions = _profileOptionsForPlatform(profile);
    final options = <String, String>{...profileOptions};
    final source = <String, String>{
      for (final key in profileOptions.keys) key: "profile:$profile",
    };
    if (settings.customPlayerOutput.value) {
      final vo = settings.videoOutputDriver.value.trim();
      final hwdec = settings.videoHardwareDecoder.value.trim();
      final ao = settings.audioOutputDriver.value.trim();
      if (vo.isNotEmpty) {
        options["vo"] = vo;
        source["vo"] = "custom";
      }
      if (hwdec.isNotEmpty) {
        options["hwdec"] = hwdec;
        source["hwdec"] = "custom";
      }
      if (ao.isNotEmpty) {
        options["ao"] = ao;
        source["ao"] = "custom";
      }
    }
    final advancedOptions = parseOptions(settings.mpvAdvancedOptions.value);
    options.addAll(advancedOptions);
    for (final key in advancedOptions.keys) {
      source[key] = "advanced";
    }
    final confOptions = parseConfFile(settings.importedMpvConfPath.value);
    options.addAll(confOptions);
    for (final key in confOptions.keys) {
      source[key] = "conf";
    }
    return MpvEffectiveOptions(options, source);
  }

  static VideoControllerConfiguration videoControllerConfiguration() {
    final settings = AppSettingsController.instance;
    if (settings.playerCompatMode.value && Platform.isAndroid) {
      return const VideoControllerConfiguration(
        vo: 'mediacodec_embed',
        hwdec: 'mediacodec',
      );
    }
    final effectiveOptions = effectiveOptionsWithSource();
    final options = effectiveOptions.options;
    if (!Platform.isAndroid) {
      return VideoControllerConfiguration(
        hwdec: _desktopVideoControllerHwdec(effectiveOptions),
        enableHardwareAcceleration: settings.hardwareDecode.value,
      );
    }
    return VideoControllerConfiguration(
      vo: options["vo"],
      hwdec: options["hwdec"],
      enableHardwareAcceleration: settings.hardwareDecode.value,
      // Fix Issue #57: 安卓全屏后画面卡死 - 延迟attach避免surface race condition
      androidAttachSurfaceAfterVideoParameters: true,
    );
  }

  /// 网络重连与缓存默认参数（移动端直播防断流）。
  /// 用户在高级参数/mpv.conf 中设置的同名参数会覆盖这些默认值。
  static const Map<String, String> networkDefaultOptions = {
    'network-timeout': '30',
    'stream-lavf-o':
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=10',
    'cache': 'yes',
    'demuxer-readahead-secs': '2',
    'demuxer-max-bytes': '16MiB',
    'demuxer-max-back-bytes': '8MiB',
  };

  /// 音频默认参数：扩大 mpv softvol 范围以支持 >100% 的音量增益档
  /// （media_kit 的 setVolume 直透 mpv volume 属性，上限由 volume-max 决定）。
  /// 用户在高级参数/mpv.conf 中设置的同名参数会覆盖该默认值。
  static const Map<String, String> audioDefaultOptions = {
    'volume-max': '300',
  };

  static Future<void> applyToPlayer(Player player) async {
    if (player.platform is! NativePlayer) {
      return;
    }
    final nativePlayer = player.platform as dynamic;
    // iOS 的视频管线固定，只应用网络默认参数；audio-exclusive 使 mpv 不使用
    // MixWithOthers，与 AppDelegate 的 .playback 类别保持一致。
    if (Platform.isIOS) {
      final iosOptions = <String, String>{
        ...audioDefaultOptions,
        ...networkDefaultOptions,
        'audio-exclusive': 'yes',
      };
      for (final entry in iosOptions.entries) {
        try {
          await nativePlayer.setProperty(entry.key, entry.value);
        } catch (e) {
          Log.d("mpv ios option skipped: ${entry.key}=${entry.value} $e");
        }
      }
      return;
    }
    final options = Map<String, String>.from(audioDefaultOptions)
      ..addAll(networkDefaultOptions)
      ..addAll(effectiveOptions())
      ..remove("vo")
      ..remove("hwdec");
    for (final entry in options.entries) {
      try {
        await nativePlayer.setProperty(entry.key, entry.value);
      } catch (e) {
        Log.d("mpv option skipped: ${entry.key}=${entry.value} $e");
      }
    }
  }

  static Map<String, String> _profileOptionsForPlatform(String profile) {
    Map<String, String> base;
    final powerSave = AppSettingsController.instance.powerSaveMode.value;
    if (powerSave) {
      // 省电模式：均衡→bilinear，画质→spline36，流畅档本就是 bilinear 不变
      final powerSaveKey = profile == "balanced"
          ? "performance"
          : profile == "quality"
          ? "qualityPowerSave"
          : profile;
      base =
          desktopProfiles[powerSaveKey] ?? desktopProfiles["performance"]!;
    } else if (profile == "balanced") {
      base = Platform.isWindows
          ? desktopProfiles["balanced"]!
          : desktopProfiles["balancedDesktop"]!;
    } else {
      base = desktopProfiles[profile] ?? desktopProfiles["balanced"]!;
    }
    // Windows: d3d11va-copy avoids #115 zero-copy black screen on slim mpv.
    if (Platform.isWindows) {
      base = {...base, "hwdec": "d3d11va-copy"};
    }
    return base;
  }

  static String? _desktopVideoControllerHwdec(MpvEffectiveOptions options) {
    return options.options["hwdec"];
  }

  static String diagnosticsSummary() {
    final effectiveOptions = effectiveOptionsWithSource();
    final options = effectiveOptions.options;
    String value(String key) {
      final optionValue = options[key];
      final source = effectiveOptions.source[key];
      if (optionValue == null || optionValue.isEmpty) {
        return "default";
      }
      return source == null ? optionValue : "$optionValue($source)";
    }

    return "profile=${AppSettingsController.instance.mpvProfile.value}, "
        "powerSave=${AppSettingsController.instance.powerSaveMode.value}, "
        "hardwareDecode=${AppSettingsController.instance.hardwareDecode.value}, "
        "vo=${value("vo")}, hwdec=${value("hwdec")}, "
        "mpvOptions=${options.length}";
  }

  static Map<String, String> parseOptions(String raw) {
    final result = <String, String>{};
    for (final rawLine in raw.split(RegExp(r"\r?\n"))) {
      final line = _stripComment(rawLine).trim();
      if (line.isEmpty) {
        continue;
      }
      final entry = _parseLine(line);
      if (entry != null) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  static Map<String, String> parseConfFile(String path) {
    if (path.trim().isEmpty) {
      return const {};
    }
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return const {};
      }
      return parseOptions(file.readAsStringSync());
    } catch (e) {
      Log.d("read mpv.conf failed: $e");
      return const {};
    }
  }

  static Future<String?> importMpvConf() async {
    final picked = await FilePicker.platform.pickFiles(
      allowedExtensions: ["conf"],
      type: FileType.custom,
    );
    final sourcePath = picked?.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }
    final supportDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(supportDir.path, "mpv"));
    await targetDir.create(recursive: true);
    final targetPath = p.join(targetDir.path, "mpv.conf");
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  static MapEntry<String, String>? _parseLine(String line) {
    final normalized =
        line.startsWith("--") ? line.substring(2).trimLeft() : line;
    final equalIndex = normalized.indexOf("=");
    if (equalIndex > 0) {
      return MapEntry(
        normalized.substring(0, equalIndex).trim(),
        normalized.substring(equalIndex + 1).trim(),
      );
    }
    final match = RegExp(r"^([^\s]+)\s+(.+)$").firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return MapEntry(match.group(1)!.trim(), match.group(2)!.trim());
  }

  static String _stripComment(String line) {
    final index = line.indexOf("#");
    if (index < 0) {
      return line;
    }
    return line.substring(0, index);
  }
}

class MpvEffectiveOptions {
  final Map<String, String> options;
  final Map<String, String> source;

  const MpvEffectiveOptions(this.options, this.source);
}
