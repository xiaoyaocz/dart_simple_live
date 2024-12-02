class TarsEncodeException extends Error {
  String message;
  TarsEncodeException(this.message);

  @override
  String toString() {
    return message;
  }
}
