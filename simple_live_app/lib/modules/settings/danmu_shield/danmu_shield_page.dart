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
        padding: AppStyle.edgeInsetsA12,
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
                  subtitle: "也可以在直播间点击用户名快速屏蔽或取消屏蔽",
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
        Text(
          "关键词屏蔽",
          style: Get.textTheme.titleMedium,
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
            "已添加${controller.settingsController.shieldList.length}个关键词（点击移除）",
            style: Get.textTheme.titleSmall,
          ),
        ),
        AppStyle.vGap12,
        Obx(
          () => _buildShieldChips(
            controller.settingsController.shieldList,
            controller.remove,
          ),
        ),
      ],
    );
  }

  Widget _buildUserSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "用户屏蔽",
          style: Get.textTheme.titleMedium,
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
          "直播间里点击用户名可直接屏蔽，再点一次可取消；长按用户名可复制。",
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap12,
        Obx(
          () => Text(
            "已屏蔽${controller.settingsController.userShieldList.length}个用户（点击移除）",
            style: Get.textTheme.titleSmall,
          ),
        ),
        AppStyle.vGap12,
        Obx(
          () => _buildShieldChips(
            controller.settingsController.userShieldList,
            controller.removeUser,
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
                "历史屏蔽预设",
                style: Get.textTheme.titleMedium,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showSavePresetDialog,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text("保存当前"),
            ),
          ],
        ),
        AppStyle.vGap8,
        Text(
          "你可以把当前关键词和用户保存成一套预设，下次直接启用。",
          style: Get.textTheme.bodySmall,
        ),
        AppStyle.vGap12,
        Obx(() {
          final presets = controller.settingsController.shieldPresetList;
          if (presets.isEmpty) {
            return Container(
              padding: AppStyle.edgeInsetsA12,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(60)),
                borderRadius: AppStyle.radius8,
              ),
              child: Text(
                "还没有保存过预设",
                style: Get.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            );
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
                  "关键词 ${preset.keywords.length} 个，用户 ${preset.users.length} 个",
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
            onPressed: () => _showDeletePresetDialog(preset.name),
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldChips(
    Iterable<String> items,
    ValueChanged<String> onRemove,
  ) {
    return Wrap(
      runSpacing: 12,
      spacing: 12,
      children: items
          .map(
            (item) => InkWell(
              borderRadius: AppStyle.radius24,
              onTap: () => onRemove(item),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: AppStyle.radius24,
                ),
                padding: AppStyle.edgeInsetsH12.copyWith(
                  top: 4,
                  bottom: 4,
                ),
                child: Text(
                  item,
                  style: Get.textTheme.bodyMedium,
                ),
              ),
            ),
          )
          .toList(),
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

  void _showDeletePresetDialog(String name) {
    Get.dialog(
      AlertDialog(
        title: const Text("删除屏蔽预设"),
        content: Text("确定删除“$name”吗？"),
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
