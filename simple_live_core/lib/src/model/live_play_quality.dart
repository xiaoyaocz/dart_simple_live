import 'dart:convert';

class LivePlayQuality {
  /// 清晰度
  final String quality;

  /// 清晰度信息
  final dynamic data;

  final int sort;

  /// Platform-advertised FPS, not measured presentation FPS. Null means unknown.
  final double? frameRate;

  LivePlayQuality({
    required this.quality,
    required this.data,
    this.sort = 0,
    this.frameRate,
  });

  @override
  String toString() {
    return json.encode({
      "quality": quality,
      "frameRate": frameRate,
      "data": data.toString(),
    });
  }
}
