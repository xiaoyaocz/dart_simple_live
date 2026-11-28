import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:http2/http2.dart';

const Set<String> kDefaultHttp2Hosts = {
  'live.douyin.com',
  'www.douyu.com',
  'api.live.bilibili.com',
  'api.bilibili.com',
};

const Set<String> _kForbiddenHttp2Headers = {
  'host',
  'authority',
  ':authority',
  ':method',
  ':path',
  ':scheme',
  'connection',
  'keep-alive',
  'transfer-encoding',
  'upgrade',
  'proxy-connection',
};

/// 调优后的 HTTP/1.1 连接池适配器（提高单主机并发与空闲保活时长）。
IOHttpClientAdapter createTunedIoAdapter({
  int maxConnectionsPerHost = 24,
  Duration idleTimeout = const Duration(seconds: 60),
  Duration connectionTimeout = const Duration(seconds: 8),
}) {
  return IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..maxConnectionsPerHost = maxConnectionsPerHost
      ..idleTimeout = idleTimeout
      ..connectionTimeout = connectionTimeout
      ..autoUncompress = true,
  );
}

/// 支持按主机路由 HTTP/2 多路复用，自动剥离 H1 非法请求头、解压响应体，并在协议/连接失败时透明降级回 HTTP/1.1。
class AdaptiveHttp2Adapter implements HttpClientAdapter {
  final HttpClientAdapter http1Adapter;
  final HttpClientAdapter http2Adapter;
  final Set<String> http2Hosts;
  final bool Function(Uri uri)? shouldUseHttp2;
  final Set<String> _downgradedHosts = <String>{};

  AdaptiveHttp2Adapter({
    HttpClientAdapter? http1Adapter,
    HttpClientAdapter? http2Adapter,
    this.http2Hosts = kDefaultHttp2Hosts,
    this.shouldUseHttp2,
  })  : http1Adapter = http1Adapter ?? createTunedIoAdapter(),
        http2Adapter = http2Adapter ??
            Http2Adapter(
              ConnectionManager(
                idleTimeout: const Duration(seconds: 60),
                handshakeTimeout: const Duration(seconds: 8),
                supportedProtocols: const ['h2', 'http/1.1'],
              ),
            );

  bool usesHttp2(Uri uri) =>
      uri.scheme == 'https' &&
      !_downgradedHosts.contains(uri.host) &&
      http2Hosts.contains(uri.host) &&
      (shouldUseHttp2?.call(uri) ?? true);

  bool isHostDowngraded(String host) => _downgradedHosts.contains(host);

  /// 克隆并清理仅适用于 HTTP/1.1 的请求头，同时补充 gzip 压缩声明以减小载荷。
  static RequestOptions sanitizeHttp2Options(RequestOptions options) {
    final cleaned = <String, dynamic>{};
    var hasAcceptEncoding = false;
    for (final entry in options.headers.entries) {
      final lower = entry.key.toLowerCase();
      if (_kForbiddenHttp2Headers.contains(lower)) continue;
      if (lower == 'accept-encoding') hasAcceptEncoding = true;
      cleaned[entry.key] = entry.value;
    }
    if (!hasAcceptEncoding) {
      cleaned['accept-encoding'] = 'gzip';
    }
    return options.copyWith(headers: cleaned);
  }

  /// 为不自带自动解压的 Http2Adapter 透明解码 gzip / deflate / br 响应流。
  static ResponseBody decodeCompressedBody(ResponseBody body) {
    final rawEncodings = <String>[];
    for (final entry in body.headers.entries) {
      if (entry.key.toLowerCase() == 'content-encoding') {
        rawEncodings.addAll(entry.value);
      }
    }
    final encoding = rawEncodings.join(',').toLowerCase().trim();
    if (encoding.isEmpty) return body;

    Stream<Uint8List>? decodedStream;
    if (encoding.contains('gzip')) {
      decodedStream = body.stream
          .cast<List<int>>()
          .transform(gzip.decoder)
          .map((chunk) =>
              chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    } else if (encoding.contains('deflate')) {
      decodedStream = body.stream
          .cast<List<int>>()
          .transform(zlib.decoder)
          .map((chunk) =>
              chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    } else if (encoding.contains('br')) {
      decodedStream = _decodeBrotliStream(body.stream);
    }
    if (decodedStream == null) return body;

    final nextHeaders = <String, List<String>>{};
    for (final entry in body.headers.entries) {
      final lower = entry.key.toLowerCase();
      if (lower == 'content-encoding' || lower == 'content-length') continue;
      nextHeaders[entry.key] = List<String>.from(entry.value);
    }

    return ResponseBody(
      decodedStream,
      body.statusCode,
      headers: nextHeaders,
      statusMessage: body.statusMessage,
      isRedirect: body.isRedirect,
      redirects: body.redirects,
    )..extra.addAll(body.extra);
  }

  static Stream<Uint8List> _decodeBrotliStream(Stream<Uint8List> source) async* {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) return;
    final decoded = brotli.decode(bytes);
    yield decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
  }

  bool _shouldDowngradeHost(Object error) {
    if (error is DioH2NotSupportedException ||
        error is HandshakeException ||
        error is TlsException ||
        error is TransportException) {
      return true;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.badCertificate ||
          error.type == DioExceptionType.unknown;
    }
    return false;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    if (!usesHttp2(uri)) {
      return http1Adapter.fetch(options, requestStream, cancelFuture);
    }

    final h2Options = sanitizeHttp2Options(options);
    try {
      final response = await http2Adapter.fetch(
        h2Options,
        requestStream,
        cancelFuture,
      );
      return decodeCompressedBody(response);
    } catch (error) {
      if (error is DioException &&
          (error.type == DioExceptionType.badResponse ||
              error.type == DioExceptionType.cancel)) {
        rethrow;
      }
      if (_shouldDowngradeHost(error)) {
        _downgradedHosts.add(uri.host);
      }
      if (requestStream != null) {
        rethrow;
      }
      return http1Adapter.fetch(options, null, cancelFuture);
    }
  }

  @override
  void close({bool force = false}) {
    http1Adapter.close(force: force);
    http2Adapter.close(force: force);
  }
}
