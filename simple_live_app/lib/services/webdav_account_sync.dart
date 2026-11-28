import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';

class WebDavAccountPayload {
  final String uri;
  final String user;
  final String password;
  final bool? autoSync;

  const WebDavAccountPayload({
    required this.uri,
    required this.user,
    required this.password,
    this.autoSync,
  });

  bool get isValid => uri.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'uri': uri.trim(),
        'user': user,
        'password': password,
        if (autoSync != null) 'autoSync': autoSync,
      };

  static WebDavAccountPayload? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final uri = raw['uri']?.toString().trim() ?? '';
    if (uri.isEmpty) return null;
    final user = raw['user']?.toString() ?? '';
    final password = raw['password']?.toString() ?? '';
    final rawAutoSync = raw['autoSync'];
    final autoSync = rawAutoSync is bool
        ? rawAutoSync
        : rawAutoSync is String
            ? rawAutoSync.toLowerCase() == 'true'
            : null;
    return WebDavAccountPayload(
      uri: uri,
      user: user,
      password: password,
      autoSync: autoSync,
    );
  }
}

class WebDavAccountSync {
  static WebDavAccountPayload? readLocal() {
    if (!Get.isRegistered<LocalStorageService>()) return null;
    final storage = LocalStorageService.instance;
    final uri =
        storage.getValue<String>(LocalStorageService.kWebDAVUri, '').trim();
    if (uri.isEmpty) return null;
    final user = storage.getValue<String>(LocalStorageService.kWebDAVUser, '');
    final password =
        storage.getValue<String>(LocalStorageService.kWebDAVPassword, '');
    final autoSync = Get.isRegistered<AppSettingsController>()
        ? AppSettingsController.instance.webDavAutoSync.value
        : storage.getValue<bool>(LocalStorageService.kWebDAVAutoSync, false);
    return WebDavAccountPayload(
      uri: uri,
      user: user,
      password: password,
      autoSync: autoSync,
    );
  }

  static Future<bool> applyLocal(WebDavAccountPayload payload) async {
    if (!payload.isValid || !Get.isRegistered<LocalStorageService>()) {
      return false;
    }
    final storage = LocalStorageService.instance;
    final currentUri =
        storage.getValue<String>(LocalStorageService.kWebDAVUri, '').trim();
    final currentUser =
        storage.getValue<String>(LocalStorageService.kWebDAVUser, '');
    final currentPassword =
        storage.getValue<String>(LocalStorageService.kWebDAVPassword, '');
    final currentAutoSync = Get.isRegistered<AppSettingsController>()
        ? AppSettingsController.instance.webDavAutoSync.value
        : storage.getValue<bool>(LocalStorageService.kWebDAVAutoSync, false);

    final nextUri = payload.uri.trim();
    final credentialsChanged = currentUri != nextUri ||
        currentUser != payload.user ||
        currentPassword != payload.password;
    final autoSyncChanged =
        payload.autoSync != null && payload.autoSync != currentAutoSync;

    if (!credentialsChanged && !autoSyncChanged) {
      return false;
    }

    if (credentialsChanged) {
      await storage.setValue(LocalStorageService.kWebDAVUri, nextUri);
      await storage.setValue(LocalStorageService.kWebDAVUser, payload.user);
      await storage.setValue(
          LocalStorageService.kWebDAVPassword, payload.password);
    }

    if (autoSyncChanged) {
      if (Get.isRegistered<AppSettingsController>()) {
        AppSettingsController.instance.setWebDavAutoSync(payload.autoSync!);
      } else {
        await storage.setValue(
            LocalStorageService.kWebDAVAutoSync, payload.autoSync!);
      }
    }

    if (Get.isRegistered<RemoteSyncWebDAVController>()) {
      Get.find<RemoteSyncWebDAVController>().doWebDAVInit();
    }

    if (payload.autoSync == true && Get.isRegistered<WebDavAutoSyncService>()) {
      WebDavAutoSyncService.instance.scheduleStartupSync();
    }

    return true;
  }
}
