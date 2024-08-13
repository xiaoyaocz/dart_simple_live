import 'dart:convert';
import 'dart:io';

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
import 'package:simple_live_app/services/local_storage_service.dart';

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
      Log.disposeWriter();
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
    Share.shareXFiles([XFile(item.path)]);
  }

  void saveLogFile(LogFileModel item) async {
    var filePath = await FilePicker.platform.saveFile(
      allowedExtensions: ['log'],
      type: FileType.custom,
      fileName: item.name,
    );
    if (filePath != null) {
      var file = File(item.path);
      await file.copy(filePath);
      SmartDialog.showToast("保存成功");
    }
  }

  void exportConfig() async {
    try {
      var config = LocalStorageService.instance.settingsBox.toMap();
      var shield = LocalStorageService.instance.shieldBox.toMap();
      var data = {
        "type": "simple_live",
        "platform": Platform.operatingSystem,
        "version": 1,
        "time": DateTime.now().millisecondsSinceEpoch,
        "config": config,
        "shield": shield
      };

      var filePath = await FilePicker.platform.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        fileName: "simple_live_config.json",
      );
      if (filePath != null) {
        var file = File(filePath);
        await file.writeAsString(jsonEncode(data));
        SmartDialog.showToast("保存成功");
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导入失败:$e");
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
      var data = jsonDecode(await File(filePath).readAsString());
      if (data["type"] != "simple_live") {
        SmartDialog.showToast("不支持的配置文件");
        return;
      }
      // 检查platform
      if (data["platform"] != Platform.operatingSystem &&
          !await Utils.showAlertDialog("导入配置文件平台不匹配,是否继续导入?", title: "平台不匹配")) {
        return;
      }
      LocalStorageService.instance.settingsBox.clear();
      LocalStorageService.instance.shieldBox.clear();
      LocalStorageService.instance.settingsBox.putAll(data["config"]);
      LocalStorageService.instance.shieldBox
          .putAll(data["shield"].cast<String, String>());
      SmartDialog.showToast("导入成功,重启生效");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导入失败:$e");
    }
  }

  void resetDefaultConfig() {
    Utils.showAlertDialog("是否重置所有配置为默认值?").then((value) {
      if (value) {
        LocalStorageService.instance.settingsBox.clear();
        LocalStorageService.instance.shieldBox.clear();
        SmartDialog.showToast("重置成功,重启生效");
      }
    });
  }
}

class LogFileModel {
  late String name;
  late String path;
  late DateTime time;
  late int size;
  LogFileModel(this.name, this.path, this.time, this.size);
}
