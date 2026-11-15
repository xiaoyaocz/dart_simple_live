import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

/// Shares WebView2's original cookie/local-storage profile, never exports credentials.
class SearchWebSession {
  static final _activeProfiles = <String, bool>{};

  static bool usesDirect(String siteId) =>
      _activeProfiles[siteId] ??
      (Get.isRegistered<LocalStorageService>()
          ? LocalStorageService.instance
              .getValue<bool>('SearchWebProfile_$siteId', false)
          : false);

  static void remember(String siteId, bool direct) {
    _activeProfiles[siteId] = direct;
    if (Get.isRegistered<LocalStorageService>()) {
      LocalStorageService.instance.setValue('SearchWebProfile_$siteId', direct);
    }
  }

  static Future<WebViewEnvironment> create(
      {String? siteId, bool? direct}) async {
    final useDirect = direct ?? usesDirect(siteId ?? 'default');
    final support = await getApplicationSupportDirectory();
    final profile = Directory(p.join(
        support.path, useDirect ? 'search_webview_direct' : 'search_webview'));
    await profile.create(recursive: true);
    final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
      userDataFolder: profile.path,
      additionalBrowserArguments: useDirect ? '--no-proxy-server' : null,
    ));
    if (direct != null && siteId != null) remember(siteId, direct);
    return environment;
  }
}
