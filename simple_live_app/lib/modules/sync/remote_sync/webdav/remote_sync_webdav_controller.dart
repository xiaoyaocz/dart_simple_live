import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/bulk_data_import_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';
import 'package:simple_live_app/widgets/sync_progress_dialog.dart';
import 'package:simple_live_core/simple_live_core.dart';

Archive _decodeWebDavBackupArchive(List<int> data) {
  final zipDecoder = ZipDecoder();
  return zipDecoder.decodeBytes(data);
}

class RemoteSyncWebDAVController extends BaseController {
  // ui
  var passwordVisible = true.obs;
  // ui-用户选择是否同步
  var isSyncFollows = true.obs;
  var isSyncHistories = true.obs;
  var isSyncBlockWord = true.obs;
  var isSyncBilibiliAccount = true.obs;
  var isSyncDouyinAccount = true.obs;

  late DAVClient davClient;
  var user = "--".obs;
  var lastRecoverTime = "--".obs;
  var lastUploadTime = "--".obs;

  final _userFollowJsonName = 'SimpleLive_follows.json';
  final _userHistoriesJsonName = 'SimpleLive_histories.json';
  final _userBlockedWordJsonName = 'SimpleLive_blocked_word.json';
  final _userBilibiliAccountJsonName = 'SimpleLive_bilibili_account.json';
  final _userDouyinAccountJsonName = 'SimpleLive_douyin_account.json';
  final _userSettingsJsonName = 'SimpleLive_Settings.json';
  final _userTagsJsonName = 'SimpleLive_Tags.json';
  final _profileJsonName = 'SimpleLive_Profile_v3.json';
  final _legacyProfileJsonName = 'SimpleLive_Profile_v2.json';

  @override
  void onInit() {
    doWebDAVInit();
    super.onInit();
  }

  // webDAV 逻辑
  // 初始化webDAV
  void doWebDAVInit() {
    var uri = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVUri, "");
    if (uri.isEmpty) {
      notLogin.value = true;
    } else {
      user.value = LocalStorageService.instance
          .getValue(LocalStorageService.kWebDAVUser, "");
      var password = LocalStorageService.instance
          .getValue(LocalStorageService.kWebDAVPassword, "");
      davClient = DAVClient(uri, user.value, password);
      // 从未同步过默认为最新数据
      lastRecoverTime.value = Utils.parseTime(
        DateTime.fromMillisecondsSinceEpoch(
          LocalStorageService.instance.getValue(
            LocalStorageService.kWebDAVLastRecoverTime,
            DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      lastUploadTime.value = Utils.parseTime(
        DateTime.fromMillisecondsSinceEpoch(
          LocalStorageService.instance.getValue(
            LocalStorageService.kWebDAVLastUploadTime,
            DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      checkIsLogin();
    }
  }

  // 检查webDAV登录状态
  Future<void> checkIsLogin() async {
    try {
      // 返回登录结果
      bool value = await davClient.pingCompleter.future;
      notLogin.value = !value;
    } catch (e) {
      Log.e("$e", StackTrace.current);
      notLogin.value = true;
    }
  }

  // WebDAV登录
  void doWebDAVLogin(
      String webDAVUri, String webDAVUser, String webDAVPassword) async {
    // 确认登录
    davClient = DAVClient(webDAVUri, webDAVUser, webDAVPassword);
    await checkIsLogin();
    if (!notLogin.value) {
      // 保存到本地
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUri, webDAVUri);
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUser, webDAVUser);
      user.value = webDAVUser;
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVPassword, webDAVPassword);
      Get.back();
      SmartDialog.showToast("登录成功！");
    } else {
      SmartDialog.showToast("WebDAV账号密码验证失败，请重新输入！");
    }
  }

  // WebDAV登出
  @override
  Future<void> onLogout() async {
    var result = await Utils.showAlertDialog("确定要登出WebDAV账号？", title: "退出登录");
    if (result) {
      // 清除本地账号数据
      LocalStorageService.instance.setValue(LocalStorageService.kWebDAVUri, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUser, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVPassword, "");
      notLogin.value = true;
    }
  }

  // webDAV上传到云端
  Future<void> doWebDAVUpload() async {
    SyncProgressDialog.show(const SyncProgress(stage: "正在打包备份"));
    try {
      final value = await _backupData();
      if (value.isNotEmpty) {
        SyncProgressDialog.update(const SyncProgress(stage: "正在上传到云端"));
        var result = await davClient.backup(Uint8List.fromList(value));
        if (result) {
          SmartDialog.showToast("上传成功");
          DateTime uploadTime = DateTime.now();
          lastUploadTime.value = Utils.parseTime(uploadTime);
          LocalStorageService.instance.setValue(
              LocalStorageService.kWebDAVLastUploadTime,
              uploadTime.millisecondsSinceEpoch);
        } else {
          Log.e("备份失败", StackTrace.current);
          SmartDialog.showToast("上传失败");
        }
      } else {
        SmartDialog.showToast("上传失败");
      }
    } catch (e) {
      Log.e("WebDAV 上传失败：$e", StackTrace.current);
      SmartDialog.showToast("上传失败：${exceptionToString(e)}");
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  // 备份所有数据
  Future<List<int>> _backupData() async {
    final archive = Archive();
    List<int> zipBytes = [];
    try {
      final profileMap = ProfileBackupService.instance.exportProfileMap();
      final profileJson =
          const JsonEncoder.withIndent("  ").convert(profileMap);
      archive.addFile(
        ArchiveFile.string(
          _profileJsonName,
          profileJson,
        ),
      );
      _addJsonFile(
        archive,
        _userFollowJsonName,
        {'data': profileMap['followUsers'] ?? const []},
      );
      _addJsonFile(
        archive,
        _userTagsJsonName,
        {'data': profileMap['followUserTags'] ?? const []},
      );
      _addJsonFile(
        archive,
        _userHistoriesJsonName,
        {'data': profileMap['histories'] ?? const []},
      );
      _addJsonFile(
        archive,
        _userBlockedWordJsonName,
        {'data': AppSettingsController.instance.allShieldValues.toList()},
      );
      _addJsonFile(
        archive,
        _userBilibiliAccountJsonName,
        {
          'data': {'cookie': BiliBiliAccountService.instance.cookie}
        },
      );
      _addJsonFile(
        archive,
        _userDouyinAccountJsonName,
        {
          'data': {'cookie': DouyinAccountService.instance.cookie}
        },
      );
      _addJsonFile(
        archive,
        _userSettingsJsonName,
        {'data': LocalStorageService.instance.settingsBox.toMap()},
      );
      final zipEncoder = ZipEncoder();
      zipBytes = zipEncoder.encode(archive);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("备份失败：$e");
    }
    return zipBytes;
  }

  void _addJsonFile(Archive archive, String name, Map<String, dynamic> data) {
    archive.addFile(
      ArchiveFile.string(
        name,
        jsonEncode(data),
      ),
    );
  }

  // webDAV恢复到本地
  void doWebDAVRecovery() async {
    SyncProgressDialog.show(const SyncProgress(stage: "正在下载备份"));
    try {
      final tempDir = await getTemporaryDirectory();
      final downloadPath = join(
        tempDir.path,
        "simple_live_webdav_backup.zip",
      );
      final downloadFile = File(downloadPath);
      if (downloadFile.existsSync()) {
        downloadFile.deleteSync();
      }
      await davClient.client.read2File(davClient.backupFile, downloadPath);
      if (!downloadFile.existsSync() || downloadFile.lengthSync() <= 0) {
        throw const FormatException("WebDAV 备份文件下载失败");
      }
      SyncProgressDialog.update(const SyncProgress(stage: "正在解压备份"));
      final data = await downloadFile.readAsBytes();
      final archive = _decodeWebDavBackupArchive(data);
      final profileFile = archive
          .where(
            (file) =>
                file.isFile &&
                (file.name == _profileJsonName ||
                    file.name == _legacyProfileJsonName),
          )
          .firstOrNull;
      if (profileFile != null) {
        try {
          final summary = await ProfileBackupService.instance.importProfileJson(
            utf8.decode(profileFile.content),
            overwrite: true,
            options: ProfileImportOptions(
              settings: true,
              follows: isSyncFollows.value,
              histories: isSyncHistories.value,
              shields: isSyncBlockWord.value,
              shieldPresets: isSyncBlockWord.value,
            ),
            onProgress: SyncProgressDialog.update,
          );
          Log.i("已同步完整配置包：${summary.message}");
        } catch (e) {
          Log.e("同步完整配置包失败：$e", StackTrace.current);
          rethrow;
        }
        for (ArchiveFile file in archive) {
          if (file.name == _userBilibiliAccountJsonName ||
              file.name == _userDouyinAccountJsonName) {
            await _recovery(file, onProgress: SyncProgressDialog.update);
          }
        }
      } else {
        for (ArchiveFile file in archive) {
          await _recovery(file, onProgress: SyncProgressDialog.update);
        }
      }
      SmartDialog.showToast('同步完成');
      DateTime recoverTime = DateTime.now();
      lastRecoverTime.value = Utils.parseTime(recoverTime);
      LocalStorageService.instance.setValue(
          LocalStorageService.kWebDAVLastRecoverTime,
          recoverTime.millisecondsSinceEpoch);
    } catch (e) {
      Log.e("WebDAV 恢复失败：$e", StackTrace.current);
      SmartDialog.showToast("恢复失败：${exceptionToString(e)}");
    } finally {
      SyncProgressDialog.dismiss();
      try {
        final tempDir = await getTemporaryDirectory();
        final downloadFile =
            File(join(tempDir.path, "simple_live_webdav_backup.zip"));
        if (downloadFile.existsSync()) {
          downloadFile.deleteSync();
        }
      } catch (_) {}
    }
  }

  Future<void> _recovery(
    ArchiveFile file, {
    SyncProgressCallback? onProgress,
  }) async {
    if (file.isFile && file.name.endsWith('.json')) {
      var jsonString = utf8.decode(file.content);
      var jsonData = json.decode(jsonString)['data'];
      // 同步follows
      if (file.name == _userFollowJsonName && isSyncFollows.value) {
        try {
          final result = await BulkDataImportService.importFollowUsers(
            jsonData,
            overwrite: true,
            onProgress: onProgress,
          );
          EventBus.instance.emit(Constant.kUpdateFollow, 0);
          Log.i('已同步关注用户列表：${result.logSummary}');
        } catch (e) {
          Log.e('同步关注用户列表失败: $e', StackTrace.current);
        }
      } else if (file.name == _userHistoriesJsonName && isSyncHistories.value) {
        try {
          final result = await BulkDataImportService.importHistories(
            jsonData,
            onProgress: onProgress,
          );
          EventBus.instance.emit(Constant.kUpdateHistory, 0);
          Log.i('已同步用户观看历史记录：${result.logSummary}');
        } catch (e) {
          Log.e('同步用户观看历史记录失败: $e', StackTrace.current);
        }
      } else if (file.name == _userBlockedWordJsonName &&
          isSyncBlockWord.value) {
        try {
          final result = await BulkDataImportService.importShieldValues(
            jsonData,
            onProgress: onProgress,
          );
          Log.i('已同步用户屏蔽词：${result.logSummary}');
        } catch (e) {
          Log.e('同步用户屏蔽词失败:$e', StackTrace.current);
        }
      } else if (file.name == _userBilibiliAccountJsonName &&
          isSyncBilibiliAccount.value) {
        try {
          var cookie = jsonData['cookie'];
          BiliBiliAccountService.instance.setCookie(cookie);
          BiliBiliAccountService.instance.loadUserInfo();
          Log.i('已同步哔哩哔哩账号');
        } catch (e) {
          Log.e('同步哔哩哔哩账号失败：$e', StackTrace.current);
        }
      } else if (file.name == _userDouyinAccountJsonName &&
          isSyncDouyinAccount.value) {
        try {
          final cookie = jsonData['cookie']?.toString() ?? "";
          if (cookie.isEmpty) {
            DouyinAccountService.instance.clearCookie();
          } else {
            DouyinAccountService.instance.setCookie(cookie);
          }
          Log.i('已同步抖音账号');
        } catch (e) {
          Log.e('同步抖音账号失败：$e', StackTrace.current);
        }
      } else if (file.name == _userSettingsJsonName) {
        try {
          await LocalStorageService.instance.settingsBox.clear();
          LocalStorageService.instance.settingsBox.putAll(jsonData);
          AppSettingsController.instance.reloadFromStorage();
          Log.i('已同步用户设置');
        } catch (e) {
          Log.e("同步用户设置失败：$e", StackTrace.current);
        }
      } else if (file.name == _userTagsJsonName && isSyncFollows.value) {
        try {
          final result = await BulkDataImportService.importFollowTags(
            jsonData,
            overwrite: true,
            onProgress: onProgress,
          );
          EventBus.instance.emit(Constant.kUpdateFollow, 0);
          Log.i('已同步用户自定义标签：${result.logSummary}');
        } catch (e) {
          Log.e('同步用户自定义标签失败:$e', StackTrace.current);
        }
      } else {
        return;
      }
    } else {
      Log.i('不是正确的文件名');
    }
  }

  // ui控制--密码可见控制
  void changePasswordVisible() {
    passwordVisible.value = !passwordVisible.value;
  }

  void changeIsSyncFollows() {
    isSyncFollows.value = !isSyncFollows.value;
  }

  void changeIsSyncHistories() {
    isSyncHistories.value = !isSyncHistories.value;
  }

  void changeIsSyncBlockWord() {
    isSyncBlockWord.value = !isSyncBlockWord.value;
  }

  void changeIsSyncBilibiliAccount() {
    isSyncBilibiliAccount.value = !isSyncBilibiliAccount.value;
  }

  void changeIsSyncDouyinAccount() {
    isSyncDouyinAccount.value = !isSyncDouyinAccount.value;
  }
}
