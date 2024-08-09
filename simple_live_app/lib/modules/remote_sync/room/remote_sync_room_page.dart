import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/remote_sync/room/remote_sync_room_controller.dart';
import 'package:simple_live_app/services/signalr_service.dart';

class RemoteSyncRoomPage extends GetView<RemoteSyncRoomController> {
  const RemoteSyncRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("数据同步"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          StreamBuilder<SignalRConnectionState>(
            stream: controller.signalR.stateStream,
            builder: (context, snapshot) {
              var stateString = "未连接";
              if (snapshot.hasData) {
                switch (snapshot.data) {
                  case SignalRConnectionState.connecting:
                    stateString = "连接中";
                    break;
                  case SignalRConnectionState.connected:
                    stateString = "已连接";
                    break;
                  case SignalRConnectionState.disconnected:
                    stateString = "已断开";
                    break;
                  default:
                    stateString = "--";
                    break;
                }
              }
              return ListTile(
                title: const Text("连接状态"),
                subtitle: Text(stateString),
                leading: const Icon(Icons.wifi),
                trailing: const Icon(Icons.refresh),
                onTap: () {
                  controller.signalR.connect();
                },
              );
            },
          ),
          Obx(
            () => Text(controller.currentRoomId.value),
          ),
          Obx(
            () => ListView.builder(
              itemCount: controller.roomUsers.length,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int index) {
                var user = controller.roomUsers[index];
                return ListTile(
                  title: Text(user.shortId),
                  subtitle:
                      Text("${user.app}-${user.platform}-${user.version}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
