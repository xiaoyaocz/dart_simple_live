import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CustomLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra["ts"] = DateTime.now().millisecondsSinceEpoch;

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var time =
        DateTime.now().millisecondsSinceEpoch - err.requestOptions.extra["ts"];
    if (!kReleaseMode) {
      Log.e('''【HTTP请求错误-${err.type}】 耗时:${time}ms
${HttpLogSanitizer.redactText(err.message, requestUri: err.requestOptions.uri)}

Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${HttpLogSanitizer.redactUri(err.requestOptions.uri)}
Request Query：${HttpLogSanitizer.redact(err.requestOptions.queryParameters)}
Request Data：${HttpLogSanitizer.redact(err.requestOptions.data)}
Request Headers：${HttpLogSanitizer.redact(err.requestOptions.headers)}
Response Headers：${HttpLogSanitizer.redact(err.response?.headers.map)}
Response Data：${HttpLogSanitizer.redact(err.response?.data)}''',
          err.stackTrace);
    } else {
      CoreLog.e('''[HTTP Error] [${err.type}] [Time:${time}ms]
${HttpLogSanitizer.redactText(err.message, requestUri: err.requestOptions.uri)}

Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${HttpLogSanitizer.redactUri(err.requestOptions.uri)}
Request Query：${HttpLogSanitizer.redact(err.requestOptions.queryParameters)}
Request Data：${HttpLogSanitizer.redact(err.requestOptions.data)}
Request Headers：${HttpLogSanitizer.redact(err.requestOptions.headers)}
Response Headers：${HttpLogSanitizer.redact(err.response?.headers.map)}
Response Data：${HttpLogSanitizer.redact(err.response?.data)}''',
          err.stackTrace);
    }

    super.onError(err, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    var time = DateTime.now().millisecondsSinceEpoch -
        response.requestOptions.extra["ts"];
    if (!kReleaseMode) {
      Log.i(
        '''【HTTP请求响应】 耗时:${time}ms
Request Method：${response.requestOptions.method}
Request Code：${response.statusCode}
Request URL：${HttpLogSanitizer.redactUri(response.requestOptions.uri)}
Request Query：${HttpLogSanitizer.redact(response.requestOptions.queryParameters)}
Request Data：${HttpLogSanitizer.redact(response.requestOptions.data)}
Request Headers：${HttpLogSanitizer.redact(response.requestOptions.headers)}
Response Headers：${HttpLogSanitizer.redact(response.headers.map)}
Response Data：${HttpLogSanitizer.redact(response.data)}''',
      );
    } else {
      CoreLog.i(
        "[HTTP Response] [time:${time}ms] [${response.statusCode}] ${HttpLogSanitizer.redactUri(response.requestOptions.uri)}",
      );
    }
    super.onResponse(response, handler);
  }
}
