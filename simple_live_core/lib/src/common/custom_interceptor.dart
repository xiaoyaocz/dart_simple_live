import 'package:dio/dio.dart';

import 'core_log.dart';
import 'http_log_sanitizer.dart';

class CustomInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra["ts"] = DateTime.now().millisecondsSinceEpoch;
    if (CoreLog.requestLogType == RequestLogType.all) {
      CoreLog.i('''[HTTP Request] [${options.method}]
Request URL：${HttpLogSanitizer.redactUri(options.uri)}
Request Query：${HttpLogSanitizer.redact(options.queryParameters)}
Request Data：${HttpLogSanitizer.redact(options.data)}
Request Headers：${HttpLogSanitizer.redact(options.headers)}''');
    } else if (CoreLog.requestLogType == RequestLogType.short) {
      CoreLog.i(
        "[HTTP Request] [${options.method}] ${HttpLogSanitizer.redactUri(options.uri)}",
      );
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var time =
        DateTime.now().millisecondsSinceEpoch - err.requestOptions.extra["ts"];
    if (CoreLog.requestLogType == RequestLogType.all) {
      CoreLog.e(
        '''[HTTP Error] [${err.type}] [Time:${time}ms]
${HttpLogSanitizer.redactText(err.message, requestUri: err.requestOptions.uri)}

Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${HttpLogSanitizer.redactUri(err.requestOptions.uri)}
Request Query：${HttpLogSanitizer.redact(err.requestOptions.queryParameters)}
Request Data：${HttpLogSanitizer.redact(err.requestOptions.data)}
Request Headers：${HttpLogSanitizer.redact(err.requestOptions.headers)}
Response Headers：${HttpLogSanitizer.redact(err.response?.headers.map)}
Response Data：${HttpLogSanitizer.redact(err.response?.data)}''',
        err.stackTrace,
      );
    } else {
      CoreLog.e(
        "[HTTP Error] [${err.type}] [Time:${time}ms]\n[${err.response?.statusCode}] ${HttpLogSanitizer.redactUri(err.requestOptions.uri)}",
        err.stackTrace,
      );
    }

    super.onError(err, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    var time =
        DateTime.now().millisecondsSinceEpoch -
        response.requestOptions.extra["ts"];
    if (CoreLog.requestLogType == RequestLogType.all) {
      CoreLog.i('''[HTTP Response] [time:${time}ms]
Request Method：${response.requestOptions.method}
Request Code：${response.statusCode}
Request URL：${HttpLogSanitizer.redactUri(response.requestOptions.uri)}
Request Query：${HttpLogSanitizer.redact(response.requestOptions.queryParameters)}
Request Data：${HttpLogSanitizer.redact(response.requestOptions.data)}
Request Headers：${HttpLogSanitizer.redact(response.requestOptions.headers)}
Response Headers：${HttpLogSanitizer.redact(response.headers.map)}
Response Data：${HttpLogSanitizer.redact(response.data)}''');
    } else if (CoreLog.requestLogType == RequestLogType.short) {
      CoreLog.i(
        "[HTTP Response] [time:${time}ms] [${response.statusCode}] ${HttpLogSanitizer.redactUri(response.requestOptions.uri)}",
      );
    }
    super.onResponse(response, handler);
  }
}
