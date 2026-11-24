class FollowRefreshProgress {
  final bool active;
  final String stage;
  final int current;
  final int total;
  final int successCount;
  final int failedCount;
  final int deferredCount;
  final int skippedCount;
  final bool automatic;
  final String scopeKey;
  final bool completed;
  final bool background;
  final String detail;

  const FollowRefreshProgress({
    this.active = false,
    this.stage = "",
    this.current = 0,
    this.total = 0,
    this.successCount = 0,
    this.failedCount = 0,
    this.deferredCount = 0,
    this.skippedCount = 0,
    this.automatic = false,
    this.scopeKey = "",
    this.completed = false,
    this.background = false,
    this.detail = "",
  });

  const FollowRefreshProgress.idle() : this();

  double get percent {
    if (total <= 0) {
      return 0;
    }
    return (resolvedCount / total).clamp(0, 1).toDouble();
  }

  String get displayText {
    if (total > 0) {
      return "$stage $current/$total";
    }
    return stage;
  }

  int get remainingCount {
    final remaining = total - resolvedCount;
    return remaining < 0 ? 0 : remaining;
  }

  int get resolvedCount {
    return current + skippedCount;
  }

  FollowRefreshProgress copyWith({
    bool? active,
    String? stage,
    int? current,
    int? total,
    int? successCount,
    int? failedCount,
    int? deferredCount,
    int? skippedCount,
    bool? automatic,
    String? scopeKey,
    bool? completed,
    bool? background,
    String? detail,
  }) {
    return FollowRefreshProgress(
      active: active ?? this.active,
      stage: stage ?? this.stage,
      current: current ?? this.current,
      total: total ?? this.total,
      successCount: successCount ?? this.successCount,
      failedCount: failedCount ?? this.failedCount,
      deferredCount: deferredCount ?? this.deferredCount,
      skippedCount: skippedCount ?? this.skippedCount,
      automatic: automatic ?? this.automatic,
      scopeKey: scopeKey ?? this.scopeKey,
      completed: completed ?? this.completed,
      background: background ?? this.background,
      detail: detail ?? this.detail,
    );
  }
}
