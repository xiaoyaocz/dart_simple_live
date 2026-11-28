import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';

class RemoteSyncWebDAVController extends BaseController {
  // ui
  var passwordVisible = true.obs;
  // ui-用户选择是否同步
  var isSyncFollows = true.obs;
  var isSyncHistories = true.obs;
  var isSyncBlockWord = true.obs;
  var isSyncBilibiliAccount = true.obs;

  final isSyncing = false.obs;

  late DAVClient davClient;
  var user = "--".obs;
  var lastRecoverTime = "--".obs;
  var lastUploadTime = "--".obs;

  WebDavAutoSyncService get _syncService =>
      Get.isRegistered<WebDavAutoSyncService>()
          ? WebDavAutoSyncService.instance
          : WebDavAutoSyncService();

  bool get autoSyncEnabled => Get.isRegistered<AppSettingsController>()
      ? AppSettingsController.instance.webDavAutoSync.value
      : false;

  String get lastAutoSyncStatus => Get.isRegistered<WebDavAutoSyncService>()
      ? WebDavAutoSyncService.instance.lastAutoSyncStatus.value
      : '';

  void setAutoSyncEnabled(bool enabled) {
    if (!Get.isRegistered<AppSettingsController>()) return;
    AppSettingsController.instance.setWebDavAutoSync(enabled);
    if (Get.isRegistered<WebDavAutoSyncService>()) {
      if (enabled) {
        WebDavAutoSyncService.instance.scheduleStartupSync();
      } else {
        WebDavAutoSyncService.instance.cancelPending();
      }
    }
  }

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
      if (autoSyncEnabled && Get.isRegistered<WebDavAutoSyncService>()) {
        WebDavAutoSyncService.instance.scheduleStartupSync();
      }
    } else {
      SmartDialog.showToast("WebDAV账号密码验证失败，请重新输入！");
    }
  }

  // WebDAV登出
  @override
  Future<void> onLogout() async {
    if (isSyncing.value || _syncService.isSyncing.value) return;
    var result = await Utils.showAlertDialog("确定要登出WebDAV账号？", title: "退出登录");
    if (result) {
      if (Get.isRegistered<WebDavAutoSyncService>()) {
        WebDavAutoSyncService.instance.cancelPending();
      }
      // 清除本地账号数据
      LocalStorageService.instance.setValue(LocalStorageService.kWebDAVUri, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUser, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVPassword, "");
      notLogin.value = true;
    }
  }

  // Both platforms share this additive upload; the client retains cloud records.
  Future<void> doWebDAVUpload() async {
    final service = _syncService;
    if (isSyncing.value || service.isSyncing.value) return;
    isSyncing.value = true;
    SmartDialog.showLoading(msg: "正在上传并补充云端未关注的");
    try {
      final uploadTime = await service.uploadBackup(client: davClient);
      lastUploadTime.value = Utils.parseTime(uploadTime);
      SmartDialog.showToast("上传完成：已保留云端已有关注并补充新增关注");
    } catch (e, stack) {
      Log.e('上传合并失败: $e', stack);
      SmartDialog.showToast('上传失败：$e');
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
      isSyncing.value = false;
    }
  }

  // webDAV恢复到本地
  Future<void> doWebDAVRecovery() async {
    final service = _syncService;
    if (isSyncing.value || service.isSyncing.value) return;
    isSyncing.value = true;
    SmartDialog.showLoading(msg: "正在下载并补充本机未关注的");
    try {
      final summary = await service.recoverBackup(
        client: davClient,
        syncFollows: isSyncFollows.value,
        syncHistories: isSyncHistories.value,
        syncBlockWord: isSyncBlockWord.value,
        syncBilibiliAccount: isSyncBilibiliAccount.value,
      );
      if (summary.hasIssues) {
        SmartDialog.showToast(
            '部分同步：${summary.failures.join('；')}，${summary.skippedCount} 条数据跳过');
        return;
      }
      SmartDialog.showToast('下载完成：已保留本机已有关注并补充未关注的');
      lastRecoverTime.value = Utils.parseTime(summary.recoverTime);
    } catch (e) {
      // 下载或解压失败时不清空本地数据，提示真实错误信息
      Log.e('恢复到本地失败: $e', StackTrace.current);
      SmartDialog.showToast('下载失败：$e');
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
      isSyncing.value = false;
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
}
