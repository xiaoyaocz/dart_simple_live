class AppError extends Error {
  /// 错误码
  final int code;

  /// 错误信息
  final String message;

  /// 是否是Http请求错误
  final bool isHttpError;

  final bool notLogin;

  AppError(
    this.message, {
    this.code = 0,
    this.isHttpError = false,
    this.notLogin = false,
  });
  @override
  String toString() {
    return message;
  }
}
