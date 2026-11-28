import 'package:simple_live_core/src/common/core_error.dart';
import 'package:dio/dio.dart';

import 'adaptive_http2_adapter.dart';
import 'custom_interceptor.dart';

CoreError _networkError(String method, Object error) => CoreError(
  '发送$method请求失败（${error is DioException ? error.type.name : error.runtimeType}）',
);

class HttpClient {
  static HttpClient? _httpUtil;

  static HttpClient get instance {
    _httpUtil ??= HttpClient();
    return _httpUtil!;
  }

  late Dio dio;
  HttpClient() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    dio.httpClientAdapter = createTunedIoAdapter();
    dio.interceptors.add(CustomInterceptor());
  }

  /// 在应用运行时启用指定白名单主机的 HTTP/2 多路复用，支持代理条件判断。
  void enableHttp2({
    bool Function(Uri uri)? shouldUseHttp2,
    Set<String>? http2Hosts,
  }) {
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = AdaptiveHttp2Adapter(
      http1Adapter: createTunedIoAdapter(),
      http2Hosts: http2Hosts ?? kDefaultHttp2Hosts,
      shouldUseHttp2: shouldUseHttp2,
    );
    previous.close();
  }

  /// 并发预热常用直播平台域名的 DNS、TLS 与 HTTP/2 / Keep-Alive 连接。
  Future<void> warmupConnections(
    Iterable<Uri> uris, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    await Future.wait(
      uris.map((uri) async {
        try {
          await dio
              .headUri(
                uri,
                options: Options(
                  sendTimeout: timeout,
                  receiveTimeout: timeout,
                  validateStatus: (_) => true,
                ),
              )
              .timeout(timeout);
        } catch (_) {
          // 预热失败静默忽略，不影响正常请求路径。
        }
      }),
    );
  }

  // Replay only safe reads, once, on a connection failure. Never replay a
  // message POST, server rejection, or a request cancelled during backoff.
  Future<Response<dynamic>> _read(
      Future<Response<dynamic>> Function() request, CancelToken? cancel) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.type != DioExceptionType.connectionError ||
          cancel?.isCancelled == true) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (cancel?.isCancelled == true) {
        throw cancel!.cancelError!;
      }
      return request();
    }
  }

  /// Get请求，返回String
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<String> getText(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await _read(() => dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          headers: header,
        ),
        cancelToken: cancel,
      ), cancel);
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw _networkError('GET', e);
      }
    }
  }

  /// Get请求，返回Map
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<dynamic> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await _read(() => dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
        ),
        cancelToken: cancel,
      ), cancel);
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw _networkError('GET', e);
      }
    }
  }

  /// Post请求，返回Map
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [data] 内容
  /// * [cancel] 任务取消Token
  Future<dynamic> postJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? header,
    bool formUrlEncoded = false,
    CancelToken? cancel,
  }) async {
    try {
      queryParameters ??= {};
      header ??= {};
      data ??= {};
      var result = await dio.post(
        url,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
          contentType:
              formUrlEncoded ? Headers.formUrlEncodedContentType : null,
        ),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw _networkError('POST', e);
      }
    }
  }

  /// Head请求，返回Response
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<Response> head(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await _read(() => dio.head(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: header,
          receiveDataWhenStatusError: true,
        ),
        cancelToken: cancel,
      ), cancel);
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        //throw CoreError(e.message, statusCode: e.response?.statusCode ?? 0);
        return e.response!;
      } else {
        throw _networkError('HEAD', e);
      }
    }
  }
}
