import 'dart:convert';

class LivePlayUrl {
  /// 播放地址
  final List<String> urls;

  /// 请求头
  final Map<String, String>? headers;

  LivePlayUrl({
    required this.urls,
    this.headers,
  });

  @override
  String toString() {
    return json.encode({
      "urls": urls,
      "headers": headers.toString(),
    });
  }
}
