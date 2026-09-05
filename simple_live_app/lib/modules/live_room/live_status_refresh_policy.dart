class LiveStatusRefreshPolicy {
  LiveStatusRefreshPolicy({this.requiredOfflineConfirmations = 3})
      : assert(requiredOfflineConfirmations > 0);

  final int requiredOfflineConfirmations;
  int _consecutiveOfflineCount = 0;

  int get consecutiveOfflineCount => _consecutiveOfflineCount;

  bool confirmOffline({
    required bool reportedLive,
    required bool hasActivePlaybackEvidence,
  }) {
    if (reportedLive || hasActivePlaybackEvidence) {
      reset();
      return false;
    }
    _consecutiveOfflineCount += 1;
    return _consecutiveOfflineCount >= requiredOfflineConfirmations;
  }

  void reset() {
    _consecutiveOfflineCount = 0;
  }
}
