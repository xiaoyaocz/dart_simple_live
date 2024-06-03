import 'package:dio/dio.dart';

import 'core_log.dart';

class CustomInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra["ts"] = DateTime.now().millisecondsSinceEpoch;
    if (CoreLog.requestLogType == RequestLogType.all) {
      CoreLog.i(
        '''[HTTP Request] [${options.method}]
Request URL：${options.uri}
Request Query：${options.queryParameters}
Request Data：${options.data}
Request Headers：${options.headers}''',
      );
    } else if (CoreLog.requestLogType == RequestLogType.short) {
      CoreLog.i("[HTTP Request] [${options.method}] ${options.uri}");
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var time =
        DateTime.now().millisecondsSinceEpoch - err.requestOptions.extra["ts"];
    if (CoreLog.requestLogType == RequestLogType.all) {
      CoreLog.e('''[HTTP Error] [${err.type}] [Time:${time}ms]
${err.message}

Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${err.requestOptions.uri}
Request Query：${err.requestOptions.queryParameters}
Request Data：${err.requestOptions.data}
Request Headers：${err.requestOptions.headers}
Response Headers：${err.response?.headers.map}
Response Data：${err.response?.data}''', err.stackTrace);
    } else {
      CoreLog.e(
        "[HTTP Error] [${err.type}] [Time:${time}ms]\n[${err.response?.statusCode}] ${err.requestOptions.uri}",
        err.stackTrace,
      );
    }

    super.onError(err, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    var time = DateTime.now().millisecondsSinceEpoch -
        response.requestOptions.extra["ts"];
    if (CoreLog.requestLogType == RequestLogType.all) {
      CoreLog.i(
        '''[HTTP Response] [time:${time}ms]
Request Method：${response.requestOptions.method}
Request Code：${response.statusCode}
Request URL：${response.requestOptions.uri}
Request Query：${response.requestOptions.queryParameters}
Request Data：${response.requestOptions.data}
Request Headers：${response.requestOptions.headers}
Response Headers：${response.headers.map}
Response Data：${response.data}''',
      );
    } else if (CoreLog.requestLogType == RequestLogType.short) {
      CoreLog.i(
        "[HTTP Response] [time:${time}ms] [${response.statusCode}] ${response.requestOptions.uri}",
      );
    }
    super.onResponse(response, handler);
  }
}
