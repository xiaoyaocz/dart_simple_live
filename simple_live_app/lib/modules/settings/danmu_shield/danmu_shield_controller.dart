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
    final value = textEditingController.text.trim();
    if (value.isEmpty) {
      SmartDialog.showToast("请输入关键词");
      return;
    }

    settingsController.addShieldList(value);
    textEditingController.text = "";
  }

  void remove(String item) {
    settingsController.removeShieldList(item);
  }

  void addUser() {
    final value = userTextEditingController.text.trim();
    if (value.isEmpty) {
      SmartDialog.showToast("请输入用户名");
      return;
    }

    settingsController.addUserShieldList(value);
    userTextEditingController.text = "";
  }

  void removeUser(String item) {
    settingsController.removeUserShieldList(item);
  }

  Future<void> savePreset(String name) async {
    final value = name.trim();
    if (value.isEmpty) {
      SmartDialog.showToast("请输入预设名称");
      return;
    }
    final success = await settingsController.saveShieldPreset(value);
    SmartDialog.showToast(success ? "已保存屏蔽预设" : "保存屏蔽预设失败");
  }

  Future<void> applyPreset(String name) async {
    final success = await settingsController.applyShieldPreset(name);
    SmartDialog.showToast(success ? "已启用屏蔽预设" : "启用屏蔽预设失败");
  }

  Future<void> deletePreset(String name) async {
    final success = await settingsController.deleteShieldPreset(name);
    SmartDialog.showToast(success ? "已删除屏蔽预设" : "删除屏蔽预设失败");
  }

  @override
  void onClose() {
    textEditingController.dispose();
    userTextEditingController.dispose();
    super.onClose();
  }
}
