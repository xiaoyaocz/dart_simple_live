import 'dart:async';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/services/db_service.dart';

enum BulkDataScale {
  normal,
  medium,
  large,
  huge,
}

class BulkDataPolicy {
  final int count;
  final BulkDataScale scale;
  final int dbBatchSize;
  final int yieldEvery;

  const BulkDataPolicy({
    required this.count,
    required this.scale,
    required this.dbBatchSize,
    required this.yieldEvery,
  });

  bool get shouldYield => yieldEvery > 0;

  String get label {
    switch (scale) {
      case BulkDataScale.normal:
        return "normal";
      case BulkDataScale.medium:
        return "medium";
      case BulkDataScale.large:
        return "large";
      case BulkDataScale.huge:
        return "huge";
    }
  }
}

class BulkImportResult {
  final int total;
  final int imported;
  final int skipped;
  final BulkDataPolicy policy;

  const BulkImportResult({
    required this.total,
    required this.imported,
    required this.skipped,
    required this.policy,
  });

  String get logSummary =>
      "total=$total imported=$imported skipped=$skipped scale=${policy.label}";
}

class BulkDataImportService {
  static const int mediumThreshold = 300;
  static const int largeThreshold = 1000;
  static const int hugeThreshold = 3000;

  static BulkDataPolicy policyForCount(int count) {
    if (count > hugeThreshold) {
      return BulkDataPolicy(
        count: count,
        scale: BulkDataScale.huge,
        dbBatchSize: 200,
        yieldEvery: 100,
      );
    }
    if (count > largeThreshold) {
      return BulkDataPolicy(
        count: count,
        scale: BulkDataScale.large,
        dbBatchSize: 400,
        yieldEvery: 200,
      );
    }
    if (count > mediumThreshold) {
      return BulkDataPolicy(
        count: count,
        scale: BulkDataScale.medium,
        dbBatchSize: 800,
        yieldEvery: 300,
      );
    }
    return BulkDataPolicy(
      count: count,
      scale: BulkDataScale.normal,
      dbBatchSize: 1200,
      yieldEvery: 0,
    );
  }

  static Future<void> yieldIfNeeded(
    BulkDataPolicy policy,
    int processed,
  ) async {
    if (!policy.shouldYield || processed <= 0) {
      return;
    }
    if (processed % policy.yieldEvery == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  static Future<BulkImportResult> importFollowUsers(
    dynamic rawUsers, {
    bool overwrite = false,
    SyncProgressCallback? onProgress,
  }) async {
    if (rawUsers is! List) {
      final policy = policyForCount(0);
      return BulkImportResult(
        total: 0,
        imported: 0,
        skipped: 0,
        policy: policy,
      );
    }
    final policy = policyForCount(rawUsers.length);
    onProgress?.call(SyncProgress(
      stage: "导入关注",
      current: 0,
      total: rawUsers.length,
      message: "正在解析关注 0/${rawUsers.length}",
    ));
    final users = <FollowUser>[];
    var skipped = 0;
    var processed = 0;
    for (final item in rawUsers) {
      processed++;
      if (item is! Map) {
        skipped++;
        await yieldIfNeeded(policy, processed);
        continue;
      }
      try {
        final user = FollowUser.fromJson(Map<String, dynamic>.from(item));
        if (user.id.isEmpty || user.roomId.isEmpty || user.siteId.isEmpty) {
          skipped++;
        } else {
          users.add(user);
        }
      } catch (e) {
        skipped++;
        Log.d("跳过异常关注项: $e");
      }
      await yieldIfNeeded(policy, processed);
      _notifyProgress(
        onProgress,
        stage: "导入关注",
        current: processed,
        total: rawUsers.length,
        verb: "解析",
      );
    }
    if (overwrite) {
      await DBService.instance.followBox.clear();
    }
    await _putFollows(users, policy, onProgress: onProgress);
    final result = BulkImportResult(
      total: rawUsers.length,
      imported: users.length,
      skipped: skipped,
      policy: policy,
    );
    Log.i("批量导入关注完成：${result.logSummary}");
    return result;
  }

  static Future<BulkImportResult> importHistories(
    dynamic rawHistories, {
    bool overwrite = false,
    SyncProgressCallback? onProgress,
  }) async {
    if (rawHistories is! List) {
      final policy = policyForCount(0);
      return BulkImportResult(
        total: 0,
        imported: 0,
        skipped: 0,
        policy: policy,
      );
    }
    final policy = policyForCount(rawHistories.length);
    onProgress?.call(SyncProgress(
      stage: "导入历史",
      current: 0,
      total: rawHistories.length,
      message: "正在整理历史 0/${rawHistories.length}",
    ));
    if (overwrite) {
      await DBService.instance.historyBox.clear();
    }
    final existing = overwrite
        ? <String, History>{}
        : {
            for (final entry in DBService.instance.historyBox.toMap().entries)
              entry.key.toString(): entry.value,
          };
    final pending = <String, History>{};
    var skipped = 0;
    var imported = 0;
    var processed = 0;
    for (final item in rawHistories) {
      processed++;
      if (item is! Map) {
        skipped++;
        await yieldIfNeeded(policy, processed);
        continue;
      }
      try {
        final history = History.fromJson(Map<String, dynamic>.from(item));
        if (history.id.isEmpty ||
            history.roomId.isEmpty ||
            history.siteId.isEmpty) {
          skipped++;
          await yieldIfNeeded(policy, processed);
          continue;
        }
        final old = existing[history.id];
        if (!overwrite &&
            old != null &&
            old.updateTime.isAfter(history.updateTime)) {
          await yieldIfNeeded(policy, processed);
          continue;
        }
        existing[history.id] = history;
        pending[history.id] = history;
        imported++;
      } catch (e) {
        skipped++;
        Log.d("跳过异常历史项: $e");
      }
      await yieldIfNeeded(policy, processed);
      _notifyProgress(
        onProgress,
        stage: "导入历史",
        current: processed,
        total: rawHistories.length,
        verb: "整理",
      );
    }
    await _putHistories(pending.values, policy, onProgress: onProgress);
    final result = BulkImportResult(
      total: rawHistories.length,
      imported: imported,
      skipped: skipped,
      policy: policy,
    );
    Log.i("批量导入历史完成：${result.logSummary}");
    return result;
  }

  static Future<BulkImportResult> importShieldValues(
    dynamic rawValues, {
    bool overwrite = false,
    SyncProgressCallback? onProgress,
  }) async {
    if (rawValues is! List) {
      final policy = policyForCount(0);
      return BulkImportResult(
        total: 0,
        imported: 0,
        skipped: 0,
        policy: policy,
      );
    }
    final policy = policyForCount(rawValues.length);
    onProgress?.call(SyncProgress(
      stage: "导入屏蔽词",
      current: 0,
      total: rawValues.length,
      message: "正在整理屏蔽词 0/${rawValues.length}",
    ));
    if (overwrite) {
      await AppSettingsController.instance.clearShieldList();
    }
    final values = <String>{};
    var skipped = 0;
    var processed = 0;
    for (final item in rawValues) {
      processed++;
      final value = item.toString().trim();
      if (value.isEmpty) {
        skipped++;
      } else {
        values.add(value);
      }
      await yieldIfNeeded(policy, processed);
      _notifyProgress(
        onProgress,
        stage: "导入屏蔽词",
        current: processed,
        total: rawValues.length,
        verb: "整理",
      );
    }
    for (final value in values) {
      AppSettingsController.instance.importShieldValue(value);
    }
    _notifyProgress(
      onProgress,
      stage: "写入屏蔽词",
      current: values.length,
      total: values.length,
      verb: "写入",
      force: true,
    );
    final result = BulkImportResult(
      total: rawValues.length,
      imported: values.length,
      skipped: skipped,
      policy: policy,
    );
    Log.i("批量导入屏蔽词完成：${result.logSummary}");
    return result;
  }

  static Future<void> _putFollows(
    Iterable<FollowUser> users,
    BulkDataPolicy policy, {
    SyncProgressCallback? onProgress,
  }) async {
    final buffer = <String, FollowUser>{};
    final total = users.length;
    var written = 0;
    for (final user in users) {
      buffer[user.id] = user;
      if (buffer.length >= policy.dbBatchSize) {
        await DBService.instance.followBox.putAll(buffer);
        written += buffer.length;
        buffer.clear();
        _notifyProgress(
          onProgress,
          stage: "写入关注",
          current: written,
          total: total,
          verb: "写入",
          force: true,
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (buffer.isNotEmpty) {
      await DBService.instance.followBox.putAll(buffer);
      written += buffer.length;
      _notifyProgress(
        onProgress,
        stage: "写入关注",
        current: written,
        total: total,
        verb: "写入",
        force: true,
      );
    }
  }

  static Future<void> _putHistories(
    Iterable<History> histories,
    BulkDataPolicy policy, {
    SyncProgressCallback? onProgress,
  }) async {
    final buffer = <String, History>{};
    final total = histories.length;
    var written = 0;
    for (final history in histories) {
      buffer[history.id] = history;
      if (buffer.length >= policy.dbBatchSize) {
        await DBService.instance.historyBox.putAll(buffer);
        written += buffer.length;
        buffer.clear();
        _notifyProgress(
          onProgress,
          stage: "写入历史",
          current: written,
          total: total,
          verb: "写入",
          force: true,
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (buffer.isNotEmpty) {
      await DBService.instance.historyBox.putAll(buffer);
      written += buffer.length;
      _notifyProgress(
        onProgress,
        stage: "写入历史",
        current: written,
        total: total,
        verb: "写入",
        force: true,
      );
    }
  }

  static void _notifyProgress(
    SyncProgressCallback? onProgress, {
    required String stage,
    required int current,
    required int total,
    required String verb,
    bool force = false,
  }) {
    if (onProgress == null || total <= 0) {
      return;
    }
    if (!force && current < total && current % 100 != 0) {
      return;
    }
    onProgress(SyncProgress(
      stage: stage,
      current: current,
      total: total,
      message: "$verb $current/$total",
    ));
  }
}
