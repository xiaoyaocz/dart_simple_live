class CoreError extends Error {
  /// 错误码
  final int statusCode;

  /// 错误信息
  final String message;

  /// 是否是Http请求错误
  final bool isHttpError;

  CoreError(
    this.message, {
    this.statusCode = 0,
    this.isHttpError = false,
  });
  @override
  String toString() {
    if (isHttpError && message.isEmpty) {
      return statusCodeToString(statusCode);
    }

    return message;
  }

  String statusCodeToString(int statusCode) {
    switch (statusCode) {
      case 400:
        return "错误的请求(400)";
      case 401:
        return "无权限访问资源(401)";
      case 403:
        return "无权限访问资源(403)";
      case 404:
        return "服务器找不到请求的资源(404)";
      case 500:
        return "服务器出现错误(500)";
      case 502:
        return "服务器出现错误(502)";
      case 503:
        return "服务器出现错误(503)";
      default:
        return "连接服务器失败，请稍后再试($statusCode)";
    }
  }
}
