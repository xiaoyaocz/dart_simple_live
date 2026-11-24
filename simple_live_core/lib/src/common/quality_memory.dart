import '../model/live_play_quality.dart';

/// 清晰度记忆：按平台记录用户上次手动选择的清晰度。
///
/// 各平台（甚至各房间）的清晰度列表不同，因此同时记录两项：
/// - 清晰度显示名称（恢复时优先精确匹配）
/// - 距最高档的偏移（名称不存在时兜底；所有平台的列表 index 0 恒为最高档）
class QualityMemory {
  /// 单条记忆的 JSON 编码，形如 {"name": "蓝光8M", "offset": 0}。
  static Map<String, dynamic> encodeEntry({
    required String qualityName,
    required int offsetFromTop,
  }) {
    return {"name": qualityName, "offset": offsetFromTop};
  }

  /// 解码单条记忆，字段缺失或非法时返回 null。
  static ({String name, int offset})? decodeEntry(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final name = raw["name"]?.toString() ?? "";
    final offset = raw["offset"];
    if (name.isEmpty || offset is! int || offset < 0) {
      return null;
    }
    return (name: name, offset: offset);
  }

  /// 在清晰度列表中定位记忆的档位：名称精确匹配优先，
  /// 其次按距最高档的偏移；都不命中返回 -1，由调用方走默认策略。
  static int resolveIndex({
    required List<LivePlayQuality> qualities,
    String? savedName,
    int? savedOffset,
  }) {
    if (savedName != null && savedName.isNotEmpty) {
      final index = qualities.indexWhere((e) => e.quality == savedName);
      if (index >= 0) {
        return index;
      }
    }
    if (savedOffset != null &&
        savedOffset >= 0 &&
        savedOffset < qualities.length) {
      return savedOffset;
    }
    return -1;
  }
}
