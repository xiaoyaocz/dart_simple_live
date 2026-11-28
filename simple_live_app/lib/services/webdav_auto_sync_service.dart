import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_backup_merge.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class WebDavRecoverySummary {
  const WebDavRecoverySummary({
    required this.skippedCount,
    required this.failures,
    required this.recoverTime,
  });

  final int skippedCount;
  final List<String> failures;
  final DateTime recoverTime;

  bool get hasIssues => failures.isNotEmpty || skippedCount > 0;
}

class WebDavAutoSyncService extends GetxService {
  WebDavAutoSyncService({
    this.debounceDuration = const Duration(seconds: 5),
    this.startupDelay = const Duration(seconds: 2),
    Future<void> Function(Uint8List data)? uploadOverride,
    Future<List<int>> Function()? downloadOverride,
    Future<List<int>> Function()? buildBackupBytesOverride,
    bool Function()? hasCredentialsOverride,
    bool Function()? autoSyncEnabledOverride,
  })  : _uploadOverride = uploadOverride,
        _downloadOverride = downloadOverride,
        _buildBackupBytesOverride = buildBackupBytesOverride,
        _hasCredentialsOverride = hasCredentialsOverride,
        _autoSyncEnabledOverride = autoSyncEnabledOverride;

  static WebDavAutoSyncService get instance => Get.find<WebDavAutoSyncService>();

  static void notifyLocalMutation() {
    if (!Get.isRegistered<WebDavAutoSyncService>()) return;
    Get.find<WebDavAutoSyncService>().scheduleUpload();
  }

  static const userFollowJsonName = 'SimpleLive_follows.json';
  static const userHistoriesJsonName = 'SimpleLive_histories.json';
  static const userBlockedWordJsonName = 'SimpleLive_blocked_word.json';
  static const userBilibiliAccountJsonName = 'SimpleLive_bilibili_account.json';
  static const userSettingsJsonName = 'SimpleLive_Settings.json';
  static const userTagsJsonName = 'SimpleLive_Tags.json';

  final Duration debounceDuration;
  final Duration startupDelay;
  final Future<void> Function(Uint8List data)? _uploadOverride;
  final Future<List<int>> Function()? _downloadOverride;
  final Future<List<int>> Function()? _buildBackupBytesOverride;
  final bool Function()? _hasCredentialsOverride;
  final bool Function()? _autoSyncEnabledOverride;

  final isSyncing = false.obs;
  final lastAutoSyncStatus = ''.obs;

  Timer? _debounceTimer;
  Timer? _startupTimer;
  bool _pendingUploadAfterSync = false;
  int _suppressMutationDepth = 0;
  bool _closed = false;

  bool get hasCredentials {
    if (_hasCredentialsOverride != null) return _hasCredentialsOverride!();
    final uri = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVUri, '');
    return uri.isNotEmpty;
  }

  bool get autoSyncEnabled {
    if (_autoSyncEnabledOverride != null) return _autoSyncEnabledOverride!();
    return AppSettingsController.instance.webDavAutoSync.value;
  }

  DAVClient _createClient() {
    final uri = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVUri, '');
    final user = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVUser, '');
    final password = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVPassword, '');
    return DAVClient(uri, user, password);
  }

  void scheduleStartupSync() {
    if (_closed || !autoSyncEnabled || !hasCredentials) return;
    _startupTimer?.cancel();
    _startupTimer = Timer(startupDelay, () {
      if (_closed || !autoSyncEnabled || !hasCredentials) return;
      unawaited(recoverSilent());
    });
  }

  void scheduleUpload() {
    if (_closed || _suppressMutationDepth > 0) return;
    if (!autoSyncEnabled || !hasCredentials) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      if (_closed || !autoSyncEnabled || !hasCredentials) return;
      if (isSyncing.value) {
        _pendingUploadAfterSync = true;
        return;
      }
      unawaited(uploadSilent());
    });
  }

  void cancelPending() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _startupTimer?.cancel();
    _startupTimer = null;
    _pendingUploadAfterSync = false;
  }

  Future<bool> uploadSilent() async {
    if (_closed || isSyncing.value || !hasCredentials) return false;
    try {
      await uploadBackup();
      lastAutoSyncStatus.value = '自动上传完成 ${Utils.parseTime(DateTime.now())}';
      return true;
    } catch (e) {
      Log.w('WebDAV 自动上传失败：$e');
      lastAutoSyncStatus.value = '自动上传失败';
      return false;
    }
  }

  Future<bool> recoverSilent() async {
    if (_closed || isSyncing.value || !hasCredentials) return false;
    try {
      final summary = await recoverBackup();
      lastAutoSyncStatus.value = summary.hasIssues
          ? '自动拉取部分完成'
          : '自动拉取完成 ${Utils.parseTime(summary.recoverTime)}';
      return !summary.hasIssues;
    } catch (e) {
      Log.w('WebDAV 自动拉取失败：$e');
      lastAutoSyncStatus.value = '自动拉取失败';
      return false;
    }
  }

  Future<DateTime> uploadBackup({DAVClient? client}) async {
    if (isSyncing.value) {
      throw StateError('同步正在进行中');
    }
    isSyncing.value = true;
    try {
      final rawBytes = _buildBackupBytesOverride != null
          ? await _buildBackupBytesOverride!()
          : await buildBackupBytes();
      final data = Uint8List.fromList(rawBytes);
      if (_uploadOverride != null) {
        await _uploadOverride!(data);
      } else {
        final target = client ?? _createClient();
        await target.backup(data);
      }
      final uploadTime = DateTime.now();
      if (_uploadOverride == null) {
        await LocalStorageService.instance.setValue(
          LocalStorageService.kWebDAVLastUploadTime,
          uploadTime.millisecondsSinceEpoch,
        );
      }
      return uploadTime;
    } finally {
      isSyncing.value = false;
      _flushPendingUpload();
    }
  }

  Future<WebDavRecoverySummary> recoverBackup({
    DAVClient? client,
    bool syncFollows = true,
    bool syncHistories = true,
    bool syncBlockWord = true,
    bool syncBilibiliAccount = true,
  }) async {
    if (isSyncing.value) {
      throw StateError('同步正在进行中');
    }
    isSyncing.value = true;
    _suppressMutationDepth++;
    try {
      final data = _downloadOverride != null
          ? await _downloadOverride!()
          : await (client ?? _createClient()).recovery();
      final archive = decodeWebDavBackup(data);
      if (syncFollows &&
          !archive.any((file) => file.name == userFollowJsonName)) {
        throw const FormatException('备份中缺少关注列表');
      }
      if (syncFollows) await _recoverFollows(archive);
      var skippedCount = 0;
      final failures = <String>[];
      for (final file in archive) {
        if (file.name == userFollowJsonName || file.name == userTagsJsonName) {
          continue;
        }
        try {
          skippedCount += await _recoverSingleFile(
            file,
            syncHistories: syncHistories,
            syncBlockWord: syncBlockWord,
            syncBilibiliAccount: syncBilibiliAccount,
          );
        } catch (e) {
          failures.add('${file.name}: $e');
          Log.e('恢复文件${file.name}失败: $e', StackTrace.current);
        }
      }
      final recoverTime = DateTime.now();
      if (failures.isEmpty && skippedCount == 0 && _downloadOverride == null) {
        await LocalStorageService.instance.setValue(
          LocalStorageService.kWebDAVLastRecoverTime,
          recoverTime.millisecondsSinceEpoch,
        );
      }
      return WebDavRecoverySummary(
        skippedCount: skippedCount,
        failures: failures,
        recoverTime: recoverTime,
      );
    } finally {
      _suppressMutationDepth--;
      isSyncing.value = false;
      _flushPendingUpload();
    }
  }

  void _flushPendingUpload() {
    if (!_pendingUploadAfterSync || _closed) return;
    _pendingUploadAfterSync = false;
    scheduleUpload();
  }

  Future<List<int>> buildBackupBytes() async {
    final archive = Archive();
    void add(String name, dynamic data) {
      final bytes = utf8.encode(jsonEncode({'data': data}));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add(userFollowJsonName,
        DBService.instance.getFollowList().map((e) => e.toJson()).toList());
    add(userTagsJsonName,
        DBService.instance.getFollowTagList().map((e) => e.toJson()).toList());
    add(userHistoriesJsonName,
        DBService.instance.getHistores().map((e) => e.toJson()).toList());
    add(userBlockedWordJsonName,
        AppSettingsController.instance.shieldList.toList());
    add(userBilibiliAccountJsonName,
        {'cookie': BiliBiliAccountService.instance.cookie});
    add(userSettingsJsonName,
        LocalStorageService.instance.settingsBox.toMap());
    return ZipEncoder().encode(archive);
  }

  Future<void> _recoverFollows(Archive incoming) async {
    final db = DBService.instance;
    await db.runFollowTagMutation(() async {
      final journal = await Hive.openBox<dynamic>('webdav_restore_journal');
      await _applyFollowRestoreJournal(journal);
      final snapshot = Archive();
      void add(String name, dynamic value) {
        final bytes = utf8.encode(jsonEncode({'data': value}));
        snapshot.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add(userFollowJsonName,
          db.getFollowList().map((e) => e.toJson()).toList());
      add(userTagsJsonName,
          db.getFollowTagList().map((e) => e.toJson()).toList());
      final followArchive = Archive();
      for (final file in incoming) {
        if (file.name == userFollowJsonName || file.name == userTagsJsonName) {
          followArchive.addFile(file);
        }
      }
      final merged = mergeWebDavBackups(snapshot, followArchive);
      List<dynamic> read(String name) =>
          jsonDecode(utf8.decode(merged.findFile(name)!.content))['data'];
      final users = read(userFollowJsonName)
          .map((row) => FollowUser.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      final tags = read(userTagsJsonName)
          .map((row) => FollowUserTag.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      final existingIds = db.followBox.values.map((e) => e.id).toSet();
      final additions =
          users.where((user) => !existingIds.contains(user.id)).toList();
      final addedIds = additions.map((user) => user.id).toSet();
      if (additions.isNotEmpty) {
        await journal.put('pending', {
          'users': additions.map((user) => user.toJson()).toList(),
          'tags': tags
              .map((tag) => tag
                  .copyWith(
                      userId: tag.userId.where(addedIds.contains).toList())
                  .toJson())
              .toList(),
        });
        await journal.flush();
        await _applyFollowRestoreJournal(journal);
      }
    });
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
  }

  Future<void> _applyFollowRestoreJournal(Box<dynamic> journal) async {
    final pending = journal.get('pending');
    if (pending == null) return;
    final db = DBService.instance;
    final users = (pending['users'] as List)
        .map((row) => FollowUser.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    final tags = (pending['tags'] as List)
        .map((row) => FollowUserTag.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    final expected = {for (final user in users) user.id: user};
    for (final user in users) {
      if (!db.followBox.containsKey(user.id)) {
        await db.followBox.put(user.id, user);
      }
    }
    final existingTags = {
      for (final key in db.tagBox.keys) db.tagBox.get(key)!.id: key,
    };
    final existingByName = {
      for (final key in db.tagBox.keys) db.tagBox.get(key)!.tag: key,
    };
    for (final tag in tags) {
      final additions = tag.userId.where((id) {
        final current = db.followBox.get(id);
        return expected.containsKey(id) && current?.tag == expected[id]!.tag;
      }).toList();
      if (additions.isEmpty) continue;
      final key = existingTags[tag.id] ?? existingByName[tag.tag];
      if (key != null) {
        final current = db.tagBox.get(key)!;
        final members = current.userId.toSet();
        final missing = additions.where(members.add).toList();
        if (missing.isNotEmpty) {
          await db.tagBox.put(
              key, current.copyWith(userId: [...current.userId, ...missing]));
        }
        if (current.tag != tag.tag) {
          await db.tagBox.flush();
          for (final id in additions) {
            final user = db.followBox.get(id)!;
            await db.followBox.put(
                id,
                FollowUser.fromJson({
                  ...user.toJson(),
                  'tag': current.tag,
                }));
          }
        }
      } else {
        await db.tagBox.put(tag.id, tag.copyWith(userId: additions));
        existingTags[tag.id] = tag.id;
        existingByName[tag.tag] = tag.id;
      }
    }
    await db.followBox.flush();
    await db.tagBox.flush();
    await journal.delete('pending');
    await journal.flush();
  }

  Future<int> _recoverSingleFile(
    ArchiveFile file, {
    required bool syncHistories,
    required bool syncBlockWord,
    required bool syncBilibiliAccount,
  }) async {
    var skippedCount = 0;
    if (!file.isFile || !file.name.endsWith('.json')) return skippedCount;
    final jsonString = utf8.decode(file.content);
    final jsonData = json.decode(jsonString)['data'];
    if (file.name == userHistoriesJsonName && syncHistories) {
      final histories = <History>[];
      for (final item in jsonData) {
        try {
          histories.add(History.fromJson(item));
        } catch (e) {
          skippedCount++;
          Log.e('解析历史记录条目失败，已跳过: $e', StackTrace.current);
        }
      }
      for (final history in histories) {
        if (!DBService.instance.historyBox.containsKey(history.id)) {
          await DBService.instance.addOrUpdateHistory(history);
        }
      }
    } else if (file.name == userBlockedWordJsonName && syncBlockWord) {
      for (final keyword in jsonData) {
        try {
          AppSettingsController.instance.addShieldList(keyword.trim());
        } catch (e) {
          skippedCount++;
          Log.e('解析屏蔽词条目失败，已跳过: $e', StackTrace.current);
        }
      }
    } else if (file.name == userBilibiliAccountJsonName &&
        syncBilibiliAccount) {
      final cookie = jsonData['cookie'];
      if (BiliBiliAccountService.instance.cookie.isEmpty &&
          cookie is String &&
          cookie.isNotEmpty) {
        BiliBiliAccountService.instance.setCookie(cookie);
        BiliBiliAccountService.instance.loadUserInfo();
      }
    } else if (file.name == userSettingsJsonName) {
      final settings = Map<String, dynamic>.from(jsonData);
      for (final entry in settings.entries) {
        if (!LocalStorageService.instance.settingsBox.containsKey(entry.key)) {
          await LocalStorageService.instance.settingsBox
              .put(entry.key, entry.value);
        }
      }
    }
    return skippedCount;
  }

  @override
  void onClose() {
    _closed = true;
    cancelPending();
    super.onClose();
  }
}
