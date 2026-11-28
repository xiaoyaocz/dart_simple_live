import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// 本地开播快照有效期（超过该时长视为过期，冷启动不直接标为直播中）。
const Duration kFollowStatusSnapshotTtl = Duration(hours: 2);

class FollowStatusSnapshotEntry {
  final int status;
  final String? showTime;
  final int? heat;
  final String? categoryName;

  const FollowStatusSnapshotEntry({
    required this.status,
    this.showTime,
    this.heat,
    this.categoryName,
  });
}

String encodeFollowStatusSnapshot(
  List<FollowUser> users, {
  required DateTime now,
}) {
  final items = <String, Map<String, dynamic>>{};
  for (final user in users) {
    final status = user.liveStatus.value;
    if (status != 1 && status != 2) continue;
    final entry = <String, dynamic>{'s': status};
    if (status == 2) {
      final startTime = user.liveStartTime?.trim();
      if (startTime != null && startTime.isNotEmpty) {
        entry['t'] = startTime;
      }
      final heat = user.heat;
      if (heat != null && heat > 0) {
        entry['h'] = heat;
      }
    }
    final category = user.categoryName?.trim();
    if (category != null && category.isNotEmpty) {
      entry['c'] = category;
    }
    items[user.id] = entry;
  }
  return jsonEncode({
    'v': 1,
    'updatedAt': now.millisecondsSinceEpoch,
    'items': items,
  });
}

Map<String, FollowStatusSnapshotEntry> decodeFollowStatusSnapshot(
  dynamic raw, {
  required DateTime now,
  Duration ttl = kFollowStatusSnapshotTtl,
}) {
  if (raw == null) return const {};
  dynamic decoded = raw;
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const {};
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return const {};
    }
  }
  if (decoded is! Map) return const {};
  final updatedAt = int.tryParse('${decoded['updatedAt'] ?? ''}');
  if (updatedAt == null || updatedAt <= 0) return const {};
  final ageMs = now.millisecondsSinceEpoch - updatedAt;
  if (ageMs > ttl.inMilliseconds) return const {};
  final rawItems = decoded['items'];
  if (rawItems is! Map) return const {};

  final result = <String, FollowStatusSnapshotEntry>{};
  for (final entry in rawItems.entries) {
    final key = entry.key?.toString() ?? '';
    final value = entry.value;
    if (key.isEmpty || value is! Map) continue;
    final status = int.tryParse('${value['s'] ?? ''}');
    if (status != 1 && status != 2) continue;
    final showTime = value['t']?.toString().trim();
    final heat = int.tryParse('${value['h'] ?? ''}');
    final category = value['c']?.toString().trim();
    result[key] = FollowStatusSnapshotEntry(
      status: status!,
      showTime: showTime != null && showTime.isNotEmpty ? showTime : null,
      heat: heat != null && heat > 0 ? heat : null,
      categoryName: category != null && category.isNotEmpty ? category : null,
    );
  }
  return result;
}

/// 按当前筛选页/标签与直播状态稳定排定刷新优先级：
/// - 若当前选中自定义标签，匹配该标签的主播整体优先；
/// - 若当前选中“未开播”(‘2’)，优先刷新未开播 -> 未知 -> 直播中；
/// - 其他视图（“全部”、“直播中”或默认）：优先刷新直播中 -> 未知 -> 未开播。
List<FollowUser> prioritizeFollowUsers(
  List<FollowUser> users, {
  FollowUserTag? activeFilter,
}) {
  if (users.length <= 1) return List<FollowUser>.from(users);

  final filterId = activeFilter?.id;
  final filterTag = activeFilter?.tag;
  final isBuiltin = activeFilter == null ||
      filterId == '0' ||
      filterId == '1' ||
      filterId == '2' ||
      filterTag == '全部' ||
      filterTag == '直播中' ||
      filterTag == '未开播';
  final prioritizeOffline = filterId == '2' || filterTag == '未开播';
  final memberIds = isBuiltin ? const <String>{} : activeFilter.userId.toSet();

  int matchBucket(FollowUser user) {
    if (isBuiltin) return 0;
    if (memberIds.contains(user.id) || user.tag == filterTag) return 0;
    return 1;
  }

  int statusBucket(FollowUser user) {
    final status = user.liveStatus.value;
    if (prioritizeOffline) {
      if (status == 1) return 0;
      if (status == 0) return 1;
      return 2;
    }
    if (status == 2) return 0;
    if (status == 0) return 1;
    return 2;
  }

  final indexed = users.asMap().entries.toList();
  indexed.sort((a, b) {
    final matchCmp = matchBucket(a.value).compareTo(matchBucket(b.value));
    if (matchCmp != 0) return matchCmp;
    final statusCmp = statusBucket(a.value).compareTo(statusBucket(b.value));
    if (statusCmp != 0) return statusCmp;
    return a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}

/// 计算单平台独立的并发工作池大小，受全局并发上限约束。
int followSiteConcurrency({
  required String siteId,
  required int globalCap,
  required bool isMobile,
}) {
  final cap = globalCap.clamp(1, 24);
  if (siteId == Constant.kDouyin) {
    return cap.clamp(1, isMobile ? 8 : 14);
  }
  if (siteId == Constant.kHuya || siteId == Constant.kDouyu) {
    return cap.clamp(1, isMobile ? 16 : 20);
  }
  return cap.clamp(1, isMobile ? 10 : 14);
}

/// 抖音关注刷新自适应限流（AIMD）：正常零等待并发，命中风控立即收紧并发并退避，连续触发则单轮熔断。
class DouyinRateLimitGuard {
  final Duration pacingDelay;
  final Duration throttledPacingDelay;
  final int throttledConcurrency;
  final List<Duration> backoffSteps;
  final int circuitBreakerThreshold;
  final DateTime Function() clock;

  int _consecutiveRiskErrors = 0;
  bool _throttled = false;
  bool _circuitOpen = false;
  DateTime? _nextAllowedAt;
  Future<void> _slotChain = Future.value();
  final Completer<void> _breakerSignal = Completer<void>();

  DouyinRateLimitGuard({
    this.pacingDelay = Duration.zero,
    this.throttledPacingDelay = const Duration(milliseconds: 80),
    this.throttledConcurrency = 2,
    this.backoffSteps = const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1500),
    ],
    this.circuitBreakerThreshold = 3,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  bool get isCircuitOpen => _circuitOpen;
  bool get isThrottled => _throttled;
  int get consecutiveRiskErrors => _consecutiveRiskErrors;

  static bool isRiskOrRateLimitError(Object error) {
    if (error is CoreError &&
        (error.statusCode == 444 ||
            error.statusCode == 429 ||
            error.statusCode == 403)) {
      return true;
    }
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('444') ||
        text.contains('429') ||
        text.contains('风控') ||
        text.contains('验证码') ||
        text.contains('verify') ||
        text.contains('captcha') ||
        text.contains('rate limit') ||
        text.contains('too many') ||
        text.contains('频繁');
  }

  bool _shouldStopWorker(int workerIndex, bool Function() isCancelled) =>
      _circuitOpen ||
      isCancelled() ||
      (_throttled && workerIndex >= throttledConcurrency);

  /// 为当前 worker 预约发送窗口；健康状态零等待直通，命中风控后收紧并发与间隔。
  Future<bool> acquireSlot({
    required bool Function() isCancelled,
    int workerIndex = 0,
  }) {
    if (_shouldStopWorker(workerIndex, isCancelled)) {
      return Future.value(false);
    }
    if (!_throttled && pacingDelay <= Duration.zero && _nextAllowedAt == null) {
      return Future.value(true);
    }
    final completer = Completer<bool>();
    _slotChain = _slotChain.then((_) async {
      if (_shouldStopWorker(workerIndex, isCancelled)) {
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      final target = _nextAllowedAt;
      if (target != null) {
        final now = clock();
        if (now.isBefore(target)) {
          final remaining = target.difference(now);
          await Future.any<void>([
            Future<void>.delayed(remaining),
            _breakerSignal.future,
          ]);
        }
      }
      if (_shouldStopWorker(workerIndex, isCancelled)) {
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      final effectivePacing = _throttled ? throttledPacingDelay : pacingDelay;
      if (effectivePacing > Duration.zero) {
        final next = clock().add(effectivePacing);
        if (_nextAllowedAt == null || _nextAllowedAt!.isBefore(next)) {
          _nextAllowedAt = next;
        }
      }
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  void recordSuccess() {
    _consecutiveRiskErrors = 0;
  }

  /// 记录一次异常；命中限流/风控立即启用保守降速，达到阈值时触发单轮熔断。
  bool recordError(Object error) {
    if (!isRiskOrRateLimitError(error)) return false;
    _throttled = true;
    _consecutiveRiskErrors++;
    if (_consecutiveRiskErrors >= circuitBreakerThreshold) {
      final newlyOpened = !_circuitOpen;
      _circuitOpen = true;
      if (!_breakerSignal.isCompleted) _breakerSignal.complete();
      return newlyOpened;
    }
    if (backoffSteps.isNotEmpty) {
      final index =
          (_consecutiveRiskErrors - 1).clamp(0, backoffSteps.length - 1);
      final wait = backoffSteps[index];
      if (wait > Duration.zero) {
        final next = clock().add(wait);
        if (_nextAllowedAt == null || _nextAllowedAt!.isBefore(next)) {
          _nextAllowedAt = next;
        }
      }
    }
    return false;
  }

  void dispose() {
    if (!_breakerSignal.isCompleted) _breakerSignal.complete();
  }
}

/// Helper to run up to [concurrency] workers over [queue] until empty or stopped.
Future<void> runFollowQueueWorkers<T>({
  required Queue<T> queue,
  required int concurrency,
  required Future<void> Function(T item) task,
  required bool Function() isCancelled,
}) async {
  if (queue.isEmpty) return;
  final workerCount = concurrency.clamp(1, queue.length);
  await Future.wait(List.generate(workerCount, (_) async {
    while (!isCancelled() && queue.isNotEmpty) {
      final item = queue.removeFirst();
      await task(item);
    }
  }));
}
