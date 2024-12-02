class TupResultException implements Exception {
  late int code;
  late String? message;

  TupResultException(this.code, {this.message});

  @override
  String toString() {
    return '{code: $code, message: $message}';
  }
}
