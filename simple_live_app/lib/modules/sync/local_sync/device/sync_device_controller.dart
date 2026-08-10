import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/bulk_data_import_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/widgets/sync_progress_dialog.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SyncDeviceController extends BaseController {
  final SyncClinet client;
  final SyncClientInfoModel info;
  SyncDeviceController({required this.client, required this.info});
  SyncClientRequest request = SyncClientRequest();

  Future<void> _syncJsonChunks<T>({
    required List<T> items,
    required bool overlay,
    required String label,
    required Object? Function(T item) toJson,
    required Future<bool> Function(
      String body,
      bool overlay,
      Map<String, String> chunkParams,
    ) send,
  }) async {
    final policy = BulkDataImportService.policyForCount(items.length);
    final chunkSize = policy.scale == BulkDataScale.normal
        ? items.length
        : policy.dbBatchSize;
    final chunkTotal =
        items.isEmpty ? 1 : ((items.length - 1) ~/ chunkSize) + 1;
    Log.i("本地发送$label：count=${items.length} scale=${policy.label}");
    if (items.isEmpty) {
      SyncProgressDialog.update(SyncProgress(
        stage: "发送$label",
        current: 0,
        total: 0,
        message: "发送空列表",
      ));
      await send(json.encode(const []), overlay, const {
        "chunkIndex": "1",
        "chunkTotal": "1",
        "itemStart": "0",
        "itemEnd": "0",
        "itemTotal": "0",
      });
      return;
    }
    for (var start = 0; start < items.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, items.length).toInt();
      final chunkIndex = (start ~/ chunkSize) + 1;
      final chunk = items.sublist(start, end);
      final body = json.encode(chunk.map(toJson).toList());
      SyncProgressDialog.update(SyncProgress(
        stage: "发送$label",
        current: end,
        total: items.length,
        message: "发送第 $chunkIndex/$chunkTotal 段，$end/${items.length}",
      ));
      await send(body, overlay && start == 0, {
        "chunkIndex": chunkIndex.toString(),
        "chunkTotal": chunkTotal.toString(),
        "itemStart": start.toString(),
        "itemEnd": end.toString(),
        "itemTotal": items.length.toString(),
      });
      Log.i(
        "本地发送$label分段：${start + 1}-$end/${items.length} bytes=${body.length}",
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<bool> showOverlayDialog() async {
    var overlay = await Utils.showAlertDialog(
      "是否覆盖对方设备上的同类数据？选择“不覆盖”会合并同步。",
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  void syncFollowAndTag() async {
    try {
      var overlay = await showOverlayDialog();
      SyncProgressDialog.show(const SyncProgress(stage: "准备同步关注"));
      var users = DBService.instance.getFollowList();
      var tags = DBService.instance.getFollowTagList();
      await _syncJsonChunks(
        items: users,
        overlay: overlay,
        label: "关注",
        toJson: (item) => item.toJson(),
        send: (body, chunkOverlay, chunkParams) {
          return request.syncFollow(
            client,
            body,
            overlay: chunkOverlay,
            extraQueryParameters: chunkParams,
          );
        },
      );
      // 标签和关注必须同时同步
      await _syncJsonChunks(
        items: tags,
        overlay: overlay,
        label: "标签",
        toJson: (item) => item.toJson(),
        send: (body, chunkOverlay, chunkParams) {
          return request.syncTag(
            client,
            body,
            overlay: chunkOverlay,
            extraQueryParameters: chunkParams,
          );
        },
      );
      SmartDialog.showToast("已同步关注列表和标签");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步关注和标签失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  void syncProfile() async {
    try {
      var overlay = await showOverlayDialog();
      SyncProgressDialog.show(const SyncProgress(stage: "同步配置包"));
      await request.syncProfile(
        client,
        ProfileBackupService.instance.exportProfileJson(),
        overlay: overlay,
      );
      SmartDialog.showToast("已同步配置包");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步配置包失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  void syncHistory() async {
    try {
      var overlay = await showOverlayDialog();
      SyncProgressDialog.show(const SyncProgress(stage: "准备同步历史"));
      var histores = DBService.instance.getHistores();
      await _syncJsonChunks(
        items: histores,
        overlay: overlay,
        label: "历史",
        toJson: (item) => item.toJson(),
        send: (body, chunkOverlay, chunkParams) {
          return request.syncHistory(
            client,
            body,
            overlay: chunkOverlay,
            extraQueryParameters: chunkParams,
          );
        },
      );
      SmartDialog.showToast("已同步历史记录");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步历史记录失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  void syncBlockedWord() async {
    try {
      var overlay = await showOverlayDialog();
      SyncProgressDialog.show(const SyncProgress(stage: "准备同步屏蔽词"));
      var shieldList = AppSettingsController.instance.allShieldValues.toList();
      await _syncJsonChunks(
        items: shieldList,
        overlay: overlay,
        label: "屏蔽词",
        toJson: (item) => item,
        send: (body, chunkOverlay, chunkParams) {
          return request.syncBlockedWord(
            client,
            body,
            overlay: chunkOverlay,
            extraQueryParameters: chunkParams,
          );
        },
      );
      SmartDialog.showToast("已同步屏蔽词");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步屏蔽词失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  void syncBiliAccount() async {
    try {
      if (!BiliBiliAccountService.instance.logined.value) {
        SmartDialog.showToast("未登录哔哩哔哩");
        return;
      }
      SyncProgressDialog.show(const SyncProgress(stage: "同步哔哩哔哩账号"));

      await request.syncBiliAccount(
          client, BiliBiliAccountService.instance.cookie);
      SmartDialog.showToast("已同步哔哩哔哩账号");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步哔哩哔哩账号失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  void syncDouyinAccount() async {
    try {
      if (!DouyinAccountService.instance.hasCookie.value) {
        SmartDialog.showToast("未配置抖音 Cookie");
        return;
      }
      SyncProgressDialog.show(const SyncProgress(stage: "同步抖音账号"));

      await request.syncDouyinAccount(
          client, DouyinAccountService.instance.cookie);
      SmartDialog.showToast("已同步抖音账号");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步抖音账号失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }

  void syncKuaishouAccount() async {
    try {
      final account = KuaishouAccountService.instance;
      if (!account.hasCookie.value) {
        SmartDialog.showToast("未配置快手 Cookie");
        return;
      }
      SyncProgressDialog.show(const SyncProgress(stage: "同步快手账号"));
      await request.syncKuaishouAccount(
        client,
        account.cookie,
        account.kww,
        account.cookieExpiresAtMs.value,
      );
      SmartDialog.showToast("已同步快手账号");
    } catch (e) {
      SmartDialog.showToast("同步失败：${exceptionToString(e)}");
      Log.e("同步快手账号失败：$e", StackTrace.current);
    } finally {
      SyncProgressDialog.dismiss();
    }
  }
}
