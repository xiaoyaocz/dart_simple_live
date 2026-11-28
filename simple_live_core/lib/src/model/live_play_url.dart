import 'dart:convert';
import '../common/native_quality.dart';

class LivePlayUrl {
  /// 播放地址
  final List<String> urls;

  /// 请求头
  final Map<String, String>? headers;
  final List<NativeHlsVariant> nativeVariants;
  final NativeHlsVariant? selectedNativeVariant;

  /// 平台响应确认的清晰度。未返回画质信息时为空。
  final String? actualQuality;

  LivePlayUrl({
    required this.urls,
    this.headers,
    this.nativeVariants = const [],
    this.selectedNativeVariant,
    this.actualQuality,
  });

  @override
  String toString() {
    return json.encode({"urls": urls, "headers": headers.toString()});
  }
}
