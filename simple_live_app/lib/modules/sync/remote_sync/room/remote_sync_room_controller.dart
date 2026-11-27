import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

class RemoteSyncRoomController extends BaseController {
  final String roomId;
  final List<String> relayAddresses;
  final SignalRService signalR = SignalRService();
  RemoteSyncRoomController(String code)
      : roomId = code.split('|').first,
        relayAddresses =
            code.contains('|') ? code.split('|').last.split(';') : const [] {
    if (roomId.isNotEmpty) {
      currentRoomId.value = roomId;
    }
  }
  StreamSubscription? _roomDestroyedSubscription;
  StreamSubscription? _roomUserUpdatedSubscription;
  StreamSubscription? _onFavoriteSubscription;
  StreamSubscription? _onHistorySubscription;
  StreamSubscription? _onShieldWordSubscription;
  StreamSubscription? _onBiliAccountSubscription;
  var currentRoomId = "--".obs;
  RxList<RoomUser> roomUsers = <RoomUser>[].obs;
  bool _qrSheetOpen = false;
  Set<String> _qrKnownUserIds = {};

  static String _userId(RoomUser user) =>
      user.connectionId.isNotEmpty ? user.connectionId : user.shortId;

  static bool hasNewRemoteUser(Set<String> knownIds, List<RoomUser> users) =>
      users.any((user) => !user.isSelf && !knownIds.contains(_userId(user)));

  Timer? _timer;
  var countDown = 600.obs;

  @override
  void onInit() {
    listenSignalR();
    connect();
    super.onInit();
  }

  void connect() async {
    try {
      await signalR.connect(relayAddresses: relayAddresses);
      if (isClosed) return;
      if (signalR.state == SignalRConnectionState.connected) {
        if (roomId.isEmpty) {
          createRoom();
        } else {
          joinRoom(roomId);
        }
      }
    } catch (e, stackTrace) {
      Log.e('连接远程同步服务失败：$e', stackTrace);
      if (isClosed) return;
      final retry = await Utils.showAlertDialog(
        '设备无法连接远程同步服务：\n$e\n\n请检查网络后重试。',
        title: '远程同步不可用',
        cancel: '返回同步选项',
        confirm: '重试',
        selectable: true,
      );
      if (isClosed) return;
      if (retry) {
        connect();
      } else {
        Get.back();
      }
    }
  }

  void createRoom() async {
    try {
      var resp = await signalR.createRoom();
      if (resp.isSuccess) {
        currentRoomId.value = resp.data!;
        _startTimer();
      } else {
        Log.w('创建房间失败：${resp.message}');
        await _showRemoteSyncUnavailable('创建房间失败：${resp.message}');
      }
    } catch (e, stackTrace) {
      Log.e('创建房间失败：$e', stackTrace);
      await _showRemoteSyncUnavailable('远程同步服务暂时无法创建房间。');
    }
  }

  Future<void> _showRemoteSyncUnavailable(String reason) async {
    if (isClosed) return;
    await Utils.showMessageDialog(
      '$reason\n请使用局域网同步或 WebDAV。',
      title: '远程同步不可用',
      confirm: '返回同步选项',
    );
    if (!isClosed) Get.back();
  }

  void _startTimer() {
    // 倒计时5分钟，自动关闭页面
    countDown.value = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countDown--;
      if (countDown <= 0) {
        timer.cancel();
        Get.back();
      }
    });
  }

  void joinRoom(String roomId) async {
    try {
      var resp = await signalR.joinRoom(roomId);
      if (!resp.isSuccess) {
        SmartDialog.showToast(resp.message);
        Get.back();
      }
    } catch (e) {
      SmartDialog.showToast("加入房间失败");
      Get.back();
    }
  }

  void listenSignalR() {
    _roomDestroyedSubscription = signalR.onRoomDestroyedStream.listen((roomId) {
      SmartDialog.showToast("房间已被销毁");
      Get.back();
    });
    _roomUserUpdatedSubscription =
        signalR.onRoomUserUpdatedStream.listen(onRoomUsersUpdated);
    _onFavoriteSubscription = signalR.onFavoriteStream.listen((data) {
      onReceiveFavorite(data.$1, data.$2);
    });
    _onHistorySubscription = signalR.onHistoryStream.listen((data) {
      onReceiveHistory(data.$1, data.$2);
    });
    _onShieldWordSubscription = signalR.onShieldWordStream.listen((data) {
      onReceiveShieldWord(data.$1, data.$2);
    });
    _onBiliAccountSubscription = signalR.onBiliAccountStream.listen((data) {
      onReceiveBiliAccount(data.$1, data.$2);
    });
  }

  void onRoomUsersUpdated(List<RoomUser> users) {
    final closeQr = _qrSheetOpen && hasNewRemoteUser(_qrKnownUserIds, users);
    roomUsers.assignAll(users);
    if (closeQr) {
      _qrSheetOpen = false;
      Navigator.of(Get.context!).pop();
    }
  }

  void onReceiveFavorite(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data) as List;
      var added = 0;
      var updated = 0;
      for (var item in jsonBody) {
        var user = FollowUser.fromJson(Map<String, dynamic>.from(item as Map));
        final existing = DBService.instance.followBox.get(user.id);
        if (existing == null) {
          await DBService.instance.followBox.put(user.id, user);
          added++;
        } else {
          var changed = false;
          if (user.userName.isNotEmpty && existing.userName != user.userName) {
            existing.userName = user.userName;
            changed = true;
          }
          if (user.face.isNotEmpty && existing.face != user.face) {
            existing.face = user.face;
            changed = true;
          }
          if (existing.tag == "全部" && user.tag.isNotEmpty && user.tag != "全部") {
            existing.tag = user.tag;
            changed = true;
          }
          if ((existing.categoryName == null ||
                  existing.categoryName!.isEmpty) &&
              user.categoryName != null &&
              user.categoryName!.isNotEmpty) {
            existing.categoryName = user.categoryName;
            changed = true;
          }
          if (changed) {
            await DBService.instance.followBox.put(user.id, existing);
            updated++;
          }
        }
      }
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      SmartDialog.showToast(
        added > 0 || updated > 0
            ? "已同步关注列表（新增$added，更新$updated）"
            : "已同步关注列表（无新增）",
      );
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveHistory(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data) as List;
      var added = 0;
      for (var item in jsonBody) {
        var history = History.fromJson(Map<String, dynamic>.from(item as Map));
        final existing = DBService.instance.historyBox.get(history.id);
        if (existing == null || history.updateTime.isAfter(existing.updateTime)) {
          await DBService.instance.addOrUpdateHistory(history);
          added++;
        }
      }
      SmartDialog.showToast(
        added > 0 ? '已同步历史记录（新增/更新$added条）' : '已同步历史记录（无新增）',
      );
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveShieldWord(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      for (var item in jsonBody) {
        // add to Hive
        AppSettingsController.instance.addShieldList(item.toString());
      }
      SmartDialog.showToast('已同步屏蔽词');
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveBiliAccount(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      var cookie = jsonBody['cookie'];
      if (cookie is String && cookie.isNotEmpty) {
        if (BiliBiliAccountService.instance.cookie != cookie) {
          BiliBiliAccountService.instance.setCookie(cookie);
          BiliBiliAccountService.instance.loadUserInfo();
          SmartDialog.showToast('已同步哔哩哔哩账号');
        } else {
          SmartDialog.showToast('哔哩哔哩账号已是最新');
        }
      }
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void syncFollow() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }

      SmartDialog.showLoading(msg: "发送中...");
      var users = DBService.instance.getFollowList();
      var data = json.encode(users.map((e) => e.toJson()).toList());

      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendFavorite",
        overlay: false,
        content: data,
      );
      await SmartDialog.dismiss(status: SmartStatus.loading);
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送 ${users.length} 个关注");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      await SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast("发送失败:$e");
      Log.logPrint(e);
    }
  }

  void syncHistory() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }
      SmartDialog.showLoading(msg: "发送中...");
      var histores = DBService.instance.getHistores();
      var data = json.encode(histores.map((e) => e.toJson()).toList());
      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendHistory",
        overlay: false,
        content: data,
      );
      await SmartDialog.dismiss(status: SmartStatus.loading);
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送 ${histores.length} 条历史记录");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      await SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast("发送失败:$e");
      Log.logPrint(e);
    }
  }

  void syncBlockedWord() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }
      SmartDialog.showLoading(msg: "发送中...");
      var shieldList = AppSettingsController.instance.shieldList;
      var data = json.encode(shieldList.toList());

      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendShieldWord",
        overlay: false,
        content: data,
      );
      await SmartDialog.dismiss(status: SmartStatus.loading);
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送 ${shieldList.length} 条屏蔽词");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      await SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast("发送失败:$e");
      Log.logPrint(e);
    }
  }

  void syncBiliAccount() async {
    try {
      if (roomUsers.length <= 1) {
        SmartDialog.showToast("无设备连接");
        return;
      }
      if (!BiliBiliAccountService.instance.logined.value) {
        SmartDialog.showToast("未登录哔哩哔哩");
        return;
      }
      SmartDialog.showLoading(msg: "发送中...");

      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendBiliAccount",
        overlay: false,
        content: json.encode({
          "cookie": BiliBiliAccountService.instance.cookie,
        }),
      );
      await SmartDialog.dismiss(status: SmartStatus.loading);
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送哔哩哔哩账号");
      } else {
        SmartDialog.showToast("发送失败:${resp.message}");
      }
    } catch (e) {
      await SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void showQRInfo() {
    if (_qrSheetOpen) return;
    _qrKnownUserIds = roomUsers.map(_userId).toSet();
    _qrSheetOpen = true;
    final relay =
        Get.isRegistered<SyncService>() ? SyncService.instance.qrAddress : '';
    Utils.showBottomSheet(
      title: "房间信息",
      child: Column(
        children: [
          QrImageView(
            data: roomId.isEmpty &&
                    (Platform.isWindows ||
                        Platform.isMacOS ||
                        Platform.isLinux) &&
                    relay.isNotEmpty
                ? '${currentRoomId.value}|$relay'
                : currentRoomId.value,
            version: QrVersions.auto,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            size: 300,
          ),
          AppStyle.vGap24,
          Text(
            currentRoomId.value,
            textAlign: TextAlign.center,
            style: Get.textTheme.titleLarge,
          ),
          const Text(
            "请使用其他Simple Live客户端扫描上方二维码\n建立连接后可选择需要同步的数据",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).whenComplete(() {
      _qrSheetOpen = false;
      _qrKnownUserIds.clear();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    _roomDestroyedSubscription?.cancel();
    _roomUserUpdatedSubscription?.cancel();
    _onFavoriteSubscription?.cancel();
    _onHistorySubscription?.cancel();
    _onShieldWordSubscription?.cancel();
    _onBiliAccountSubscription?.cancel();
    signalR.dispose();
    super.onClose();
  }
}
