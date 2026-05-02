import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';

class DanmuShieldController extends BaseController {
  final TextEditingController textEditingController = TextEditingController();
  final TextEditingController userTextEditingController =
      TextEditingController();
  final AppSettingsController settingsController =
      Get.find<AppSettingsController>();

  void add() {
    if (textEditingController.text.isEmpty) {
      SmartDialog.showToast("璇疯緭鍏ュ叧閿瘝");
      return;
    }

    settingsController.addShieldList(textEditingController.text.trim());
    textEditingController.text = "";
  }

  void remove(String item) {
    settingsController.removeShieldList(item);
  }

  void addUser() {
    if (userTextEditingController.text.isEmpty) {
      SmartDialog.showToast("璇疯緭鍏ョ敤鎴峰悕");
      return;
    }

    settingsController.addUserShieldList(userTextEditingController.text.trim());
    userTextEditingController.text = "";
  }

  void removeUser(String item) {
    settingsController.removeUserShieldList(item);
  }

  @override
  void onClose() {
    textEditingController.dispose();
    userTextEditingController.dispose();
    super.onClose();
  }
}
