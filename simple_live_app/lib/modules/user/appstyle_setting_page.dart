import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';


double opacityLevel = 1.0;
class AppstyleSettingPage extends GetView<AppSettingsController> {
  const AppstyleSettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("外观设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          ListTile(
              leading:
              Icon(Get.isDarkMode ? Remix.moon_line : Remix.sun_line),
              title: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: const Text("显示主题"),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
              onTap: Get.find<AppSettingsController>().changeTheme,
            ),
          Obx(() => RadioListTile(
            value: true,
            groupValue: controller.styleColor.value,
            onChanged: (e) {
              controller.setStyleColor(e??true);
            },
            title: const Text("动态取色"),
          ),
          ),
          Obx(() =>RadioListTile(
            value: false,
            groupValue: controller.styleColor.value,
            onChanged: (e) {
              controller.setStyleColor(e??false);
            },
            title: const Text("选定颜色"),
          ),
          ),
          Divider(
            indent: 12,
            endIndent: 12,
            color: Colors.grey.withOpacity(.1),
          ),
        ],
      ),
    );
  }
}
