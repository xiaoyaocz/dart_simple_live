extension DurationStringExtensions on String {
  /// 将 "HH:MM:SS" 格式的字符串转换为 Duration
  Duration toDuration() {
    final parts = split(':');
    if (parts.length != 3) {
      throw FormatException('Invalid duration format: $this');
    }

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = int.tryParse(parts[2]) ?? 0;

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}

extension DurationExtensions on Duration {
  /// 将 Duration 转换为紧凑格式的字符串（如 "2h30m15s"）
  String toHMSString() {
    final hours = inHours; // 计算总小时数
    final minutes = inMinutes.remainder(60); // 计算剩余分钟数
    final seconds = inSeconds.remainder(60); // 计算剩余秒数

    // 格式化分钟和秒为两位数
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    return '$hours:$minutesStr:$secondsStr';
  }
}
