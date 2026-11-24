class SyncProgress {
  final String stage;
  final int current;
  final int total;
  final String message;

  const SyncProgress({
    required this.stage,
    this.current = 0,
    this.total = 0,
    this.message = "",
  });

  double get percent {
    if (total <= 0) {
      return 0;
    }
    return (current / total).clamp(0, 1).toDouble();
  }

  bool get isIndeterminate => total <= 0;

  String get displayMessage {
    if (message.isNotEmpty) {
      return message;
    }
    if (total > 0) {
      return "$stage $current/$total";
    }
    return stage;
  }
}

typedef SyncProgressCallback = void Function(SyncProgress progress);
