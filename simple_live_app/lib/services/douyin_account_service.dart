import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/account/douyin_user_info.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class DouyinAccountService extends GetxService {
  static DouyinAccountService get instance => Get.find<DouyinAccountService>();

  var logined = false.obs;
  var cookie = "";
  var name = "未登录".obs;

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyinCookie, "");
    logined.value = cookie.isNotEmpty;
    loadUserInfo();
    super.onInit();
  }

  Future loadUserInfo() async {
    if (cookie.isEmpty) {
      return;
    }
    try {
      final site = (Sites.allSites[Constant.kDouyin]!.liveSite as DouyinSite);
      final data = await site.getUserInfoByCookie(cookie);
      if (data.isEmpty) {
        SmartDialog.showToast("抖音登录已失效，请重新登录");
        logout();
        return;
      }
      var info = DouyinUserInfoModel.fromJson(data);
      name.value = info.nickname!;
      logined.value = true;
      _setSite();
    } catch (e) {
      SmartDialog.showToast("获取抖音登录用户信息失败，可前往账号管理重试");
    }
  }

  void _setSite() {
    var site = (Sites.allSites[Constant.kDouyin]!.liveSite as DouyinSite);
    if (cookie.isEmpty) {
      site.headers.remove("cookie");
    } else {
      site.headers["cookie"] = cookie;
    }
  }

  void setCookie(String cookie) {
    this.cookie = cookie;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDouyinCookie, cookie);
    _setSite();
  }

  void logout() {
    cookie = "";
    LocalStorageService.instance
        .setValue(LocalStorageService.kDouyinCookie, "");
    logined.value = false;
    _setSite();
  }
}
