import 'dart:io';

import 'package:dio/dio.dart';
import 'package:simple_live_app/requests/custom_log_interceptor.dart';
import 'package:simple_live_app/requests/http_error.dart';

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
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(CustomLogInterceptor());
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
        throw HttpError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw HttpError("发送GET请求失败");
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
        throw HttpError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw HttpError("发送GET请求失败");
      }
    }
  }

  /// Get请求，返回Response
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<Response<dynamic>> get(
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
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw HttpError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw HttpError("发送GET请求失败");
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
        throw HttpError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw HttpError("发送POST请求失败");
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
        return e.response!;
      } else {
        throw HttpError("发送HEAD请求失败");
      }
    }
  }

  /// DOWNLOAD 文件
  /// * [url] 下载链接
  /// * [savePath] 保存路径
  /// * [header] 可选请求头
  /// * [cancel] 任务取消Token
  /// * [onProgress] 下载进度 0~1
  Future<File> download(
      String url,
      String savePath, {
        Map<String, dynamic>? header,
        CancelToken? cancel,
        Function(int value, int progress)? onReceiveProgress,
      }) async {
    header ??= {};
    final tempPath = "$savePath.part";
    final tempFile = File(tempPath);

    try {
      if (!await tempFile.exists()) {
        await tempFile.create(recursive: true);
      }
      final response = await dio.download(
        url,
        tempPath,
        cancelToken: cancel,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          headers: header,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        // 下载完成重命名临时文件
        return await tempFile.rename(savePath);
      } else {
        throw HttpError("下载失败", statusCode: response.statusCode ?? 0);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw HttpError("下载已取消");
      } else if (e.type == DioExceptionType.badResponse) {
        throw HttpError(e.message ?? "",
            statusCode: e.response?.statusCode ?? 0);
      } else {
        throw HttpError("下载请求失败");
      }
    }
  }
}
