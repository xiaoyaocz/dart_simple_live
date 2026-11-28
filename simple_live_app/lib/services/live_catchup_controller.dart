/// 直播累积延迟自动微倍速追帧状态机。
///
/// 通过滞回阈值和连续采样确认，避免网络短暂波动导致播放倍速频繁抖动：
/// - 相对起播时的延迟连续达到 8 秒：1.08x 温和追帧
/// - 相对起播时的延迟连续达到 14 秒：1.15x 加速追帧
/// - 延迟回落到 3 秒以下，或处于缓冲/非播放状态：恢复 1.0x
class LiveCatchupController {
  LiveCatchupController({
    this.mildThresholdSeconds = 8.0,
    this.severeThresholdSeconds = 14.0,
    this.restoreThresholdSeconds = 3.0,
    this.mildRate = 1.08,
    this.severeRate = 1.15,
    this.confirmSamples = 2,
  });

  final double mildThresholdSeconds;
  final double severeThresholdSeconds;
  final double restoreThresholdSeconds;
  final double mildRate;
  final double severeRate;
  final int confirmSamples;

  double _currentRate = 1.0;
  int _mildSamples = 0;
  int _severeSamples = 0;

  double get currentRate => _currentRate;

  double evaluate(
    double? lagSeconds, {
    required bool enabled,
    required bool buffering,
    required bool active,
  }) {
    if (!enabled ||
        buffering ||
        !active ||
        lagSeconds == null ||
        !lagSeconds.isFinite) {
      reset();
      return _currentRate;
    }

    if (lagSeconds <= restoreThresholdSeconds) {
      reset();
      return _currentRate;
    }

    if (lagSeconds >= severeThresholdSeconds) {
      _severeSamples++;
      _mildSamples++;
      if (_severeSamples >= confirmSamples) {
        _currentRate = severeRate;
      } else if (_mildSamples >= confirmSamples && _currentRate < mildRate) {
        _currentRate = mildRate;
      }
      return _currentRate;
    }

    if (lagSeconds >= mildThresholdSeconds) {
      _severeSamples = 0;
      _mildSamples++;
      if (_mildSamples >= confirmSamples) {
        _currentRate = mildRate;
      }
      return _currentRate;
    }

    // 处于回落区间（restoreThresholdSeconds < cache < mildThresholdSeconds）：
    // 清零加速计数；若正处于高档追帧，先降到温和追帧直至追平。
    _severeSamples = 0;
    _mildSamples = 0;
    if (_currentRate > mildRate) {
      _currentRate = mildRate;
    }
    return _currentRate;
  }

  void reset() {
    _currentRate = 1.0;
    _mildSamples = 0;
    _severeSamples = 0;
  }
}
