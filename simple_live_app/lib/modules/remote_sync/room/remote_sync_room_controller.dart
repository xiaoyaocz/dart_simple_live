import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/services/signalr_service.dart';

class RemoteSyncRoomController extends BaseController {
  final String roomId;
  final SignalRService signalR = SignalRService();
  RemoteSyncRoomController(this.roomId) {
    if (roomId.isNotEmpty) {
      currentRoomId.value = roomId;
    }
  }
  StreamSubscription? _roomDestroyedSubscription;
  StreamSubscription? _roomUserUpdatedSubscription;
  var currentRoomId = "--".obs;
  RxList<RoomUser> roomUsers = <RoomUser>[].obs;
  @override
  void onInit() {
    connect();
    super.onInit();
  }

  void connect() async {
    listenSignalR();
    await signalR.connect();
    if (signalR.state == SignalRConnectionState.connected) {
      if (roomId.isEmpty) {
        createRoom();
      } else {
        joinRoom(roomId);
      }
    }
  }

  void listenSignalR() {
    _roomDestroyedSubscription = signalR.onRoomDestroyedStream.listen((roomId) {
      SmartDialog.showToast("房间已被销毁");
      Get.back();
    });
    _roomUserUpdatedSubscription = signalR.onRoomUserUpdatedStream.listen(
      (roomUsers) {
        this.roomUsers.assignAll(roomUsers);
      },
    );
  }

  void createRoom() async {
    try {
      var resp = await signalR.createRoom();
      if (resp.isSuccess) {
        currentRoomId.value = resp.data!;
      } else {
        SmartDialog.showToast(resp.message);
      }
    } catch (e) {
      SmartDialog.showToast("创建房间失败");
    }
  }

  void joinRoom(String roomId) async {
    try {
      var resp = await signalR.joinRoom(roomId);
      if (!resp.isSuccess) {
        SmartDialog.showToast(resp.message);
      }
    } catch (e) {
      SmartDialog.showToast("加入房间失败");
    }
  }

  @override
  void onClose() {
    _roomDestroyedSubscription?.cancel();
    _roomUserUpdatedSubscription?.cancel();
    signalR.dispose();
    super.onClose();
  }
}
