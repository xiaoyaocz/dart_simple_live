import 'package:simple_live_core/src/common/core_error.dart';
import 'package:dio/dio.dart';

import 'custom_interceptor.dart';

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
        connectTimeout: Duration(seconds: 20),
        receiveTimeout: Duration(seconds: 20),
        sendTimeout: Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(CustomInterceptor());
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
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          headers: header,
        ),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw CoreError("发送GET请求失败");
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
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
        ),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw CoreError("发送GET请求失败");
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
        throw CoreError("发送POST请求失败");
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
      var result = await dio.head(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: header,
          receiveDataWhenStatusError: true,
        ),
        cancelToken: cancel,
      );
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        //throw CoreError(e.message, statusCode: e.response?.statusCode ?? 0);
        return e.response!;
      } else {
        throw CoreError("发送HEAD请求失败");
      }
    }
  }
}
