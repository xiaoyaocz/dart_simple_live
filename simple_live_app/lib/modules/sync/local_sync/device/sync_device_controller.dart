import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';

class SyncDeviceController extends BaseController {
  final SyncClinet client;
  final SyncClientInfoModel info;
  final SyncClientRequest request;
  SyncDeviceController({
    required this.client,
    required this.info,
    SyncClientRequest? request,
  }) : request = request ?? SyncClientRequest();

  final RxString lastSyncStatus = ''.obs;
  final RxBool lastSyncError = false.obs;
  bool _busy = false;

  Future<void> _runSync(
    String loadingMsg,
    Future<String> Function() action,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      SmartDialog.showLoading(msg: loadingMsg);
      final msg = await action();
      await SmartDialog.dismiss(status: SmartStatus.loading);
      lastSyncError.value = false;
      lastSyncStatus.value = msg;
      SmartDialog.showToast(msg);
    } catch (e) {
      await SmartDialog.dismiss(status: SmartStatus.loading);
      final msg = '同步失败：$e';
      lastSyncError.value = true;
      lastSyncStatus.value = msg;
      SmartDialog.showToast(msg);
      Log.logPrint(e);
    } finally {
      _busy = false;
    }
  }

  void syncFollowAndTag() => _runSync('正在发送关注和标签...', () async {
        var users = DBService.instance.getFollowList();
        var tags = DBService.instance.getFollowTagList();
        if (users.isEmpty && tags.isEmpty) {
          return '本机关注列表为空（如需从对方获取，请点击下方“从对方拉取”）';
        }
        var data = json.encode(users.map((e) => e.toJson()).toList());
        var dataT = json.encode(tags.map((e) => e.toJson()).toList());
        final followResp = await request.syncFollow(client, data);
        await request.syncTag(client, dataT);
        final added = followResp['added'];
        final updated = followResp['updated'];
        if (added is int && updated is int) {
          return '已发送 ${users.length} 个关注、${tags.length} 个标签到 ${info.name}（对方新增 $added、更新 $updated）';
        }
        return '已发送 ${users.length} 个关注、${tags.length} 个标签到 ${info.name}';
      });

  void syncHistory() => _runSync('正在发送观看记录...', () async {
        var histores = DBService.instance.getHistores();
        if (histores.isEmpty) {
          return '本机观看记录为空';
        }
        var data = json.encode(histores.map((e) => e.toJson()).toList());
        final resp = await request.syncHistory(client, data);
        final added = resp['added'];
        if (added is int) {
          return '已发送 ${histores.length} 条观看记录到 ${info.name}（对方新增 $added）';
        }
        return '已发送 ${histores.length} 条观看记录到 ${info.name}';
      });

  void syncBlockedWord() => _runSync('正在发送弹幕屏蔽...', () async {
        final settings = AppSettingsController.instance;
        final words = settings.shieldList.toList();
        final users = settings.shieldUserList.toList();
        if (words.isEmpty && users.isEmpty) {
          return '本机弹幕屏蔽规则为空';
        }
        // 旧版接收端仅支持 List；没有屏蔽用户时发送纯数组保持最大兼容。
        final payload = users.isEmpty
            ? json.encode(words)
            : json.encode({'words': words, 'users': users});
        try {
          await request.syncBlockedWord(client, payload);
        } catch (_) {
          if (users.isNotEmpty) {
            await request.syncBlockedWord(client, json.encode(words));
          } else {
            rethrow;
          }
        }
        return '已发送 ${words.length} 条屏蔽词${users.isNotEmpty ? '、${users.length} 个屏蔽用户' : ''}到 ${info.name}';
      });

  void syncBiliAccount() => _runSync('正在发送哔哩哔哩账号...', () async {
        if (!BiliBiliAccountService.instance.logined.value ||
            BiliBiliAccountService.instance.cookie.isEmpty) {
          throw '本机未登录哔哩哔哩';
        }
        await request.syncBiliAccount(
          client,
          BiliBiliAccountService.instance.cookie,
        );
        return '已发送哔哩哔哩账号到 ${info.name}';
      });

  void pullFollowAndTag() => _runSync('正在从 ${info.name} 拉取关注和标签...', () async {
        final rawUsers = await request.fetchFollow(client);
        final rawTags = await request.fetchTag(client);
        final db = DBService.instance;
        var added = 0;
        var updated = 0;
        for (final item in rawUsers) {
          final user =
              FollowUser.fromJson(Map<String, dynamic>.from(item as Map));
          final existing = db.followBox.get(user.id);
          if (existing == null) {
            await db.followBox.put(user.id, user);
            added++;
          } else {
            var changed = false;
            if (user.userName.isNotEmpty &&
                existing.userName != user.userName) {
              existing.userName = user.userName;
              changed = true;
            }
            if (user.face.isNotEmpty && existing.face != user.face) {
              existing.face = user.face;
              changed = true;
            }
            if (existing.tag == "全部" &&
                user.tag.isNotEmpty &&
                user.tag != "全部") {
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
              await db.followBox.put(user.id, existing);
              updated++;
            }
          }
        }
        final tags = rawTags
            .map((e) =>
                FollowUserTag.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        await db.normalizeFollowTags();
        await db.runFollowTagMutation(() async {
          for (final tag in tags) {
            final localTag = db.tagBox.get(tag.id);
            if (localTag == null) {
              await db.tagBox.put(tag.id, tag);
            } else {
              final userIds = {...localTag.userId, ...tag.userId}.toList();
              if (userIds.length != localTag.userId.length) {
                await db.tagBox.put(tag.id, localTag.copyWith(userId: userIds));
              }
            }
          }
        });
        await db.normalizeFollowTags();
        if (added > 0 || updated > 0 || tags.isNotEmpty) {
          WebDavAutoSyncService.notifyLocalMutation();
        }
        EventBus.instance.emit(Constant.kUpdateFollow, 0);
        return '已从 ${info.name} 拉取关注（共 ${rawUsers.length} 个，新增 $added、更新 $updated，标签 ${tags.length} 个）';
      });

  void pullHistory() => _runSync('正在从 ${info.name} 拉取观看记录...', () async {
        final rawList = await request.fetchHistory(client);
        final db = DBService.instance;
        var added = 0;
        var updated = 0;
        for (final item in rawList) {
          final history =
              History.fromJson(Map<String, dynamic>.from(item as Map));
          final existing = db.historyBox.get(history.id);
          if (existing == null) {
            await db.addOrUpdateHistory(history);
            added++;
          } else if (history.updateTime.isAfter(existing.updateTime)) {
            await db.addOrUpdateHistory(history);
            updated++;
          }
        }
        EventBus.instance.emit(Constant.kUpdateHistory, 0);
        return '已从 ${info.name} 拉取观看记录（共 ${rawList.length} 条，新增 $added、更新 $updated）';
      });

  void pullBlockedWord() => _runSync('正在从 ${info.name} 拉取弹幕屏蔽...', () async {
        final resp = await request.fetchBlockedWord(client);
        final settings = AppSettingsController.instance;
        var addedWords = 0;
        var addedUsers = 0;
        final words = resp['data'];
        if (words is List) {
          for (final w in words) {
            final text = w.toString().trim();
            if (text.isNotEmpty && !settings.shieldList.contains(text)) {
              settings.addShieldList(text);
              addedWords++;
            }
          }
        }
        final users = resp['users'];
        if (users is List) {
          for (final u in users) {
            final text = u.toString().trim();
            if (text.isNotEmpty && !settings.shieldUserList.contains(text)) {
              settings.addShieldUser(text);
              addedUsers++;
            }
          }
        }
        return '已从 ${info.name} 拉取弹幕屏蔽（新增词 $addedWords、屏蔽用户 $addedUsers）';
      });

  void pullBiliAccount() => _runSync('正在从 ${info.name} 拉取哔哩哔哩账号...', () async {
        final cookie = await request.fetchBiliAccount(client);
        if (cookie.isEmpty) {
          return '${info.name} 未登录哔哩哔哩';
        }
        if (BiliBiliAccountService.instance.cookie == cookie) {
          return '本机哔哩哔哩账号已是最新';
        }
        BiliBiliAccountService.instance.setCookie(cookie);
        BiliBiliAccountService.instance.loadUserInfo();
        return '已从 ${info.name} 拉取哔哩哔哩账号';
      });
}
