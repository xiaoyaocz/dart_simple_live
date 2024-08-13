import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class FollowSettingsPage extends GetView<AppSettingsController> {
  const FollowSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("关注设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: controller.autoUpdateFollowEnable.value,
                    title: "自动更新关注直播状态",
                    onChanged: (e) {
                      controller.setAutoUpdateFollowEnable(e);
                      FollowService.instance.initTimer();
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: controller.autoUpdateFollowEnable.value,
                    child: AppStyle.divider,
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: controller.autoUpdateFollowEnable.value,
                    child: SettingsAction(
                      title: "自动更新间隔",
                      value:
                          "${controller.autoUpdateFollowDuration.value ~/ 60}小时${controller.autoUpdateFollowDuration.value % 60}分钟",
                      onTap: () {
                        setTimer(context);
                      },
                    ),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsNumber(
                    value: controller.updateFollowThreadCount.value,
                    title: "更新线程数",
                    subtitle: "多线程可以能更快的完成加载，但可能会因为请求太频繁导致读取状态失败",
                    min: 1,
                    max: 12,
                    onChanged: (e) {
                      controller.setUpdateFollowThreadCount(e);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void setTimer(BuildContext context) async {
    var value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.autoUpdateFollowDuration.value ~/ 60,
        minute: controller.autoUpdateFollowDuration.value % 60,
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
    var duration = Duration(hours: value.hour, minutes: value.minute);
    controller.setAutoUpdateFollowDuration(duration.inMinutes);
    FollowService.instance.initTimer();
  }
}
