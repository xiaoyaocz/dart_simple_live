class TarsDecodeException extends Error {
  String message;
  TarsDecodeException(this.message);
  @override
  String toString() {
    return message;
  }
}
