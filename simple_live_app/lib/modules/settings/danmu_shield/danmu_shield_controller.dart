import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/services/danmaku_filter.dart';

class DanmuShieldController extends BaseController {
  final TextEditingController textEditingController = TextEditingController();
  final TextEditingController userTextEditingController =
      TextEditingController();
  final AppSettingsController settingsController =
      Get.find<AppSettingsController>();

  void add() {
    final raw = textEditingController.text.trim();
    final error = DanmakuFilter.validateRule(raw);
    if (error != null) {
      SmartDialog.showToast(error);
      return;
    }

    settingsController.addShieldList(raw);
    textEditingController.text = "";
  }

  void remove(String item) {
    settingsController.removeShieldList(item);
  }

  void addUser() {
    final userName = userTextEditingController.text.trim();
    if (userName.isEmpty) {
      SmartDialog.showToast("请输入要屏蔽的用户名");
      return;
    }
    settingsController.addShieldUser(userName);
    userTextEditingController.text = "";
  }

  void removeUser(String userName) {
    settingsController.removeShieldUser(userName);
  }

  @override
  void onClose() {
    textEditingController.dispose();
    userTextEditingController.dispose();
    super.onClose();
  }
}
