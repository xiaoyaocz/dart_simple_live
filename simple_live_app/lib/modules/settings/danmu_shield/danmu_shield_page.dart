import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/models/danmu_shield_preset.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class DanmuShieldPage extends GetView<DanmuShieldController> {
  const DanmuShieldPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("弹幕屏蔽"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          _buildSwitchSection(),
          AppStyle.vGap24,
          _buildKeywordSection(),
          AppStyle.vGap24,
          _buildUserSection(),
          AppStyle.vGap24,
          _buildPresetSection(),
        ],
      ),
    );
  }

  Widget _buildSwitchSection() {
    final settings = controller.settingsController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "屏蔽开关",
          style: Get.textTheme.titleMedium,
        ),
        AppStyle.vGap8,
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsSwitch(
                  title: "启用弹幕屏蔽",
                  subtitle: "关闭后，关键词和用户屏蔽都会暂时失效",
                  value: settings.danmuShieldEnable.value,
                  onChanged: settings.setDanmuShieldEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "启用关键词屏蔽",
                  value: settings.danmuKeywordShieldEnable.value,
                  onChanged: settings.setDanmuKeywordShieldEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "启用用户屏蔽",
                  subtitle: "可按平台分别管理，也可在直播间点击用户名快速处理",
                  value: settings.danmuUserShieldEnable.value,
                  onChanged: settings.setDanmuUserShieldEnable,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "关键词屏蔽",
                style: Get.textTheme.titleMedium,
              ),
            ),
            Obx(
              () => FilledButton.tonalIcon(
                onPressed: controller.settingsController.shieldList.isEmpty
                    ? null
                    : controller.clearKeywords,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text("一键清空"),
              ),
            ),
          ],
        ),
        AppStyle.vGap8,
        TextField(
          controller: controller.textEditingController,
          decoration: InputDecoration(
            contentPadding: AppStyle.edgeInsetsH12,
            border: const OutlineInputBorder(),
            hintText: "请输入关键词或正则表达式",
            suffixIcon: TextButton.icon(
              onPressed: controller.add,
              icon: const Icon(Icons.add),
              label: const Text("添加"),
            ),
          ),
          onSubmitted: (_) => controller.add(),
        ),
        AppStyle.vGap4,
        Text(
          r'使用 /.../ 会按正则表达式匹配，例如 /\d+/ 可屏蔽所有数字。',
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap12,
        Obx(
          () => Text(
            "已添加 ${controller.settingsController.shieldList.length} 个关键词（点击编辑，点叉移除）",
            style: Get.textTheme.titleSmall,
          ),
        ),
        AppStyle.vGap12,
        Obx(
          () => _buildShieldChips(
            items: controller.settingsController.shieldList,
            onEdit: (item) => _showEditValueDialog(
              title: "编辑关键词",
              initialValue: item,
              hintText: "请输入关键词或正则表达式",
              onConfirm: (value) => controller.edit(item, value),
            ),
            onRemove: controller.remove,
            emptyText: "当前还没有过滤关键词",
          ),
        ),
      ],
    );
  }

  Widget _buildUserSection() {
    final settings = controller.settingsController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "用户屏蔽",
                style: Get.textTheme.titleMedium,
              ),
            ),
            Obx(
              () => FilledButton.tonalIcon(
                onPressed: controller.currentUserShieldValues.isEmpty
                    ? null
                    : controller.clearUsers,
                icon: const Icon(Icons.delete_outline),
                label: const Text("清空当前分组"),
              ),
            ),
          ],
        ),
        AppStyle.vGap8,
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.userShieldSiteIds
                .map(
                  (siteId) => FilterChip(
                    selected: controller.selectedUserSiteId.value == siteId,
                    label: Text(settings.resolveShieldSiteLabel(siteId)),
                    onSelected: (_) => controller.setSelectedUserSite(siteId),
                  ),
                )
                .toList(),
          ),
        ),
        AppStyle.vGap8,
        TextField(
          controller: controller.userTextEditingController,
          decoration: InputDecoration(
            contentPadding: AppStyle.edgeInsetsH12,
            border: const OutlineInputBorder(),
            hintText: "请输入要屏蔽的用户名",
            suffixIcon: TextButton.icon(
              onPressed: controller.addUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("添加"),
            ),
          ),
          onSubmitted: (_) => controller.addUser(),
        ),
        AppStyle.vGap4,
        Text(
          "当前分组只影响对应平台；“全平台”分组会在所有平台一起生效。",
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap4,
        Text(
          "直播间里点击用户名还能直接屏蔽、临时禁言、备注或复制。",
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap12,
        Obx(() {
          final currentCount = controller.currentUserShieldValues.length;
          final globalCount = settings
              .getUserShieldValues(
                siteId: controller.currentUserSiteId,
                includeGlobal: true,
              )
              .length;
          final isGlobal = controller.currentUserSiteId ==
              controller.userShieldSiteIds.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "当前分组已屏蔽 $currentCount 个用户（点击编辑，点叉移除）",
                style: Get.textTheme.titleSmall,
              ),
              if (!isGlobal) ...[
                AppStyle.vGap4,
                Text(
                  "算上“全平台”分组后，本平台实际会命中 $globalCount 个用户名。",
                  style: Get.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          );
        }),
        AppStyle.vGap12,
        Obx(
          () => _buildShieldChips(
            items: controller.currentUserShieldValues,
            onEdit: (item) => _showEditValueDialog(
              title: "编辑用户名",
              initialValue: item,
              hintText: "请输入要屏蔽的用户名",
              onConfirm: (value) => controller.editUser(item, value),
            ),
            onRemove: (item) => controller.removeUser(item),
            emptyText: "当前分组还没有屏蔽用户名",
          ),
        ),
        AppStyle.vGap8,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => controller.clearUsers(clearAll: true),
            icon: const Icon(Icons.warning_amber_outlined),
            label: const Text("清空全部平台"),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "屏蔽预设",
                style: Get.textTheme.titleMedium,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showSavePresetDialog,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text("保存当前"),
            ),
            AppStyle.hGap8,
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case "export_file":
                    controller.exportPresetFile();
                    break;
                  case "export_text":
                    controller.exportPresetText();
                    break;
                  case "import_file":
                    controller.importPresetFile();
                    break;
                  case "import_text":
                    controller.importPresetText();
                    break;
                  default:
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: "export_file",
                  child: Text("导出到文件"),
                ),
                PopupMenuItem(
                  value: "export_text",
                  child: Text("导出为文本"),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: "import_file",
                  child: Text("从文件导入"),
                ),
                PopupMenuItem(
                  value: "import_text",
                  child: Text("从文本导入"),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.import_export),
              ),
            ),
          ],
        ),
        AppStyle.vGap8,
        Text(
          "导出时会带上当前关键词、当前分平台用户名单以及已保存的全部预设，方便多设备迁移。",
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap4,
        Text(
          "如果你先把当前关键词或用户分组调整好，再点某个预设的“编辑保存”，就能直接覆盖原预设内容。",
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap12,
        Obx(() {
          final presets = controller.settingsController.shieldPresetList;
          if (presets.isEmpty) {
            return _buildEmptyBox("还没有保存过屏蔽预设");
          }

          return SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < presets.length; i++) ...[
                  _buildPresetItem(presets[i]),
                  if (i != presets.length - 1) AppStyle.divider,
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPresetItem(DanmuShieldPreset preset) {
    final userTotal = preset.userGroups.values.fold<int>(
      0,
      (sum, values) => sum + values.length,
    );
    return Padding(
      padding: AppStyle.edgeInsetsA12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: Get.textTheme.titleSmall,
                ),
                AppStyle.vGap4,
                Text(
                  "关键词 ${preset.keywords.length} 个，用户 $userTotal 个，分组 ${preset.userGroups.length} 个",
                  style: Get.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => controller.applyPreset(preset.name),
            child: const Text("启用"),
          ),
          TextButton(
            onPressed: () => _showEditPresetDialog(preset.name),
            child: const Text("编辑保存"),
          ),
          TextButton(
            onPressed: () => _showDeletePresetDialog(preset.name),
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldChips({
    required Iterable<String> items,
    required ValueChanged<String> onEdit,
    required ValueChanged<String> onRemove,
    required String emptyText,
  }) {
    final values = items.toList();
    if (values.isEmpty) {
      return _buildEmptyBox(emptyText);
    }

    return Wrap(
      runSpacing: 12,
      spacing: 12,
      children: values
          .map(
            (item) => InkWell(
              borderRadius: AppStyle.radius24,
              onTap: () => onEdit(item),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: AppStyle.radius24,
                ),
                padding: AppStyle.edgeInsetsH12.copyWith(
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        item,
                        style: Get.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppStyle.hGap4,
                    GestureDetector(
                      onTap: () => onRemove(item),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _showEditValueDialog({
    required String title,
    required String initialValue,
    required String hintText,
    required ValueChanged<String> onConfirm,
  }) {
    final textController = TextEditingController(text: initialValue);
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
          onSubmitted: (_) {
            final value = textController.text;
            Get.back();
            onConfirm(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () {
              final value = textController.text;
              Get.back();
              onConfirm(value);
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      padding: AppStyle.edgeInsetsA12,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(60)),
        borderRadius: AppStyle.radius8,
      ),
      child: Text(
        text,
        style: Get.textTheme.bodyMedium?.copyWith(color: Colors.grey),
      ),
    );
  }

  void _showSavePresetDialog() {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("保存屏蔽预设"),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "输入一个预设名称",
          ),
          onSubmitted: (_) async {
            final name = textController.text;
            Get.back();
            await controller.savePreset(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () async {
              final name = textController.text;
              Get.back();
              await controller.savePreset(name);
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  void _showEditPresetDialog(String name) {
    final textController = TextEditingController(text: name);
    Get.dialog(
      AlertDialog(
        title: const Text("编辑并覆盖预设"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "会用当前页面里的关键词和用户分组，覆盖这个预设。",
            ),
            AppStyle.vGap12,
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "预设名称",
              ),
              onSubmitted: (_) async {
                final nextName = textController.text;
                Get.back();
                await controller.editPreset(name, nextName);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () async {
              final nextName = textController.text;
              Get.back();
              await controller.editPreset(name, nextName);
            },
            child: const Text("覆盖保存"),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(String name) {
    Get.dialog(
      AlertDialog(
        title: const Text("删除屏蔽预设"),
        content: Text('确定要删除“$name”吗？'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () async {
              Get.back();
              await controller.deletePreset(name);
            },
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }
}
