import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

class AutoExitSettingsPage extends GetView<AppSettingsController> {
  const AutoExitSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("定时关闭设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          Obx(
            () => SwitchListTile(
              title: Text(
                "启用定时关闭",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              value: controller.autoExitEnable.value,
              onChanged: (e) {
                controller.setAutoExitEnable(e);
              },
            ),
          ),
          Obx(
            () => ListTile(
              enabled: controller.autoExitEnable.value,
              title: Text(
                "自动关闭时间：${controller.autoExitDuration.value ~/ 60}小时${controller.autoExitDuration.value % 60}分钟",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text("从进入直播间开始倒计时"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                var value = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: controller.autoExitDuration.value ~/ 60,
                    minute: controller.autoExitDuration.value % 60,
                  ),
                  initialEntryMode: TimePickerEntryMode.inputOnly,
                  builder: (_, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        alwaysUse24HourFormat: true,
                      ),
                      child: child!,
                    );
                  },
                );
                if (value == null || (value.hour == 0 && value.minute == 0)) {
                  return;
                }
                var duration =
                    Duration(hours: value.hour, minutes: value.minute);
                controller.setAutoExitDuration(duration.inMinutes);
              },
            ),
          ),
        ],
      ),
    );
  }
}
