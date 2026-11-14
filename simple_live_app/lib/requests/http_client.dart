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
      } else if (e is DioException) {
        throw HttpError(_dioExceptionToString(e, "GET"));
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
      } else if (e is DioException) {
        throw HttpError(_dioExceptionToString(e, "GET"));
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
      } else if (e is DioException) {
        throw HttpError(_dioExceptionToString(e, "GET"));
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
      } else if (e is DioException) {
        throw HttpError(_dioExceptionToString(e, "POST"));
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
      } else if (e is DioException) {
        throw HttpError(_dioExceptionToString(e, "HEAD"));
      } else {
        throw HttpError("发送HEAD请求失败");
      }
    }
  }

  String _dioExceptionToString(DioException exception, String method) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
        return "$method连接超时，请检查地址、端口和局域网是否互通";
      case DioExceptionType.sendTimeout:
        return "$method发送超时，配置包可能较大或对方设备响应太慢";
      case DioExceptionType.receiveTimeout:
        return "$method接收超时，对方设备可能卡住或网络不稳定";
      case DioExceptionType.connectionError:
        return "$method连接失败，请确认对方设备已打开局域网同步";
      case DioExceptionType.cancel:
        return "请求已取消";
      case DioExceptionType.badCertificate:
        return "证书验证失败";
      case DioExceptionType.unknown:
        return exception.message?.isNotEmpty == true
            ? exception.message!
            : "发送$method请求失败";
      case DioExceptionType.badResponse:
        return exception.message ?? "服务器响应异常";
      default:
        return exception.message?.isNotEmpty == true
            ? exception.message!
            : "发送$method请求失败";
    }
  }
}
