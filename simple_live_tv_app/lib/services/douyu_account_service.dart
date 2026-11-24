import 'dart:math';

import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';

class DouyuAccountService extends GetxService {
  static DouyuAccountService get instance => Get.find<DouyuAccountService>();

  String cookie = "";
  final hasCookie = false.obs;

  /// 扫码登录获得的续期凭据（LTP0 + dy_did）：播放 Cookie（约 7 天）过期后
  /// 由 Passport safeAuth 自动换取新 Cookie。TV 端通常经手机同步获得。
  String ltp0 = "";
  String dyDid = "";

  bool _renewing = false;
  DateTime? _lastRenewFailureAt;
  static const Duration _renewFailureBackoff = Duration(minutes: 5);

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyuCookie, "");
    ltp0 = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyuLtp0, "");
    dyDid = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyuPassportDid, "");
    hasCookie.value = cookie.trim().isNotEmpty;
    setSite();
    super.onInit();
  }

  void setSite() {
    final site = Sites.allSites[Constant.kDouyu]?.liveSite;
    if (site is DouyuSite) {
      site.cookie = cookie;
      site.deviceId = _ensureDeviceId();
      site.onCookieExpired = _renewCookie;
    }
  }

  /// 匿名身份用的本设备持久化 did：首次生成 32 位 hex 并落盘，
  /// 之后所有斗鱼请求复用，不再共用签名脚本里写死的共享 did。
  String _ensureDeviceId() {
    var stored = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyuDeviceId, "");
    if (stored.isEmpty) {
      stored = _generateHexDeviceId();
      LocalStorageService.instance
          .setValue(LocalStorageService.kDouyuDeviceId, stored);
    }
    return stored;
  }

  static String _generateHexDeviceId() {
    var random = Random.secure();
    return List.generate(
      32,
      (i) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  /// 设置 Cookie 的统一入口（同步接收 / 手动粘贴 / 扫码）。
  /// Cookie 非空时尽力提取续期凭据（显式传入的优先）；
  /// 清空 Cookie 时续期凭据一并清除。
  void setCookie(String value, {String? ltp0, String? dyDid}) {
    cookie = value.trim();
    hasCookie.value = cookie.isNotEmpty;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDouyuCookie, cookie);
    if (cookie.isEmpty) {
      this.ltp0 = "";
      this.dyDid = "";
      LocalStorageService.instance
          .setValue(LocalStorageService.kDouyuLtp0, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kDouyuPassportDid, "");
    } else {
      _storeCredential(
        (ltp0 != null && ltp0.trim().isNotEmpty)
            ? ltp0.trim()
            : DouyuPassport.cookieValue(cookie, "LTP0"),
        LocalStorageService.kDouyuLtp0,
        (v) => this.ltp0 = v,
      );
      _storeCredential(
        (dyDid != null && dyDid.trim().isNotEmpty)
            ? dyDid.trim()
            : DouyuPassport.cookieValue(cookie, "dy_did"),
        LocalStorageService.kDouyuPassportDid,
        (v) => this.dyDid = v,
      );
    }
    setSite();
  }

  void _storeCredential(
    String value,
    String storageKey,
    void Function(String) assign,
  ) {
    if (value.isEmpty) {
      return;
    }
    assign(value);
    LocalStorageService.instance.setValue(storageKey, value);
  }

  void clearCookie() => setCookie("");

  /// 扫码确认成功后落库：先存续期凭据，再换取播放 Cookie。
  /// 换取失败时凭据已保存，之后取流会自动续期，不阻塞登录成功。
  Future<void> applyQrCredentials(DouyuPassport session) async {
    _storeCredential(
      session.ltp0,
      LocalStorageService.kDouyuLtp0,
      (v) => ltp0 = v,
    );
    _storeCredential(
      session.did,
      LocalStorageService.kDouyuPassportDid,
      (v) => dyDid = v,
    );
    final renewed = await DouyuPassport.refreshPlayCookie(
      dyDid: session.did,
      ltp0: session.ltp0,
    );
    setCookie(renewed, ltp0: session.ltp0, dyDid: session.did);
  }

  /// 播放 Cookie 过期时由 core 回调：用 LTP0/dy_did 经 safeAuth 换新 Cookie。
  /// 失败后 5 分钟内不重复请求 Passport，避免每次取流都触发续期。
  Future<String?> _renewCookie() async {
    if (ltp0.isEmpty || dyDid.isEmpty) {
      return null;
    }
    if (_renewing) {
      return null;
    }
    final lastFailure = _lastRenewFailureAt;
    if (lastFailure != null &&
        DateTime.now().difference(lastFailure) < _renewFailureBackoff) {
      return null;
    }
    _renewing = true;
    try {
      final renewed = await DouyuPassport.refreshPlayCookie(
        dyDid: dyDid,
        ltp0: ltp0,
      );
      setCookie(renewed, ltp0: ltp0, dyDid: dyDid);
      Log.i("斗鱼播放 Cookie 已自动续期");
      return renewed;
    } catch (e) {
      _lastRenewFailureAt = DateTime.now();
      Log.w("斗鱼 Cookie 自动续期失败：$e");
      return null;
    } finally {
      _renewing = false;
    }
  }
}
