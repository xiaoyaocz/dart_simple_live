import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';

class DanmuShieldController extends BaseController {
  final TextEditingController textEditingController = TextEditingController();
  final TextEditingController userTextEditingController =
      TextEditingController();
  final AppSettingsController settingsController =
      Get.find<AppSettingsController>();

  final RxString selectedUserSiteId =
      AppSettingsController.kGlobalUserShieldSiteId.obs;

  List<String> get userShieldSiteIds => [
        AppSettingsController.kGlobalUserShieldSiteId,
        ...Sites.allSites.keys,
      ];

  String get currentUserSiteId => selectedUserSiteId.value;

  String get currentUserSiteLabel =>
      settingsController.resolveShieldSiteLabel(currentUserSiteId);

  List<String> get currentUserShieldValues =>
      settingsController.getUserShieldValues(siteId: currentUserSiteId);

  void setSelectedUserSite(String siteId) {
    selectedUserSiteId.value = siteId;
  }

  void add() {
    final value = textEditingController.text.trim();
    if (value.isEmpty) {
      SmartDialog.showToast("请输入关键词");
      return;
    }

    settingsController.addShieldList(value);
    textEditingController.clear();
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

    settingsController.addUserShieldList(value, siteId: currentUserSiteId);
    userTextEditingController.clear();
  }

  void removeUser(String item, {String? siteId}) {
    settingsController.removeUserShieldList(
      item,
      siteId: siteId ?? currentUserSiteId,
    );
  }

  Future<void> clearKeywords() async {
    if (settingsController.shieldList.isEmpty) {
      SmartDialog.showToast("当前没有可清空的过滤关键词");
      return;
    }
    final confirm = await Utils.showAlertDialog(
      "此操作会一次性删除全部弹幕过滤关键词，删除后无法恢复。",
      title: "确认清空关键词",
      confirm: "确认清空",
      cancel: "取消",
    );
    if (!confirm) {
      return;
    }
    await settingsController.clearKeywordShieldList();
    SmartDialog.showToast("已清空过滤关键词");
  }

  Future<void> clearUsers({bool clearAll = false}) async {
    final hasValues = clearAll
        ? settingsController.userShieldList.isNotEmpty
        : currentUserShieldValues.isNotEmpty;
    if (!hasValues) {
      SmartDialog.showToast(
        clearAll ? "当前没有可清空的屏蔽用户名" : "当前分组没有可清空的屏蔽用户名",
      );
      return;
    }
    final title = clearAll ? "确认清空全部用户名" : "确认清空当前分组";
    final content = clearAll
        ? "此操作会删除所有平台的用户屏蔽名单，删除后无法恢复。"
        : "此操作会删除$currentUserSiteLabel分组下的用户屏蔽名单，删除后无法恢复。";
    final confirm = await Utils.showAlertDialog(
      content,
      title: title,
      confirm: "确认清空",
      cancel: "取消",
    );
    if (!confirm) {
      return;
    }
    await settingsController.clearUserShieldList(
      siteId: clearAll ? null : currentUserSiteId,
    );
    SmartDialog.showToast(clearAll ? "已清空全部用户名屏蔽" : "已清空当前分组");
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

  Future<void> editPreset(String originalName, String nextName) async {
    final oldValue = originalName.trim();
    final newValue = nextName.trim();
    if (newValue.isEmpty) {
      SmartDialog.showToast("请输入预设名称");
      return;
    }

    if (oldValue != newValue &&
        settingsController.shieldPresetList.any((item) => item.name == newValue)) {
      final confirm = await Utils.showAlertDialog(
        "已经存在同名预设，继续后会用当前关键词和用户分组覆盖它。",
        title: "确认覆盖同名预设",
        confirm: "覆盖保存",
        cancel: "取消",
      );
      if (!confirm) {
        return;
      }
    }

    final success = await settingsController.saveShieldPreset(newValue);
    if (!success) {
      SmartDialog.showToast("更新屏蔽预设失败");
      return;
    }
    if (oldValue.isNotEmpty && oldValue != newValue) {
      await settingsController.deleteShieldPreset(oldValue);
    }
    SmartDialog.showToast("已更新屏蔽预设");
  }

  Future<void> applyPreset(String name) async {
    final success = await settingsController.applyShieldPreset(name);
    SmartDialog.showToast(success ? "已启用屏蔽预设" : "启用屏蔽预设失败");
  }

  Future<void> deletePreset(String name) async {
    final success = await settingsController.deleteShieldPreset(name);
    SmartDialog.showToast(success ? "已删除屏蔽预设" : "删除屏蔽预设失败");
  }

  Future<void> exportPresetFile() async {
    try {
      final status = await Utils.checkStorgePermission();
      if (!status) {
        SmartDialog.showToast("没有存储权限");
        return;
      }
      var dir = "";
      if (Platform.isIOS) {
        dir = (await getApplicationDocumentsDirectory()).path;
      } else {
        dir = await FilePicker.platform.getDirectoryPath() ?? "";
      }
      if (dir.isEmpty) {
        return;
      }
      final file = File(
        "$dir/SimpleLiveShield_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json",
      );
      await file.writeAsString(settingsController.generateShieldPresetJson());
      SmartDialog.showToast("已导出屏蔽预设");
    } catch (e) {
      SmartDialog.showToast("导出失败：$e");
    }
  }

  void exportPresetText() {
    final content = settingsController.generateShieldPresetJson();
    Get.dialog(
      AlertDialog(
        title: const Text("导出屏蔽预设"),
        content: TextField(
          controller: TextEditingController(text: content),
          readOnly: true,
          minLines: 8,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("关闭"),
          ),
          TextButton(
            onPressed: () {
              Utils.copyToClipboard(content);
              Get.back();
            },
            child: const Text("复制"),
          ),
        ],
      ),
    );
  }

  Future<void> importPresetFile() async {
    try {
      final status = await Utils.checkStorgePermission();
      if (!status) {
        SmartDialog.showToast("没有存储权限");
        return;
      }
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null || file.files.single.path == null) {
        return;
      }
      final content = await File(file.files.single.path!).readAsString();
      await settingsController.importShieldPresetJson(content);
      SmartDialog.showToast("导入成功，当前配置和预设已更新");
    } catch (e) {
      SmartDialog.showToast("导入失败，请检查文件内容");
    }
  }

  Future<void> importPresetText() async {
    final textController = TextEditingController();
    await Get.dialog(
      AlertDialog(
        title: const Text("导入屏蔽预设"),
        content: TextField(
          controller: textController,
          minLines: 8,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "粘贴导出的 JSON 内容",
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: textController.clear,
            child: const Text("清空输入"),
          ),
          FilledButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) {
                SmartDialog.showToast("内容为空");
                return;
              }
              try {
                await settingsController.importShieldPresetJson(
                  textController.text,
                );
                Get.back();
                SmartDialog.showToast("导入成功，当前配置和预设已更新");
              } catch (e) {
                SmartDialog.showToast("导入失败，请检查内容是否正确");
              }
            },
            child: const Text("导入"),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    textEditingController.dispose();
    userTextEditingController.dispose();
    super.onClose();
  }
}
