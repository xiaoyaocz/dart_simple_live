class PlayerVolumePolicy {
  const PlayerVolumePolicy._();

  /// 基础段上限：≤100% 为常规音量（移动端=系统音量，桌面=播放器音量）。
  static const double baseVolume = 100.0;

  /// 音量上限：>100% 的部分为播放器软件增益档，
  /// 依赖播放器初始化时设置 mpv `volume-max=300`。
  static const double maxVolume = 300.0;

  /// 是否处于增益段。
  static bool isBoostVolume(double volume) => volume > baseVolume;

  /// 计算播放器内部音量。
  ///
  /// 移动端 ≤100 段由系统音量控制实际输出，播放器内部保持满格；
  /// >100 的增益档由播放器自身应用（mpv 软件增益）。
  static double internalVolume({
    required bool mobile,
    required bool muted,
    required double persisted,
  }) {
    if (muted) {
      return 0;
    }
    final value = persisted.clamp(0.0, maxVolume).toDouble();
    if (mobile) {
      return value > baseVolume ? value : baseVolume;
    }
    return value;
  }
}
