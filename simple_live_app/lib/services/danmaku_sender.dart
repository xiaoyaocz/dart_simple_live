class DanmakuSendResult {
  const DanmakuSendResult(this.status, this.message);
  final String status;
  final String message;
  bool get sent => status == 'sent';
  factory DanmakuSendResult.fromValue(dynamic value) {
    if (value is! Map ||
        value['status'] is! String ||
        value['message'] is! String) {
      return const DanmakuSendResult('unknown', '发送结果未确认，请先查看聊天，避免重复发送');
    }
    return DanmakuSendResult(
        value['status'] as String, value['message'] as String);
  }
}

abstract interface class DanmakuSender {
  void prepare();
  Future<DanmakuSendResult> send(String text);
  Future<void> dispose();
}

typedef DanmakuCredentials = Future<Map<String, String>> Function(Uri uri);
