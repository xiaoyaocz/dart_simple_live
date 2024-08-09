import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/remote_sync/room/remote_sync_room_controller.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class RemoteSyncRoomPage extends GetView<RemoteSyncRoomController> {
  const RemoteSyncRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("数据同步"),
        actions: [
          Padding(
            padding: AppStyle.edgeInsetsH12,
            child: StreamBuilder<SignalRConnectionState>(
              stream: controller.signalR.stateStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  switch (snapshot.data) {
                    case SignalRConnectionState.connected:
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AppStyle.hGap8,
                          const Text(
                            '已连接',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    case SignalRConnectionState.disconnected:
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AppStyle.hGap8,
                          const Text(
                            '断开连接',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    default:
                      return const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          Text(
                            '连接中',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
        children: [
          Visibility(
            visible: controller.roomId.isEmpty,
            child: SettingsCard(
              child: ListTile(
                visualDensity: VisualDensity.compact,
                leading: const Icon(Remix.timer_line),
                title: Obx(
                  () => Text(
                    "${controller.countDown.value}秒后房间将会自动关闭",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12,
            child: Text(
              "房间号",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ListTile(
                title: SelectableText(
                  controller.currentRoomId.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                trailing: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                      ),
                      onPressed: () {
                        Utils.copyToClipboard(controller.currentRoomId.value);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code,
                        size: 20,
                      ),
                      onPressed: () {
                        controller.showQRInfo();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
            child: Text(
              "同步操作",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Remix.heart_line),
                  title: const Text("发送关注列表"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncFollow();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text("发送观看记录"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncHistory();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.shield_keyhole_line),
                  title: const Text("发送弹幕屏蔽词"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncBlockedWord();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.account_circle_line),
                  title: const Text("发送哔哩哔哩账号"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncBiliAccount();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
            child: Text(
              "已连接设备",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ListView.separated(
                itemCount: controller.roomUsers.length,
                shrinkWrap: true,
                separatorBuilder: (context, index) => AppStyle.divider,
                itemBuilder: (BuildContext context, int index) {
                  var user = controller.roomUsers[index];
                  return ListTile(
                    visualDensity: VisualDensity.compact,
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: buildIcon(user.platform),
                      ),
                    ),
                    title: Text(user.shortId),
                    subtitle: Text("${user.app} - v${user.version}"),
                    trailing: Visibility(
                      visible: controller.signalR.hubConnection?.connectionId ==
                          user.connectionId,
                      child: const Text(
                        "本机",
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget buildIcon(String platform) {
    if (platform == "android") {
      return const Icon(Remix.android_line);
    } else if (platform == "ios") {
      return const Icon(Remix.apple_line);
    } else if (platform == "tv") {
      return const Icon(Remix.tv_2_line);
    } else if (platform == "windows") {
      return const Icon(Remix.microsoft_fill);
    } else if (platform == "xbox") {
      return const Icon(Remix.xbox_line);
    } else if (platform == "macos") {
      return const Icon(Remix.mac_line);
    } else if (platform == "linux") {
      return const Icon(Remix.ubuntu_line);
    } else {
      return const Icon(Remix.device_line);
    }
  }
}
