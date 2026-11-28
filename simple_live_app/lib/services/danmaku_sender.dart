class DanmakuSendResult {
  const DanmakuSendResult(this.status, this.message, {this.userId, this.userName});
  final String? userId, userName;
  final String status;
  final String message;
  bool get sent => status == 'sent';
}

abstract interface class DanmakuSender {
  void prepare();
  Future<DanmakuSendResult> send(String text);
  Future<void> dispose();
}

typedef DanmakuCredentials = Future<Map<String, String>> Function(Uri uri);
