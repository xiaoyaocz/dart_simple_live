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
import 'package:simple_live_app/services/webdav_account_sync.dart';
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

  void _showLoading(String msg) {
    try {
      SmartDialog.showLoading(msg: msg);
    } catch (_) {}
  }

  Future<void> _dismissLoading() async {
    try {
      await SmartDialog.dismiss(status: SmartStatus.loading);
    } catch (_) {}
  }

  void _showToast(String msg) {
    try {
      SmartDialog.showToast(msg);
    } catch (_) {}
  }

  bool _isUnsupportedEndpointError(Object error) =>
      error.toString().contains('对端版本不支持该操作');

  Future<void> _runSync(
    String loadingMsg,
    Future<String> Function() action,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      _showLoading(loadingMsg);
      final msg = await action();
      await _dismissLoading();
      lastSyncError.value = false;
      lastSyncStatus.value = msg;
      _showToast(msg);
    } catch (e) {
      await _dismissLoading();
      final msg = '同步失败：$e';
      lastSyncError.value = true;
      lastSyncStatus.value = msg;
      _showToast(msg);
      Log.logPrint(e);
    } finally {
      _busy = false;
    }
  }

  Future<String?> _sendFollowAndTag({bool detailed = true}) async {
    var users = DBService.instance.getFollowList();
    var tags = DBService.instance.getFollowTagList();
    if (users.isEmpty && tags.isEmpty) {
      return null;
    }
    var data = json.encode(users.map((e) => e.toJson()).toList());
    var dataT = json.encode(tags.map((e) => e.toJson()).toList());
    final followResp = await request.syncFollow(client, data);
    await request.syncTag(client, dataT);
    if (!detailed) {
      return '关注 ${users.length}/标签 ${tags.length}';
    }
    final added = followResp['added'];
    final updated = followResp['updated'];
    if (added is int && updated is int) {
      return '已发送 ${users.length} 个关注、${tags.length} 个标签到 ${info.name}（对方新增 $added、更新 $updated）';
    }
    return '已发送 ${users.length} 个关注、${tags.length} 个标签到 ${info.name}';
  }

  Future<String?> _sendHistory({bool detailed = true}) async {
    var histores = DBService.instance.getHistores();
    if (histores.isEmpty) {
      return null;
    }
    var data = json.encode(histores.map((e) => e.toJson()).toList());
    final resp = await request.syncHistory(client, data);
    if (!detailed) {
      return '观看记录 ${histores.length}';
    }
    final added = resp['added'];
    if (added is int) {
      return '已发送 ${histores.length} 条观看记录到 ${info.name}（对方新增 $added）';
    }
    return '已发送 ${histores.length} 条观看记录到 ${info.name}';
  }

  Future<String?> _sendBlockedWord({bool detailed = true}) async {
    final settings = AppSettingsController.instance;
    final words = settings.shieldList.toList();
    final users = settings.shieldUserList.toList();
    if (words.isEmpty && users.isEmpty) {
      return null;
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
    if (!detailed) {
      return '屏蔽规则 ${words.length + users.length}';
    }
    return '已发送 ${words.length} 条屏蔽词${users.isNotEmpty ? '、${users.length} 个屏蔽用户' : ''}到 ${info.name}';
  }

  Future<String?> _sendBiliAccount({bool throwIfMissing = false}) async {
    final loggedIn = Get.isRegistered<BiliBiliAccountService>() &&
        BiliBiliAccountService.instance.logined.value &&
        BiliBiliAccountService.instance.cookie.isNotEmpty;
    if (!loggedIn) {
      if (throwIfMissing) throw '本机未登录哔哩哔哩';
      return null;
    }
    await request.syncBiliAccount(
      client,
      BiliBiliAccountService.instance.cookie,
    );
    return 'B站账号';
  }

  Future<String?> _sendWebDavAccount() async {
    final payload = WebDavAccountSync.readLocal();
    if (payload == null) return null;
    await request.syncWebDavAccount(client, payload.toJson());
    return 'WebDAV 账号';
  }

  Future<String> _pullFollowAndTag({bool detailed = true}) async {
    final rawUsers = await request.fetchFollow(client);
    final rawTags = await request.fetchTag(client);
    final db = DBService.instance;
    var added = 0;
    var updated = 0;
    for (final item in rawUsers) {
      final user = FollowUser.fromJson(Map<String, dynamic>.from(item as Map));
      final existing = db.followBox.get(user.id);
      if (existing == null) {
        await db.followBox.put(user.id, user);
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
        if ((existing.categoryName == null || existing.categoryName!.isEmpty) &&
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
        .map((e) => FollowUserTag.fromJson(Map<String, dynamic>.from(e as Map)))
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
    if (!detailed) {
      return '关注 ${rawUsers.length}(+$added/~$updated)/标签 ${tags.length}';
    }
    return '已从 ${info.name} 拉取关注（共 ${rawUsers.length} 个，新增 $added、更新 $updated，标签 ${tags.length} 个）';
  }

  Future<String> _pullHistory({bool detailed = true}) async {
    final rawList = await request.fetchHistory(client);
    final db = DBService.instance;
    var added = 0;
    var updated = 0;
    for (final item in rawList) {
      final history = History.fromJson(Map<String, dynamic>.from(item as Map));
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
    if (!detailed) {
      return '观看记录 ${rawList.length}(+$added/~$updated)';
    }
    return '已从 ${info.name} 拉取观看记录（共 ${rawList.length} 条，新增 $added、更新 $updated）';
  }

  Future<String> _pullBlockedWord({bool detailed = true}) async {
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
    if (!detailed) {
      return '屏蔽(+$addedWords词/+$addedUsers人)';
    }
    return '已从 ${info.name} 拉取弹幕屏蔽（新增词 $addedWords、屏蔽用户 $addedUsers）';
  }

  Future<String?> _pullBiliAccount() async {
    if (!Get.isRegistered<BiliBiliAccountService>()) return null;
    final cookie = await request.fetchBiliAccount(client);
    if (cookie.isEmpty) {
      return null;
    }
    if (BiliBiliAccountService.instance.cookie == cookie) {
      return 'B站账号(已最新)';
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    BiliBiliAccountService.instance.loadUserInfo();
    return 'B站账号';
  }

  Future<String?> _pullWebDavAccount() async {
    final raw = await request.fetchWebDavAccount(client);
    final payload = WebDavAccountPayload.fromJson(raw);
    if (payload == null) return null;
    final updated = await WebDavAccountSync.applyLocal(payload);
    return updated ? 'WebDAV 账号' : 'WebDAV 账号(已最新)';
  }

  Future<void> syncAll() => _runSync('正在一键发送全部数据...', () async {
        final sent = <String>[];
        final followSummary = await _sendFollowAndTag(detailed: false);
        if (followSummary != null) sent.add(followSummary);

        final historySummary = await _sendHistory(detailed: false);
        if (historySummary != null) sent.add(historySummary);

        final shieldSummary = await _sendBlockedWord(detailed: false);
        if (shieldSummary != null) sent.add(shieldSummary);

        final biliSummary = await _sendBiliAccount();
        if (biliSummary != null) sent.add(biliSummary);

        try {
          final webdavSummary = await _sendWebDavAccount();
          if (webdavSummary != null) sent.add(webdavSummary);
        } catch (e) {
          if (!_isUnsupportedEndpointError(e)) rethrow;
          sent.add('WebDAV(对端版本过旧未同步)');
        }

        if (sent.isEmpty) {
          return '本机暂无可发送的数据';
        }
        return '已一键发送到 ${info.name}：${sent.join('、')}';
      });

  Future<void> pullAll() => _runSync('正在从 ${info.name} 一键拉取全部数据...', () async {
        final pulled = <String>[
          await _pullFollowAndTag(detailed: false),
          await _pullHistory(detailed: false),
          await _pullBlockedWord(detailed: false),
        ];

        final biliSummary = await _pullBiliAccount();
        if (biliSummary != null) pulled.add(biliSummary);

        try {
          final webdavSummary = await _pullWebDavAccount();
          if (webdavSummary != null) pulled.add(webdavSummary);
        } catch (e) {
          if (!_isUnsupportedEndpointError(e)) rethrow;
          pulled.add('WebDAV(对端版本过旧未同步)');
        }

        return '已从 ${info.name} 一键拉取：${pulled.join('、')}';
      });

  Future<void> syncFollowAndTag() => _runSync('正在发送关注和标签...', () async {
        return await _sendFollowAndTag() ??
            '本机关注列表为空（如需从对方获取，请点击下方“一键拉取全部数据”）';
      });

  Future<void> syncHistory() => _runSync('正在发送观看记录...', () async {
        return await _sendHistory() ?? '本机观看记录为空';
      });

  Future<void> syncBlockedWord() => _runSync('正在发送弹幕屏蔽...', () async {
        return await _sendBlockedWord() ?? '本机弹幕屏蔽规则为空';
      });

  Future<void> syncBiliAccount() => _runSync('正在发送哔哩哔哩账号...', () async {
        await _sendBiliAccount(throwIfMissing: true);
        return '已发送哔哩哔哩账号到 ${info.name}';
      });

  Future<void> syncWebDavAccount() => _runSync('正在发送 WebDAV 账号...', () async {
        final summary = await _sendWebDavAccount();
        if (summary == null) {
          throw '本机未配置 WebDAV 账号';
        }
        return '已发送 WebDAV 账号到 ${info.name}';
      });

  Future<void> pullFollowAndTag() =>
      _runSync('正在从 ${info.name} 拉取关注和标签...', () => _pullFollowAndTag());

  Future<void> pullHistory() =>
      _runSync('正在从 ${info.name} 拉取观看记录...', () => _pullHistory());

  Future<void> pullBlockedWord() =>
      _runSync('正在从 ${info.name} 拉取弹幕屏蔽...', () => _pullBlockedWord());

  Future<void> pullBiliAccount() => _runSync('正在从 ${info.name} 拉取哔哩哔哩账号...', () async {
        final result = await _pullBiliAccount();
        if (result == null) return '${info.name} 未登录哔哩哔哩';
        if (result.contains('已最新')) return '本机哔哩哔哩账号已是最新';
        return '已从 ${info.name} 拉取哔哩哔哩账号';
      });

  Future<void> pullWebDavAccount() =>
      _runSync('正在从 ${info.name} 拉取 WebDAV 账号...', () async {
        final result = await _pullWebDavAccount();
        if (result == null) return '${info.name} 未配置 WebDAV 账号';
        if (result.contains('已最新')) return '本机 WebDAV 账号已是最新';
        return '已从 ${info.name} 拉取 WebDAV 账号';
      });
}
