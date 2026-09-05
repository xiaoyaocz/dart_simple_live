enum AutoExitSource { none, global, roomOverride }

class AutoExitSession {
  AutoExitSource source = AutoExitSource.none;
  DateTime? deadline;
  DateTime? globalDeadline;

  bool get enabled => source != AutoExitSource.none && deadline != null;

  /// Returns whether the active deadline has been reached.
  bool isDue(DateTime now) {
    final currentDeadline = deadline;
    return enabled && currentDeadline != null && !currentDeadline.isAfter(now);
  }

  void startGlobal({required DateTime now, required int minutes}) {
    final duration = Duration(minutes: _normalizeMinutes(minutes));
    globalDeadline = now.add(duration);
    deadline = globalDeadline;
    source = AutoExitSource.global;
  }

  void startRoomOverride({required DateTime now, required int minutes}) {
    deadline = now.add(Duration(minutes: _normalizeMinutes(minutes)));
    source = AutoExitSource.roomOverride;
  }

  void stop() {
    source = AutoExitSource.none;
    deadline = null;
    globalDeadline = null;
  }

  Duration remaining(DateTime now) {
    final currentDeadline = deadline;
    if (currentDeadline == null) {
      return Duration.zero;
    }
    final value = currentDeadline.difference(now);
    return value.isNegative ? Duration.zero : value;
  }

  Duration globalRemaining(DateTime now) {
    final currentDeadline = globalDeadline;
    if (currentDeadline == null) {
      return Duration.zero;
    }
    final value = currentDeadline.difference(now);
    return value.isNegative ? Duration.zero : value;
  }

  static int _normalizeMinutes(int minutes) {
    return minutes.clamp(1, 24 * 60).toInt();
  }
}
