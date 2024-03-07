import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/models/account/bilibili_user_info_page.dart';
import 'package:simple_live_tv_app/requests/http_client.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';

class BiliBiliAccountService extends GetxService {
  static BiliBiliAccountService get instance =>
      Get.find<BiliBiliAccountService>();

  var logined = false.obs;

  var cookie = "";
  var uid = 0;
  var name = "未登录".obs;

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kBilibiliCookie, "");
    logined.value = cookie.isNotEmpty;
    loadUserInfo();
    super.onInit();
  }

  Future loadUserInfo() async {
    if (cookie.isEmpty) {
      return;
    }
    try {
      var result = await HttpClient.instance.getJson(
        "https://api.bilibili.com/x/member/web/account",
        header: {
          "Cookie": cookie,
        },
      );
      if (result["code"] == 0) {
        var info = BiliBiliUserInfoModel.fromJson(result["data"]);
        name.value = info.uname ?? "未登录";
        uid = info.mid ?? 0;
        setSite();
      } else {
        SmartDialog.showToast("哔哩哔哩登录已失效，请重新登录");
        logout();
      }
    } catch (e) {
      SmartDialog.showToast("获取哔哩哔哩用户信息失败，可前往账号管理重试");
    }
  }

  void setSite() {
    var site = (Sites.allSites[Constant.kBiliBili]!.liveSite as BiliBiliSite);
    site.userId = uid;
    site.cookie = cookie;
  }

  void setCookie(String cookie) {
    this.cookie = cookie;
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliCookie, cookie);
    logined.value = cookie.isNotEmpty;
  }

  void logout() async {
    cookie = "";
    uid = 0;
    name.value = "未登录";
    setSite();
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliCookie, "");
    logined.value = false;
  }
}
