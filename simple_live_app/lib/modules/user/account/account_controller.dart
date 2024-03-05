import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';

class AccountController extends GetxController {
  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      AppNavigator.toBiliBiliLogin();
    }
  }
}
