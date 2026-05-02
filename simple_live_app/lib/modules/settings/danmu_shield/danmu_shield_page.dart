import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_controller.dart';

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
            '使用 /.../ 会按正则表达式匹配，例如 /\\d+/ 可屏蔽所有数字。',
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
          AppStyle.vGap24,
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
}
