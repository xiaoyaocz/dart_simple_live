import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/settings/indexed_settings/indexed_settings_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';

class PlaybackPageSettingsPage extends GetView<IndexedSettingsController> {
  const PlaybackPageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("播放页设置"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "播放页标签顺序",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: controller.updateLiveRoomTabSort,
                children: controller.liveRoomTabSort.map(
                  (key) {
                    final item = Constant.allLiveRoomTabs[key]!;
                    return ListTile(
                      key: ValueKey("tab_$key"),
                      title: Text(item.title),
                      subtitle:
                          item.subtitle == null ? null : Text(item.subtitle!),
                      visualDensity: VisualDensity.compact,
                      leading: Icon(item.iconData),
                      trailing: _buildTrailingAction(key),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "全屏长按快捷入口",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: controller.updateLiveRoomQuickAccessSort,
                children: controller.liveRoomQuickAccessSort.map(
                  (key) {
                    final item = Constant.allLiveRoomQuickAccess[key]!;
                    final enabled =
                        controller.liveRoomQuickAccessEnabled.contains(key);
                    return ListTile(
                      key: ValueKey("quick_$key"),
                      leading: Icon(item.iconData),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      visualDensity: VisualDensity.compact,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: enabled,
                            onChanged: (value) {
                              controller.setLiveRoomQuickAccessEnabled(
                                key,
                                value,
                              );
                            },
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
              child: Text(
                "桌面快捷键",
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => SettingsMenu<int>(
                      title: "切换全屏",
                      subtitle: "仅在直播间且输入框未聚焦时生效，桌面端中文输入法下也支持",
                      value: AppSettingsController
                          .instance.liveRoomShortcutFullScreen.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutFullScreen,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "显示/隐藏弹幕",
                      subtitle: "仅在直播间且输入框未聚焦时生效",
                      value: AppSettingsController
                          .instance.liveRoomShortcutDanmaku.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutDanmaku,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "静音/取消静音",
                      subtitle: "仅在直播间且输入框未聚焦时生效",
                      value: AppSettingsController
                          .instance.liveRoomShortcutMute.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutMute,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "刷新直播间",
                      subtitle: "仅在直播间且输入框未聚焦时生效",
                      value: AppSettingsController
                          .instance.liveRoomShortcutRefresh.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutRefresh,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "收起/展开聊天区",
                      subtitle: "仅在直播间且输入框未聚焦时生效",
                      value: AppSettingsController
                          .instance.liveRoomShortcutToggleChat.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutToggleChat,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "调高音量",
                      subtitle: "每次增加 5%，仅在直播间且输入框未聚焦时生效",
                      value: AppSettingsController
                          .instance.liveRoomShortcutVolumeUp.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutVolumeUp,
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsMenu<int>(
                      title: "调低音量",
                      subtitle: "每次减少 5%，仅在直播间且输入框未聚焦时生效",
                      value: AppSettingsController
                          .instance.liveRoomShortcutVolumeDown.value,
                      valueMap: AppSettingsController.liveRoomShortcutOptions,
                      onChanged: AppSettingsController
                          .instance.setLiveRoomShortcutVolumeDown,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrailingAction(String key) {
    if (key == "contribution_rank") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => Switch(
              value: controller.contributionRankEnable.value,
              onChanged: controller.setContributionRankEnable,
            ),
          ),
          const Icon(Icons.drag_handle),
        ],
      );
    }
    if (key == "event_flow") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => Switch(
              value: controller.liveEventFlowEnable.value,
              onChanged: controller.setLiveEventFlowEnable,
            ),
          ),
          const Icon(Icons.drag_handle),
        ],
      );
    }
    return const Icon(Icons.drag_handle);
  }
}
