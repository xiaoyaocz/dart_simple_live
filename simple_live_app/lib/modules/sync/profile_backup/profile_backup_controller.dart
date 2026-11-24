import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';
import 'package:simple_live_app/widgets/sync_progress_dialog.dart';
import 'package:simple_live_core/simple_live_core.dart';

class ProfileBackupController extends BaseController {
  Future<void> exportProfile() async {
    try {
      var status = await Utils.checkStorgePermission();
      if (!status) {
        SmartDialog.showToast("没有存储权限");
        return;
      }
      final content = ProfileBackupService.instance.exportProfileJson();
      final fileName =
          "SimpleLive_Profile_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json";
      final inlineSave = Platform.isAndroid || Platform.isIOS || kIsWeb;
      final path = await FilePicker.platform.saveFile(
        allowedExtensions: ["json"],
        type: FileType.custom,
        fileName: fileName,
        bytes: inlineSave ? utf8.encode(content) : null,
      );
      if (path == null && !kIsWeb) {
        return;
      }
      if (!inlineSave && path != null) {
        await File(path).writeAsString(content);
      }
      SmartDialog.showToast("已导出配置包");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导出失败：$e");
    }
  }

  Future<void> importProfile() async {
    try {
      var status = await Utils.checkStorgePermission();
      if (!status) {
        SmartDialog.showToast("没有存储权限");
        return;
      }
      final overwrite = await Utils.showAlertDialog(
        "是否覆盖本地数据？选择“不覆盖”会合并导入，保留本机已有数据。",
        title: "导入配置包",
        confirm: "覆盖",
        cancel: "不覆盖",
      );
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["json"],
      );
      if (picked == null || picked.files.single.path == null) {
        return;
      }
      SyncProgressDialog.show(const SyncProgress(stage: "正在导入配置包"));
      final content = await File(picked.files.single.path!).readAsString();
      final summary = await ProfileBackupService.instance.importProfileJson(
        content,
        overwrite: overwrite,
        onProgress: SyncProgressDialog.update,
      );
      SyncProgressDialog.dismiss();
      SmartDialog.showToast("导入完成：${summary.message}");
    } catch (e) {
      SyncProgressDialog.dismiss();
      Log.logPrint(e);
      SmartDialog.showToast("导入失败：$e");
    }
  }
}
