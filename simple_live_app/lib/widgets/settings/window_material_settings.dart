import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/services/window_appearance_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class WindowMaterialSettings extends GetView<WindowAppearanceController> {
  const WindowMaterialSettings({super.key});
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
        child: Obx(() => Column(children: [
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: Text(controller.isAndroid ? '界面材质' : '窗口材质'),
                subtitle: Text(
                    controller.selected.value == controller.effective.value
                        ? '立即生效，自动记住选择'
                        : '当前系统使用${controller.effective.value.label}，保留原选择'),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: DropdownButtonFormField<WindowMaterial>(
                    key: ValueKey(controller.selected.value),
                    initialValue: controller.selected.value,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: controller.isAndroid ? '界面材质' : '窗口材质',
                        border: const OutlineInputBorder()),
                    items: WindowMaterial.values
                        .map((material) => DropdownMenuItem(
                            value: material, child: Text(material.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) controller.setMaterial(value);
                    },
                  )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          controller.isAndroid
                              ? '手机端使用应用内仿材质背景，随深浅色主题变化；不读取壁纸、不透出其他应用。'
                              : '云母适用于 Windows 11。不支持的效果自动回退；高对比度或关闭系统透明效果时使用纯色。',
                          style: Theme.of(context).textTheme.bodySmall))),
            ])));
  }
}
