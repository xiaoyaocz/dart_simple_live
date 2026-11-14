import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/bulk_data_import_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/douyu_account_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/services/kuaishou_account_service.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';

class ProfileBackupService extends GetxService {
  static ProfileBackupService get instance => Get.find<ProfileBackupService>();

  static const schema = "simple_live_profile";
  static const schemaVersion = 4;
  static const Set<int> _supportedSchemaVersions = {2, 3, 4};

  static const Set<String> _excludedSettings = {
    LocalStorageService.kFirstRun,
    LocalStorageService.kWebDAVUri,
    LocalStorageService.kWebDAVUser,
    LocalStorageService.kWebDAVPassword,
    LocalStorageService.kWebDAVLastUploadTime,
    LocalStorageService.kWebDAVLastRecoverTime,
    // 斗鱼匿名设备号是本设备身份，不随配置包/备份/恢复迁移：
    // 每台设备保持独立 did，避免多设备共用同一"设备"触发风控
    LocalStorageService.kDouyuDeviceId,
  };

  /// 只随本机、绝不随任何备份/同步通道迁移的键。
  /// WebDAV zip 等全量 settings 通道也必须过滤这些键。
  static const Set<String> deviceLocalSettings = {
    LocalStorageService.kDouyuDeviceId,
  };

  /// 导出/上传前剔除本机专属键
  static Map<dynamic, dynamic> stripDeviceLocalSettings(
    Map<dynamic, dynamic> raw,
  ) {
    return {
      for (final entry in raw.entries)
        if (!deviceLocalSettings.contains(entry.key.toString()))
            entry.key: entry.value,
    };
  }

  Map<String, dynamic> exportProfileMap() {
    final settingsPayload = _exportSettings();
    final shieldPayload = _exportShieldValues();
    final followUsers = DBService.instance
        .getFollowList()
        .map((item) => item.toJson())
        .toList();
    final followTags = DBService.instance
        .getFollowTagList()
        .map((item) => item.toJson())
        .toList();
    final histories =
        DBService.instance.getHistores().map((item) => item.toJson()).toList();
    // 旧版订阅源已废弃，聚合逻辑不再使用本地playlist
    const iptvPlaylists = <dynamic>[];
    final iptvFavorites = IptvService.instance
        .getFavorites()
        .map((item) => item.toJson())
        .toList();
    return {
      "schema": schema,
      "schemaVersion": schemaVersion,
      "appVersion": Utils.packageInfo.version,
      "platform": Platform.operatingSystem,
      "exportedAt": DateTime.now().toIso8601String(),
      "settings": settingsPayload,
      "accounts": _exportAccounts(),
      "danmuShield": shieldPayload,
      "shieldPresets": const [],
      "followUsers": followUsers,
      "followUserTags": followTags,
      "histories": histories,
      "iptvPlaylists": iptvPlaylists,
      "iptvFavorites": iptvFavorites,
      "summary": {
        "settingCount": settingsPayload.length,
        "keywordShieldCount": (shieldPayload["keywords"] as List).length,
        "userShieldCount": 0,
        "followUserCount": followUsers.length,
        "followTagCount": followTags.length,
        "historyCount": histories.length,
        "iptvPlaylistCount": iptvPlaylists.length,
        "iptvFavoriteCount": iptvFavorites.length,
        "accountCount": (_exportAccounts()["items"] as List).length,
      },
    };
  }

  String exportProfileJson() {
    return const JsonEncoder.withIndent("  ").convert(exportProfileMap());
  }

  Future<ProfileImportSummary> importProfileJson(
    String content, {
    bool overwrite = false,
    ProfileImportOptions options = const ProfileImportOptions(),
    SyncProgressCallback? onProgress,
  }) async {
    onProgress?.call(const SyncProgress(stage: "解析配置包"));
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException("不是 Simple Live 配置包");
    }
    final payload = decoded.cast<String, dynamic>();
    if (payload["schema"] == schema) {
      final version = (payload["schemaVersion"] as num?)?.toInt() ?? 2;
      if (!_supportedSchemaVersions.contains(version)) {
        throw const FormatException("暂不支持该配置包版本");
      }
      return importProfileMap(
        payload,
        overwrite: overwrite,
        options: options,
        onProgress: onProgress,
      );
    }
    if (payload["type"] == "simple_live") {
      return importLegacyProfileMap(
        payload,
        overwrite: overwrite,
        options: options,
        onProgress: onProgress,
      );
    }
    if (_looksLikeLegacyDataFile(payload)) {
      return importLegacyDataFileMap(
        payload,
        overwrite: overwrite,
        options: options,
        onProgress: onProgress,
      );
    }
    throw const FormatException("不是 Simple Live 配置包");
  }

  Future<ProfileImportSummary> importProfileMap(
    Map<String, dynamic> payload, {
    bool overwrite = false,
    ProfileImportOptions options = const ProfileImportOptions(),
    SyncProgressCallback? onProgress,
  }) async {
    final summary = ProfileImportSummary();
    if (options.settings) {
      onProgress?.call(const SyncProgress(stage: "导入设置"));
      await _importSettings(payload["settings"], summary, overwrite);
    }
    if (options.shields) {
      await _importShields(
        payload["danmuShield"],
        summary,
        overwrite,
        onProgress,
      );
    }
    await _importAccounts(payload["accounts"]);
    if (options.follows) {
      await _importFollowUsers(
        _readPayloadList(
            payload, const ["followUsers", "follows", "favorites"]),
        summary,
        overwrite,
        onProgress,
      );
      await _importFollowTags(
        _readPayloadList(payload, const ["followUserTags", "followTags"]),
        summary,
      );
    }
    if (options.histories) {
      await _importHistories(
        _readPayloadList(payload, const ["histories", "history"]),
        summary,
        overwrite,
        onProgress,
      );
    }
    if (options.follows) {
      await _importIptv(payload, summary, overwrite);
    }

    if (options.settings || options.shields) {
      AppSettingsController.instance.onInit();
    }
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
    EventBus.instance.emit(Constant.kUpdateHistory, 0);
    return summary;
  }

  /// 导入 IPTV 订阅源与收藏，覆盖模式先清空现有数据
  Future<void> _importIptv(
    Map<String, dynamic> payload,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    final service = IptvService.instance;
    if (overwrite) {
      await service.favoriteBox.clear();
    }

    // 旧版playlist数据忽略，仅导入收藏
    final rawFavorites = payload["iptvFavorites"];
    if (rawFavorites is List) {
      for (final item in rawFavorites) {
        if (item is! Map) continue;
        final favorite = IptvFavorite.fromJson(item.cast<String, dynamic>());
        await service.favoriteBox.put(favorite.id, favorite);
        summary.iptvFavorites++;
      }
    }
  }

  Future<ProfileImportSummary> importLegacyProfileMap(
    Map<String, dynamic> payload, {
    bool overwrite = false,
    ProfileImportOptions options = const ProfileImportOptions(),
    SyncProgressCallback? onProgress,
  }) async {
    final summary = ProfileImportSummary();
    if (options.settings) {
      onProgress?.call(const SyncProgress(stage: "导入设置"));
      await _importSettings(payload["config"], summary, overwrite);
    }
    if (options.shields) {
      await _importShields(
        {"raw": _legacyShieldValues(payload["shield"])},
        summary,
        overwrite,
        onProgress,
      );
    }
    if (options.settings || options.shields) {
      AppSettingsController.instance.onInit();
    }
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
    EventBus.instance.emit(Constant.kUpdateHistory, 0);
    return summary;
  }

  Future<ProfileImportSummary> importLegacyDataFileMap(
    Map<String, dynamic> payload, {
    bool overwrite = false,
    ProfileImportOptions options = const ProfileImportOptions(),
    SyncProgressCallback? onProgress,
  }) async {
    final summary = ProfileImportSummary();
    if (payload["data"] is List) {
      await _importLegacyDataList(
        payload["data"],
        summary,
        overwrite,
        options,
        onProgress,
      );
    } else {
      if (options.follows) {
        await _importFollowUsers(
          _readPayloadList(
              payload, const ["followUsers", "follows", "favorites"]),
          summary,
          overwrite,
          onProgress,
        );
      }
      if (options.histories) {
        await _importHistories(
          _readPayloadList(payload, const ["histories", "history"]),
          summary,
          overwrite,
          onProgress,
        );
      }
    }
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
    EventBus.instance.emit(Constant.kUpdateHistory, 0);
    return summary;
  }

  bool _looksLikeLegacyDataFile(dynamic payload) {
    if (payload is! Map) {
      return false;
    }
    if (payload["data"] is List) {
      return true;
    }
    const keys = {
      "followUsers",
      "follows",
      "favorites",
      "histories",
      "history",
    };
    return keys.any((key) {
      final value = payload[key];
      return value is List || (value is Map && value["data"] is List);
    });
  }

  Map<String, dynamic> _exportSettings() {
    final result = <String, dynamic>{};
    for (final entry
        in LocalStorageService.instance.settingsBox.toMap().entries) {
      final key = entry.key.toString();
      if (_excludedSettings.contains(key)) {
        continue;
      }
      result[key] = _safeJsonValue(entry.value);
    }
    return result;
  }

  Map<String, dynamic> _exportAccounts() {
    return {
      "items": [
        {
          "siteId": Constant.kBiliBili,
          "cookie": LocalStorageService.instance.getValue(
            LocalStorageService.kBilibiliCookie,
            "",
          ),
        },
        {
          "siteId": Constant.kDouyu,
          "cookie": LocalStorageService.instance.getValue(
            LocalStorageService.kDouyuCookie,
            "",
          ),
        },
        {
          "siteId": Constant.kDouyin,
          "cookie": LocalStorageService.instance.getValue(
            LocalStorageService.kDouyinCookie,
            "",
          ),
        },
        {
          "siteId": Constant.kKuaishou,
          "cookie": LocalStorageService.instance.getValue(
            LocalStorageService.kKuaishouCookie,
            "",
          ),
          "kww": LocalStorageService.instance.getValue(
            LocalStorageService.kKuaishouKww,
            "",
          ),
          "cookieExpiresAt": LocalStorageService.instance.getValue(
            LocalStorageService.kKuaishouCookieExpiresAt,
            0,
          ),
        },
      ],
    };
  }

  Map<String, dynamic> _exportShieldValues() {
    final keywords = AppSettingsController.instance.shieldList.toList()..sort();
    final raw = LocalStorageService.instance.shieldBox.values
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    return {
      "raw": raw,
      "keywords": keywords,
      "users": const [],
      "userGroups": const <String, List<String>>{},
    };
  }

  Future<void> _importSettings(
    dynamic rawSettings,
    ProfileImportSummary summary,
    bool overwrite,
  ) async {
    if (rawSettings is! Map) {
      return;
    }
    if (overwrite) {
      await _clearImportableSettings();
    }
    final values = <dynamic, dynamic>{};
    for (final entry in rawSettings.entries) {
      final key = entry.key.toString();
      if (_excludedSettings.contains(key)) {
        continue;
      }
      values[key] = entry.value;
    }
    await LocalStorageService.instance.settingsBox.putAll(values);
    summary.settings = values.length;
  }

  Future<void> _clearImportableSettings() async {
    final keys = LocalStorageService.instance.settingsBox.keys
        .where((key) => !_excludedSettings.contains(key.toString()))
        .toList();
    if (keys.isNotEmpty) {
      await LocalStorageService.instance.settingsBox.deleteAll(keys);
    }
  }

  Future<void> _importShields(
    dynamic rawShield,
    ProfileImportSummary summary,
    bool overwrite,
    SyncProgressCallback? onProgress,
  ) async {
    if (rawShield is! Map) {
      return;
    }
    final rawValues = rawShield["raw"];
    final keywords = rawShield["keywords"];
    final values = <String>[
      if (rawValues is List) ...rawValues.map((e) => e.toString()),
      if (keywords is List) ...keywords.map((e) => e.toString()),
    ];
    if (values.isEmpty) {
      return;
    }
    final result = await BulkDataImportService.importShieldValues(
      values,
      overwrite: overwrite,
      onProgress: onProgress,
    );
    summary.shields += result.imported;
    summary.skipped += result.skipped;
  }

  Future<void> _importAccounts(dynamic rawAccounts) async {
    if (rawAccounts is! Map) {
      return;
    }
    final items = rawAccounts["items"];
    if (items is! List) {
      return;
    }
    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final siteId = item["siteId"]?.toString() ?? "";
      final cookie = item["cookie"]?.toString() ?? "";
      switch (siteId) {
        case Constant.kBiliBili:
          BiliBiliAccountService.instance.setCookie(cookie);
          break;
        case Constant.kDouyin:
          if (cookie.isEmpty) {
            DouyinAccountService.instance.clearCookie();
          } else {
            DouyinAccountService.instance.setCookie(cookie);
          }
          break;
        case Constant.kDouyu:
          if (cookie.isEmpty) {
            DouyuAccountService.instance.clearCookie();
          } else {
            DouyuAccountService.instance.setCookie(cookie);
          }
          break;
        case Constant.kKuaishou:
          final kww = item["kww"]?.toString() ?? "";
          final expiresAtMs = (item["cookieExpiresAt"] as num?)?.toInt() ?? 0;
          if (cookie.isEmpty) {
            KuaishouAccountService.instance.clearCookie();
          } else {
            KuaishouAccountService.instance.setCookie(
              cookie,
              kww: kww.isEmpty ? null : kww,
              expiresAt: expiresAtMs > 0
                  ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
                  : null,
            );
          }
          break;
      }
    }
  }

  Future<void> _importFollowUsers(
    dynamic rawUsers,
    ProfileImportSummary summary,
    bool overwrite,
    SyncProgressCallback? onProgress,
  ) async {
    final result = await BulkDataImportService.importFollowUsers(
      rawUsers,
      overwrite: overwrite,
      onProgress: onProgress,
    );
    summary.followUsers += result.imported;
    summary.skipped += result.skipped;
  }

  /// 导入自定义标签（与手机端配置包兼容）；成员关系以 FollowUser.tag 冗余字段重建
  Future<void> _importFollowTags(
    dynamic rawTags,
    ProfileImportSummary summary,
  ) async {
    if (rawTags is! List || rawTags.isEmpty) {
      return;
    }
    int imported = 0;
    for (final item in rawTags) {
      if (item is! Map) {
        continue;
      }
      final tagName = item["tag"]?.toString().trim() ?? "";
      if (tagName.isEmpty ||
          tagName == FollowUserService.allTagName ||
          tagName.length > DBService.followTagMaxLength) {
        continue;
      }
      if (DBService.instance.getFollowTagExistByTag(tagName)) {
        continue;
      }
      final tag = await DBService.instance.addFollowTag(tagName);
      if (tag == null) {
        continue;
      }
      imported++;
    }
    // 依据关注数据补全每个标签的成员列表
    final follows = DBService.instance.getFollowList();
    for (final tag in DBService.instance.getFollowTagList()) {
      final memberIds = follows
          .where((e) => e.tag.trim() == tag.tag)
          .map((e) => e.id)
          .toSet();
      bool changed = false;
      for (final id in memberIds) {
        if (!tag.userId.contains(id)) {
          tag.userId.add(id);
          changed = true;
        }
      }
      if (changed) {
        await DBService.instance.updateFollowTag(tag);
      }
    }
    summary.followTags += imported;
  }

  Future<void> _importHistories(
    dynamic rawHistories,
    ProfileImportSummary summary,
    bool overwrite,
    SyncProgressCallback? onProgress,
  ) async {
    final result = await BulkDataImportService.importHistories(
      rawHistories,
      overwrite: overwrite,
      onProgress: onProgress,
    );
    summary.histories += result.imported;
    summary.skipped += result.skipped;
  }

  dynamic _readPayloadList(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is List) {
        return value;
      }
      if (value is Map && value["data"] is List) {
        return value["data"];
      }
    }
    return null;
  }

  Future<void> _importLegacyDataList(
    dynamic rawList,
    ProfileImportSummary summary,
    bool overwrite,
    ProfileImportOptions options,
    SyncProgressCallback? onProgress,
  ) async {
    if (rawList is! List || rawList.isEmpty) {
      return;
    }
    Map? firstMap;
    for (final item in rawList) {
      if (item is Map) {
        firstMap = item;
        break;
      }
    }
    if (firstMap != null) {
      if (firstMap.containsKey("updateTime")) {
        if (options.histories) {
          await _importHistories(rawList, summary, overwrite, onProgress);
        }
        return;
      }
      if (firstMap.containsKey("roomId") || firstMap.containsKey("siteId")) {
        if (options.follows) {
          await _importFollowUsers(rawList, summary, overwrite, onProgress);
        }
        return;
      }
    }
    if (options.shields && rawList.every((item) => item is String)) {
      await _importShields({"raw": rawList}, summary, overwrite, onProgress);
    }
  }

  List<String> _legacyShieldValues(dynamic rawShield) {
    if (rawShield is! Map) {
      return const [];
    }
    return rawShield.values
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  dynamic _safeJsonValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Iterable) {
      return value.map(_safeJsonValue).toList();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _safeJsonValue(entry.value),
      };
    }
    return value.toString();
  }
}

class ProfileImportOptions {
  final bool settings;
  final bool shields;
  final bool follows;
  final bool histories;

  const ProfileImportOptions({
    this.settings = true,
    this.shields = true,
    this.follows = true,
    this.histories = true,
  });
}

class ProfileImportSummary {
  int settings = 0;
  int shields = 0;
  int followUsers = 0;
  int followTags = 0;
  int histories = 0;
  int iptvPlaylists = 0;
  int iptvFavorites = 0;
  int skipped = 0;

  String get message {
    final base =
        "设置 $settings 项，屏蔽 $shields 项，关注 $followUsers 个，标签 $followTags 个，历史 $histories 条，IPTV 源 $iptvPlaylists 个，IPTV 收藏 $iptvFavorites 个";
    return skipped > 0 ? "$base，跳过异常 $skipped 条" : base;
  }
}
