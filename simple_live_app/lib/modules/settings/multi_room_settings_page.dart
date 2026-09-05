import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/desktop_multi_window_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class MultiRoomSettingsPage extends GetView<AppSettingsController> {
  const MultiRoomSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("多开设置"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: "默认收起聊天区",
                    subtitle: "从关注页多开时，独立直播窗口默认只保留展开按钮",
                    value: controller.multiRoomCollapseChat.value,
                    onChanged: controller.setMultiRoomCollapseChat,
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () => SettingsNumber(
                    title: "布局间距",
                    subtitle: "影响独立窗口铺排、桌面同屏多开和 TV 多屏同播",
                    value: controller.effectiveMultiRoomGap,
                    min: AppSettingsController.kMultiRoomMinGap,
                    max: AppSettingsController.kMultiRoomMaxGap,
                    unit: "px",
                    onChanged: controller.setMultiRoomGap,
                  ),
                ),
              ],
            ),
          ),
          AppStyle.vGap12,
          const SettingsCard(
            child: SettingsAction(
              title: "关闭所有多开窗口",
              subtitle: "关闭本次从关注页多开启动的独立直播窗口",
              leading: Icon(Icons.close),
              onTap: DesktopMultiWindowService.closeOpenedRooms,
            ),
          ),
        ],
      ),
    );
  }
}
