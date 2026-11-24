import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class KuaishouAccountService extends GetxService {
  static KuaishouAccountService get instance =>
      Get.find<KuaishouAccountService>();
  var cookie = "";
  var kww = "";
  var hasCookie = false.obs;
  var cookieExpiresAtMs = 0.obs;

  DateTime? get cookieExpiresAt => cookieExpiresAtMs.value > 0
      ? DateTime.fromMillisecondsSinceEpoch(cookieExpiresAtMs.value)
      : null;
  @override
  void onInit() {
    cookie = LocalStorageService.instance.getValue(
      LocalStorageService.kKuaishouCookie,
      "",
    );
    kww = LocalStorageService.instance.getValue(
      LocalStorageService.kKuaishouKww,
      "",
    );
    cookieExpiresAtMs.value = LocalStorageService.instance.getValue(
      LocalStorageService.kKuaishouCookieExpiresAt,
      0,
    );
    hasCookie.value = cookie.isNotEmpty;
    setSite();
    super.onInit();
  }

  void setSite() {
    final site = Sites.allSites[Constant.kKuaishou]?.liveSite;
    if (site is KuaishouSite) {
      site.customCookie = cookie;
      site.customKww = kww;
      site.cookie = "";
      site.cookieObj = {};
    }
  }

  void setCookie(String cookie, {String? kww, DateTime? expiresAt}) {
    this.cookie = cookie;
    if (kww != null) {
      this.kww = kww;
    }
    LocalStorageService.instance.setValue(
      LocalStorageService.kKuaishouCookie,
      cookie,
    );
    LocalStorageService.instance.setValue(
      LocalStorageService.kKuaishouKww,
      this.kww,
    );
    cookieExpiresAtMs.value = expiresAt?.millisecondsSinceEpoch ?? 0;
    LocalStorageService.instance.setValue(
      LocalStorageService.kKuaishouCookieExpiresAt,
      cookieExpiresAtMs.value,
    );
    hasCookie.value = cookie.isNotEmpty;
    setSite();
  }

  void clearCookie() {
    cookie = "";
    kww = "";
    LocalStorageService.instance.setValue(
      LocalStorageService.kKuaishouCookie,
      "",
    );
    LocalStorageService.instance.setValue(
      LocalStorageService.kKuaishouKww,
      "",
    );
    cookieExpiresAtMs.value = 0;
    LocalStorageService.instance.setValue(
      LocalStorageService.kKuaishouCookieExpiresAt,
      0,
    );
    hasCookie.value = false;
    setSite();
  }
}
