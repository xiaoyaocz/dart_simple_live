import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:path/path.dart' as p;
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/widgets/sync_progress_dialog.dart';
import 'package:simple_live_core/simple_live_core.dart';

class OtherSettingsController extends BaseController {
  RxList<LogFileModel> logFiles = <LogFileModel>[].obs;

  var videoOutputDrivers = {
    "gpu": "gpu",
    "gpu-next": "gpu-next",
    "xv": "xv (X11 only)",
    "x11": "x11 (X11 only)",
    "vdpau": "vdpau (X11 only)",
    "direct3d": "direct3d (Windows only)",
    "sdl": "sdl",
    "dmabuf-wayland": "dmabuf-wayland",
    "vaapi": "vaapi",
    "null": "null",
    "libmpv": "libmpv",
    "mediacodec_embed": "mediacodec_embed (Android only)",
  };

  var audioOutputDrivers = {
    "null": "null (No audio output)",
    "pulse": "pulse (Linux, uses PulseAudio)",
    "pipewire": "pipewire (Linux, via Pulse compatibility or native)",
    "alsa": "alsa (Linux only)",
    "oss": "oss (Linux only)",
    "jack": "jack (Linux/macOS, low-latency audio)",
    "directsound": "directsound (Windows only)",
    "wasapi": "wasapi (Windows only)",
    "winmm": "winmm (Windows only, legacy API)",
    "audiounit": "audiounit (iOS only)",
    "coreaudio": "coreaudio (macOS only)",
    "opensles": "opensles (Android only)",
    "audiotrack": "audiotrack (Android only)",
    "aaudio": "aaudio (Android only)",
    "pcm": "pcm (Cross-platform)",
    "sdl": "sdl (Cross-platform, via SDL library)",
    "openal": "openal (Cross-platform, OpenAL backend)",
    "libao": "libao (Cross-platform, uses libao library)",
    "auto": "auto (Not available)"
  };

  var hardwareDecoder = {
    "no": "no",
    "auto": "auto",
    "auto-safe": "auto-safe",
    "yes": "yes",
    "auto-copy": "auto-copy",
    "d3d11va": "d3d11va",
    "d3d11va-copy": "d3d11va-copy",
    "videotoolbox": "videotoolbox",
    "videotoolbox-copy": "videotoolbox-copy",
    "vaapi": "vaapi",
    "vaapi-copy": "vaapi-copy",
    "nvdec": "nvdec",
    "nvdec-copy": "nvdec-copy",
    "drm": "drm",
    "drm-copy": "drm-copy",
    "vulkan": "vulkan",
    "vulkan-copy": "vulkan-copy",
    "dxva2": "dxva2",
    "dxva2-copy": "dxva2-copy",
    "vdpau": "vdpau",
    "vdpau-copy": "vdpau-copy",
    "mediacodec": "mediacodec",
    "mediacodec-copy": "mediacodec-copy",
    "cuda": "cuda",
    "cuda-copy": "cuda-copy",
    "crystalhd": "crystalhd",
    "rkmpp": "rkmpp"
  };

  @override
  void onInit() {
    loadLogFiles();
    super.onInit();
  }

  void setLogEnable(e) {
    AppSettingsController.instance.setLogEnable(e);
    if (e) {
      Log.initWriter();
      Future.delayed(const Duration(milliseconds: 100), () {
        loadLogFiles();
      });
    } else {
      unawaited(Log.disposeWriter());
    }
  }

  void loadLogFiles() async {
    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (!await logDir.exists()) {
      await logDir.create();
    }
    logFiles.clear();
    await logDir.list().forEach((element) {
      var file = element as File;
      var name = p.basename(file.path);
      var time = file.lastModifiedSync();
      var size = file.lengthSync();
      logFiles.add(LogFileModel(name, file.path, time, size));
    });
    //logFiles 名称倒序
    logFiles.sort((a, b) => b.time.compareTo(a.time));
  }

  void cleanLog() async {
    if (AppSettingsController.instance.logEnable.value) {
      SmartDialog.showToast("请先关闭日志记录");
      return;
    }

    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (await logDir.exists()) {
      await logDir.delete(recursive: true);
    }
    loadLogFiles();
  }

  void shareLogFile(LogFileModel item) {
    SharePlus.instance.share(ShareParams(
      files: [XFile(item.path)],
    ));
  }

  void saveLogFile(LogFileModel item) async {
    try {
      await Log.flushWriter();
      final source = File(item.path);
      if (!await source.exists()) {
        SmartDialog.showToast("日志文件不存在");
        return;
      }
      final inlineSave = Platform.isAndroid || Platform.isIOS || kIsWeb;
      final bytes = inlineSave ? await source.readAsBytes() : null;
      final filePath = await FilePicker.platform.saveFile(
        allowedExtensions: ['log'],
        type: FileType.custom,
        fileName: item.name,
        bytes: bytes,
      );
      if (filePath == null) {
        return;
      }
      if (!inlineSave) {
        await source.copy(filePath);
      }
      SmartDialog.showToast("保存成功");
    } catch (e) {
      SmartDialog.showToast("保存失败：$e");
    }
  }

  void exportConfig() async {
    try {
      var data = ProfileBackupService.instance.exportProfileJson();
      var bytes = Uint8List.fromList(utf8.encode(data));

      // FilePicker 直接写入
      var inlineSave = Platform.isAndroid || Platform.isIOS || kIsWeb;

      var path = await FilePicker.platform.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        fileName: "simple_live_profile.json",
        bytes: inlineSave ? bytes : null,
      );

      if (path == null && !kIsWeb) {
        SmartDialog.showToast("保存取消");
        return;
      }

      // 桌面平台需要手动写入
      if (!inlineSave && path != null) {
        await File(path).writeAsBytes(bytes);
      }

      SmartDialog.showToast("保存成功");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导出失败:$e");
    }
  }

  void importConfig() async {
    try {
      var file = await FilePicker.platform.pickFiles(
        allowedExtensions: ['json'],
        type: FileType.custom,
      );
      if (file == null) {
        return;
      }
      var filePath = file.files.single.path!;
      var content = await File(filePath).readAsString();
      var data = jsonDecode(content);
      if (ProfileBackupService.instance.isSupportedProfileMap(data)) {
        var overwrite = await Utils.showAlertDialog(
          "是否覆盖本地数据？选择“不覆盖”会合并导入，保留本机已有数据。",
          title: "导入配置包",
          confirm: "覆盖",
          cancel: "不覆盖",
        );
        SyncProgressDialog.show(const SyncProgress(stage: "正在导入配置包"));
        final summary = await ProfileBackupService.instance.importProfileJson(
          content,
          overwrite: overwrite,
          onProgress: SyncProgressDialog.update,
        );
        SyncProgressDialog.dismiss();
        SmartDialog.showToast("导入成功：${summary.message}");
        return;
      }
      SmartDialog.showToast("不支持的配置文件");
    } catch (e) {
      SyncProgressDialog.dismiss();
      Log.logPrint(e);
      SmartDialog.showToast("导入失败:$e");
    }
  }

  void resetDefaultConfig() {
    Utils.showAlertDialog("是否重置所有配置为默认值?").then((value) {
      if (value) {
        LocalStorageService.instance.settingsBox.clear();
        LocalStorageService.instance.shieldBox.clear();
        AppSettingsController.instance.reloadFromStorage();
        LiveSubtitleService.instance.stop();
        SmartDialog.showToast("重置成功,重启生效");
      }
    });
  }

  String get syncServerUrl => SignalRService.configuredUrl;
  String get syncServerUrlLabel => SignalRService.configuredServerLabel;
  String get syncServerUrlSubtitle => SignalRService.configuredUrl;

  String get syncProxyUrl => SignalRService.proxyDisplayName;

  void editSyncServerUrl() async {
    final customUrl = SignalRService.configuredServerOption ==
            SignalRService.kCustomServerOption
        ? SignalRService.configuredUrl
        : "";
    final optionUrls = <String, String>{
      SignalRService.kDefaultServerOption: SignalRService.kDefaultUrl,
      SignalRService.kCloudflareServerOption: SignalRService.kCloudflareUrl,
      SignalRService.kCustomServerOption: customUrl,
    };
    final probeResults = <String, ValueNotifier<SyncServerProbeResult?>>{
      for (final entry in optionUrls.entries)
        entry.key: ValueNotifier(
          entry.value.isEmpty
              ? const SyncServerProbeResult.notConfigured()
              : null,
        ),
    };
    for (final entry in optionUrls.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      SignalRService.probeServer(
        entry.value,
      ).then((result) => probeResults[entry.key]!.value = result);
    }

    final option = await Utils.showOptionDialog<String>(
      SignalRService.kServerOptions,
      SignalRService.configuredServerOption,
      title: "选择同步服务",
      titleBuilder: (value) => _buildSyncServerOptionTitle(
        value,
        probeResults[value]!,
      ),
      subtitleBuilder: (value) => Text(
        _syncServerOptionDescription(value, optionUrls[value]!),
      ),
    );
    if (option == null) {
      return;
    }
    if (option == SignalRService.kDefaultServerOption) {
      await SignalRService.setConfiguredUrl("");
      SmartDialog.showToast("已切换到自建服务器");
    } else if (option == SignalRService.kCloudflareServerOption) {
      await SignalRService.setConfiguredUrl(SignalRService.kCloudflareUrl);
      SmartDialog.showToast("已切换到 Cloudflare Worker");
    } else {
      final saved = await _editCustomSyncServerUrl();
      if (!saved) {
        return;
      }
    }
    update();
  }

  Widget _buildSyncServerOptionTitle(
    String option,
    ValueNotifier<SyncServerProbeResult?> probeResult,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            option,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<SyncServerProbeResult?>(
          valueListenable: probeResult,
          builder: (context, result, _) {
            if (result == null) {
              return const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text("检测中"),
                ],
              );
            }
            final color = result.isReachable
                ? Colors.green
                : result.label == "未配置"
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : Colors.red;
            return Text(
              result.label,
              style: TextStyle(color: color),
            );
          },
        ),
      ],
    );
  }

  String _syncServerOptionDescription(String option, String url) {
    if (option == SignalRService.kDefaultServerOption) {
      return "$url\n默认直连；设置代理后使用代理";
    }
    if (option == SignalRService.kCloudflareServerOption) {
      return "$url\n备用服务，部分网络需要代理";
    }
    final address = url.isEmpty ? "选择后填写 ws:// 或 wss:// 地址" : url;
    return "$address\n按当前同步代理设置检测";
  }

  Future<bool> _editCustomSyncServerUrl() async {
    final current = SignalRService.configuredServerOption ==
            SignalRService.kCustomServerOption
        ? SignalRService.configuredUrl
        : "";
    final value = await Utils.showEditTextDialog(
      current,
      title: "自定义同步服务",
      hintText: "wss://example.com/sync",
      validate: (text) {
        if (!SignalRService.isValidServerUrl(text)) {
          SmartDialog.showToast("请输入 ws:// 或 wss:// 开头的同步服务地址");
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return false;
    }
    await SignalRService.setConfiguredUrl(value);
    SmartDialog.showToast("已保存自定义同步服务");
    return true;
  }

  void resetSyncServerUrl() async {
    await SignalRService.setConfiguredUrl("");
    SmartDialog.showToast("已恢复默认同步服务");
    update();
  }

  void editSyncProxyUrl() async {
    var value = await Utils.showEditTextDialog(
      SignalRService.configuredProxyUrl,
      title: "同步代理地址",
      hintText: "留空直连，例如 ${SignalRService.kDefaultLocalProxy}",
      validate: (text) {
        final value = text.trim();
        if (!SignalRService.isValidProxyConfig(value)) {
          SmartDialog.showToast(
            "请输入 host:port、http://host:port，或 direct 直连",
          );
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return;
    }
    await SignalRService.setConfiguredProxyUrl(value);
    SmartDialog.showToast(value.trim().isEmpty ? "已切换为直连" : "已保存");
    update();
  }

  Future<void> editMpvAdvancedOptions() async {
    final textController = TextEditingController(
      text: AppSettingsController.instance.mpvAdvancedOptions.value,
    );
    final value = await Get.dialog<String>(
      AlertDialog(
        title: const Text("高级 mpv options"),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: textController,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "每行一个，例如 scale=spline36",
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Get.back(result: textController.text),
            child: const Text("确定"),
          ),
        ],
      ),
    );
    textController.dispose();
    if (value == null) {
      return;
    }
    AppSettingsController.instance.setMpvAdvancedOptions(value);
    SmartDialog.showToast("已保存，重开直播间后生效");
    update();
  }

  Future<void> importMpvConf() async {
    final path = await MpvOptionsService.importMpvConf();
    if (path == null) {
      return;
    }
    AppSettingsController.instance.setImportedMpvConfPath(path);
    SmartDialog.showToast("已导入 mpv.conf，重开直播间后生效");
    update();
  }

  void clearImportedMpvConf() {
    AppSettingsController.instance.setImportedMpvConfPath("");
    SmartDialog.showToast("已清除导入配置");
    update();
  }
}

class LogFileModel {
  late String name;
  late String path;
  late DateTime time;
  late int size;
  LogFileModel(this.name, this.path, this.time, this.size);
}
