import 'dart:async';
import 'dart:io';

import 'package:simple_live_app/services/playback_route_history.dart';

typedef RouteProbeRequest = Future<int?> Function(
  Uri uri,
  Map<String, String>? headers,
  Duration timeout,
);

/// 开播或切换清晰度前的轻量 CDN 线路并发测速优选。
///
/// 仅对同协议、同扩展名（`.flv` / `.m3u8`）、同流文件名的前 N 条备用线路
/// 做 HTTP 响应头握手测速（收到状态码后立即断开，不下载视频正文），
/// 硬超时上限默认 400ms，超时或无可用结果时无感回退默认顺序。
class StreamRouteProber {
  StreamRouteProber({
    this.timeout = const Duration(milliseconds: 400),
    this.maxCandidates = 3,
    RouteProbeRequest? probeRequest,
  }) : _probeRequest = probeRequest ?? _defaultProbeRequest;

  final Duration timeout;
  final int maxCandidates;
  final RouteProbeRequest _probeRequest;

  /// 返回建议优先尝试的线路下标；不适合测速或超时则返回历史首选（通常为 0）。
  Future<int> selectFastest({
    required String site,
    required String quality,
    required List<String> urls,
    Map<String, String>? headers,
    PlaybackRouteHistory? history,
    bool recordHistory = true,
  }) async {
    if (urls.isEmpty) return -1;
    final routeHistory = history ?? PlaybackRouteHistory.instance;
    final eligible = _eligibleIndices(urls);
    if (eligible.length < 2) {
      return routeHistory.select(site, quality, urls);
    }

    final candidates = eligible.take(maxCandidates).toList(growable: false);
    final winner = Completer<int?>();
    var remaining = candidates.length;

    for (final index in candidates) {
      final url = urls[index];
      final uri = Uri.tryParse(url);
      if (uri == null) {
        remaining--;
        continue;
      }
      final watch = Stopwatch()..start();
      unawaited(() async {
        try {
          final status = await _probeRequest(uri, headers, timeout);
          watch.stop();
          if (status != null && status >= 200 && status < 400) {
            if (recordHistory) routeHistory.success(
              site,
              quality,
              url,
              watch.elapsed > Duration.zero
                  ? watch.elapsed
                  : const Duration(milliseconds: 1),
            );
            if (!winner.isCompleted) {
              winner.complete(index);
            }
          } else if (recordHistory && status != null && status >= 400) {
            routeHistory.failure(site, quality, url);
          }
        } catch (_) {
          // 测速超时或网络异常不中断主起播链路
        } finally {
          remaining--;
          if (remaining <= 0 && !winner.isCompleted) {
            winner.complete(null);
          }
        }
      }());
    }

    if (remaining <= 0 && !winner.isCompleted) {
      winner.complete(null);
    }

    final selected = await winner.future.timeout(timeout, onTimeout: () => null);
    if (selected != null && selected >= 0 && selected < urls.length) {
      return selected;
    }
    final fallback = routeHistory.select(site, quality, urls);
    return fallback >= 0 ? fallback : 0;
  }

  static List<int> _eligibleIndices(List<String> urls) {
    final firstUri = Uri.tryParse(urls.first);
    final firstExt = _streamExtension(firstUri);
    if (firstUri == null ||
        firstExt == null ||
        firstUri.pathSegments.isEmpty) {
      return const [];
    }
    final scheme = firstUri.scheme;
    final streamFile = firstUri.pathSegments.last;
    final result = <int>[];
    final seenOrigins = <String>{};
    for (var i = 0; i < urls.length; i++) {
      final uri = Uri.tryParse(urls[i]);
      if (uri == null ||
          uri.host.isEmpty ||
          uri.scheme != scheme ||
          uri.pathSegments.isEmpty ||
          uri.pathSegments.last != streamFile ||
          _streamExtension(uri) != firstExt) {
        continue;
      }
      if (seenOrigins.add(uri.origin)) {
        result.add(i);
      }
    }
    return result;
  }

  static String? _streamExtension(Uri? uri) {
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    final lower = uri.path.toLowerCase();
    if (lower.endsWith('.flv')) return '.flv';
    if (lower.endsWith('.m3u8')) return '.m3u8';
    return null;
  }

  static Future<int?> _defaultProbeRequest(
    Uri uri,
    Map<String, String>? headers,
    Duration timeout,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = true;
      request.maxRedirects = 3;
      if (headers != null) {
        headers.forEach((key, value) {
          if (key.toLowerCase() != 'range') {
            request.headers.set(key, value);
          }
        });
      }
      // 仅探测首字节/响应头，避免服务端持续推送直播流正文
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final response = await request.close().timeout(timeout);
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }
}
