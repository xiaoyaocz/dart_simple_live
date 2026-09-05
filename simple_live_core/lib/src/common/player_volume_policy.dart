class PlayerVolumePolicy {
  const PlayerVolumePolicy._();

  static double internalVolume({
    required bool mobile,
    required bool muted,
    required double persisted,
  }) {
    if (muted) {
      return 0;
    }
    if (mobile) {
      return 100;
    }
    return persisted.clamp(0.0, 100.0).toDouble();
  }
}
