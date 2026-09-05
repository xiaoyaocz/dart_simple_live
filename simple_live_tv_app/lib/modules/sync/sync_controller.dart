import 'dart:async';
import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/bulk_data_import_service.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';
import 'package:simple_live_tv_app/widgets/sync_progress_dialog.dart';

class SyncController extends BaseController {
  final SignalRService signalR = SignalRService();
  StreamSubscription? _stateSubscription;
  StreamSubscription? _roomDestroyedSubscription;
  StreamSubscription? _roomUserUpdatedSubscription;
  StreamSubscription? _onFavoriteSubscription;
  StreamSubscription? _onHistorySubscription;
  StreamSubscription? _onShieldWordSubscription;
  StreamSubscription? _onBiliAccountSubscription;
  final currentRoomId = "--".obs;
  final RxList<RoomUser> roomUsers = <RoomUser>[].obs;
  Timer? _timer;
  final countDown = 600.obs;

  final Rx<SignalRConnectionState> state =
      Rx<SignalRConnectionState>(SignalRConnectionState.connecting);

  @override
  void onInit() {
    connect();
    super.onInit();
  }

  void _finishSyncImport({
    required String successMessage,
    String? eventName,
  }) {
    if (eventName != null) {
      EventBus.instance.emit(eventName, 0);
    }
    SyncProgressDialog.dismiss();
    SmartDialog.showToast(successMessage);
  }

  void connect() async {
    try {
      listenSignalR();
      await signalR.connect();
      if (signalR.state == SignalRConnectionState.connected) {
        createRoom();
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("连接同步服务失败：${_formatSyncError(e)}");
      Get.back();
    }
  }

  void createRoom() async {
    try {
      final resp = await signalR.createRoom();
      if (resp.isSuccess && (resp.data?.trim().isNotEmpty ?? false)) {
        currentRoomId.value = resp.data!.trim();
        _startTimer();
      } else {
        SmartDialog.showToast(
          resp.message.isEmpty
              ? "创建房间失败：服务未返回房间号"
              : "创建房间失败：${_formatSyncError(resp.message)}",
        );
        Get.back();
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("创建房间失败：${_formatSyncError(e)}");
      Get.back();
    }
  }

  String _formatSyncError(Object e) {
    final text =
        e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (text.isEmpty) {
      return "未知错误";
    }
    return text;
  }

  void _startTimer() {
    countDown.value = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countDown.value--;
      if (countDown <= 0) {
        timer.cancel();
        Get.back();
      }
    });
  }

  void listenSignalR() {
    _stateSubscription = signalR.stateStream.listen((event) {
      state.value = event;
    });
    _roomDestroyedSubscription = signalR.onRoomDestroyedStream.listen((roomId) {
      SmartDialog.showToast("房间已被销毁");
      Get.back();
    });
    _roomUserUpdatedSubscription = signalR.onRoomUserUpdatedStream.listen(
      (roomUsers) {
        this.roomUsers.assignAll(roomUsers);
      },
    );
    _onFavoriteSubscription = signalR.onFavoriteStream.listen(onReceiveFavorite);
    _onHistorySubscription = signalR.onHistoryStream.listen(onReceiveHistory);
    _onShieldWordSubscription =
        signalR.onShieldWordStream.listen(onReceiveShieldWord);
    _onBiliAccountSubscription =
        signalR.onBiliAccountStream.listen(onReceiveBiliAccount);
  }

  SyncProgress _stageProgress(String stage, RoomSyncPayload payload) {
    final total =
        payload.itemTotal > 0 ? payload.itemTotal : payload.chunkTotal;
    final current =
        payload.itemTotal > 0 ? payload.itemEnd : payload.chunkIndex;
    return SyncProgress(
      stage: stage,
      current: current,
      total: total,
      message: payload.chunkTotal > 1
          ? "接收第 ${payload.chunkIndex}/${payload.chunkTotal} 段"
          : stage,
    );
  }

  SyncProgressCallback _wrapPayloadProgress(RoomSyncPayload payload) {
    return (progress) {
      if (payload.itemTotal <= 0) {
        SyncProgressDialog.update(progress);
        return;
      }
      final current = (payload.itemStart + progress.current)
          .clamp(0, payload.itemTotal)
          .toInt();
      SyncProgressDialog.update(
        SyncProgress(
          stage: progress.stage,
          current: current,
          total: payload.itemTotal,
          message: "${progress.stage} $current/${payload.itemTotal}",
        ),
      );
    };
  }

  void onReceiveFavorite(RoomSyncPayload payload) async {
    try {
      SyncProgressDialog.show(_stageProgress("接收关注", payload));
      final stopwatch = Stopwatch()..start();
      final jsonBody = json.decode(payload.content);
      if (jsonBody is! List) {
        throw const FormatException("关注列表格式不是数组");
      }

      final result = await BulkDataImportService.importFollowUsers(
        jsonBody,
        overwrite: payload.overlay,
        onProgress: _wrapPayloadProgress(payload),
      );

      stopwatch.stop();
      Log.i(
        "房间同步关注完成：${result.logSummary} bytes=${payload.content.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );

      if (payload.isLastChunk) {
        _finishSyncImport(
          successMessage:
              "已同步关注列表（${payload.itemTotal > 0 ? payload.itemTotal : result.imported} 条）",
          eventName: Constant.kUpdateFollow,
        );
      }
    } catch (e) {
      SyncProgressDialog.dismiss();
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveHistory(RoomSyncPayload payload) async {
    try {
      SyncProgressDialog.show(_stageProgress("接收历史", payload));
      final stopwatch = Stopwatch()..start();
      final jsonBody = json.decode(payload.content);
      if (jsonBody is! List) {
        throw const FormatException("历史记录格式不是数组");
      }

      final result = await BulkDataImportService.importHistories(
        jsonBody,
        overwrite: payload.overlay,
        onProgress: _wrapPayloadProgress(payload),
      );

      stopwatch.stop();
      Log.i(
        "房间同步历史完成：${result.logSummary} bytes=${payload.content.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );

      if (payload.isLastChunk) {
        _finishSyncImport(
          successMessage:
              "已同步观看记录（${payload.itemTotal > 0 ? payload.itemTotal : result.imported} 条）",
          eventName: Constant.kUpdateHistory,
        );
      }
    } catch (e) {
      SyncProgressDialog.dismiss();
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveShieldWord(RoomSyncPayload payload) async {
    try {
      SyncProgressDialog.show(_stageProgress("接收屏蔽词", payload));
      final stopwatch = Stopwatch()..start();
      final jsonBody = json.decode(payload.content);
      if (jsonBody is! List) {
        throw const FormatException("屏蔽词格式不是数组");
      }

      final result = await BulkDataImportService.importShieldValues(
        jsonBody,
        overwrite: payload.overlay,
        onProgress: _wrapPayloadProgress(payload),
      );

      stopwatch.stop();
      Log.i(
        "房间同步屏蔽词完成：${result.logSummary} bytes=${payload.content.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );

      if (payload.isLastChunk) {
        _finishSyncImport(
          successMessage:
              "已同步屏蔽词（${payload.itemTotal > 0 ? payload.itemTotal : result.imported} 条）",
        );
      }
    } catch (e) {
      SyncProgressDialog.dismiss();
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveBiliAccount(RoomSyncPayload payload) async {
    try {
      final jsonBody = json.decode(payload.content);
      if (jsonBody is! Map) {
        throw const FormatException("账号数据格式不是对象");
      }
      final cookie = jsonBody['cookie']?.toString() ?? "";
      if (cookie.isEmpty) {
        throw const FormatException("账号 Cookie 为空");
      }
      BiliBiliAccountService.instance.setCookie(cookie);
      BiliBiliAccountService.instance.loadUserInfo();
      SmartDialog.showToast('已同步哔哩哔哩账号');
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _stateSubscription?.cancel();
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
