class FollowUpdateIntervalOptions {
  static const List<int> presets = [
    5,
    10,
    15,
    20,
    25,
    30,
    45,
    60,
    90,
    120,
    180,
    240,
  ];

  static Map<int, String> get presetLabels => {
        for (final minutes in presets) minutes: format(minutes),
      };

  static String format(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours <= 0) {
      return "$minutes分钟";
    }
    if (remainingMinutes == 0) {
      return "$hours小时";
    }
    return "$hours小时$remainingMinutes分钟";
  }

  static int normalizeToPreset(int minutes) {
    var nearest = presets.first;
    var nearestDistance = (minutes - nearest).abs();
    for (final preset in presets.skip(1)) {
      final distance = (minutes - preset).abs();
      if (distance < nearestDistance ||
          (distance == nearestDistance && preset > nearest)) {
        nearest = preset;
        nearestDistance = distance;
      }
    }
    return nearest;
  }
}
