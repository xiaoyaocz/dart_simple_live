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
