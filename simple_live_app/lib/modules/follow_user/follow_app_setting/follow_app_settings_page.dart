import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_app_setting/follow_app_settings_controller.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu_check.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class FollowSettingsPage extends GetView<FollowAppSettingsController> {
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
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
                child: Text(
                  "标签管理",
                  style: Get.textTheme.titleSmall,
                ),
              ),
              SettingsCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsAction(
                      title: "标签管理",
                      onTap: controller.showTagsManager,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
                child: Text(
                  "关注清理功能",
                  style: Get.textTheme.titleSmall,
                ),
              ),
              SettingsCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // todo：筛选条件设置
                    // SettingsAction(
                    //   title: "筛选条件设置",
                    // ),
                    SettingsMenuCheck<FollowUser>(
                      title: '选择要清理的用户',
                      confirmText: '清理',
                      itemToString: (user) => user.userName, // 告诉组件如何显示用户名

                      // 这里传入您自己的筛选函数
                      itemsProvider: () async {
                        return controller.buildAutoCleanPool();
                      },
                      // 用户点击“清理”按钮后的回调
                      onConfirm: (List<FollowUser> selectedUsers) {
                        controller.cleanFollow(selectedUsers);
                      },
                    )
                  ],
                ),
              ),
              Padding(
                padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
                child: Text(
                  "自动更新设置",
                  style: Get.textTheme.titleSmall,
                ),
              ),
              SettingsCard(
                child: Column(
                  children: [
                    Obx(
                      () => SettingsSwitch(
                        value: controller.appC.autoUpdateFollowEnable.value,
                        title: "自动更新关注直播状态",
                        onChanged: (e) {
                          controller.appC.setAutoUpdateFollowEnable(e);
                          FollowService.instance.initTimer();
                        },
                      ),
                    ),
                    Obx(
                      () => Visibility(
                        visible: controller.appC.autoUpdateFollowEnable.value,
                        child: AppStyle.divider,
                      ),
                    ),
                    Obx(
                      () => Visibility(
                        visible: controller.appC.autoUpdateFollowEnable.value,
                        child: SettingsAction(
                          title: "自动更新间隔",
                          value:
                              "${controller.appC.autoUpdateFollowDuration.value ~/ 60}小时${controller.appC.autoUpdateFollowDuration.value % 60}分钟",
                          onTap: () {
                            setTimer(context);
                          },
                        ),
                      ),
                    ),
                    AppStyle.divider,
                    Obx(
                      () => SettingsNumber(
                        value: controller.appC.updateFollowThreadCount.value,
                        title: "更新线程数",
                        subtitle: "多线程可以能更快的完成加载，但可能会因为请求太频繁导致读取状态失败",
                        min: 1,
                        max: 12,
                        onChanged: (e) {
                          controller.appC.setUpdateFollowThreadCount(e);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void setTimer(BuildContext context) async {
    var value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.appC.autoUpdateFollowDuration.value ~/ 60,
        minute: controller.appC.autoUpdateFollowDuration.value % 60,
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
    controller.appC.setAutoUpdateFollowDuration(duration.inMinutes);
    FollowService.instance.initTimer();
  }
}
