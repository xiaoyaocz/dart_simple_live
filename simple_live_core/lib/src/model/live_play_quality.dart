import 'dart:convert';

class LivePlayQuality {
  /// 清晰度
  final String quality;

  /// 清晰度信息
  final dynamic data;

  final int sort;

  LivePlayQuality({
    required this.quality,
    required this.data,
    this.sort = 0,
  });

  @override
  String toString() {
    return json.encode({
      "quality": quality,
      "data": data.toString(),
    });
  }
}
