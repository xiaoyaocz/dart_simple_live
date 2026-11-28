import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../model/live_play_url.dart';
import 'http_client.dart';
import 'native_quality.dart';

/// Probe only the selected HLS URL. A FLV start incurs zero extra requests.
/// One second / 128KiB bound; failed/unsupported manifests retain normal playback.
Future<LivePlayUrl> preferNativeHls(
  LivePlayUrl input, {
  double displayHz = 0,
  double? maxFrameRate,
}) async {
  if (input.urls.isEmpty) return input;
  final uri = Uri.tryParse(input.urls.first);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      !uri.path.toLowerCase().endsWith('.m3u8')) {
    return input;
  }
  final cancel = CancelToken();
  Future<LivePlayUrl> resolve() async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.stream,
        headers: input.headers,
      ),
      cancelToken: cancel,
    );
    final body = response.data;
    if (body == null) return input;
    final bytes = <int>[];
    await for (final chunk in body.stream) {
      if (bytes.length + chunk.length > 128 * 1024) return input;
      bytes.addAll(chunk);
    }
    final base = response.realUri;
    final variants = nativeHlsVariants(
      base,
      utf8.decode(bytes, allowMalformed: true),
    );
    final selected = chooseNativeHlsVariant(
      variants,
      displayHz: displayHz,
      maxFrameRate: maxFrameRate,
    );
    if (selected == null) {
      if (maxFrameRate != null && variants.isNotEmpty) {
        return LivePlayUrl(
          urls: [],
          headers: input.headers,
          nativeVariants: variants,
          actualQuality: input.actualQuality,
        );
      }
      return input;
    }
    final url = selected.uri.toString();
    return LivePlayUrl(
      urls: [
        url,
        ...(maxFrameRate == null
            ? input.urls.where((u) => u != url)
            : variants
                  .where(
                    (v) =>
                        v.frameRate <= maxFrameRate + 0.01 &&
                        v.uri.toString() != url,
                  )
                  .map((v) => v.uri.toString())),
      ],
      headers: input.headers,
      nativeVariants: variants,
      selectedNativeVariant: selected,
      actualQuality: input.actualQuality,
    );
  }

  try {
    return await resolve().timeout(const Duration(seconds: 1));
  } on Exception {
    return maxFrameRate == null
        ? input
        : LivePlayUrl(
            urls: [],
            headers: input.headers,
            actualQuality: input.actualQuality,
          );
  } finally {
    cancel.cancel('Native HLS preference finished');
  }
}
