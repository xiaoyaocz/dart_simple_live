import 'package:simple_live_core/simple_live_core.dart';

/// Instance belongs to one platform/account context. Never infer from text.
class SelfDanmakuIdentity {
  String? userId;
  String? userName;
  static String? validId(String? value) =>
      value != null && RegExp(r'^[1-9][0-9]*$').hasMatch(value) ? value : null;
  void update(String? id, String? name) {
    userId = validId(id);
    userName = name?.trim().isNotEmpty == true ? name!.trim() : null;
  }

  bool matches(LiveMessage message) {
    if (userId != null) return validId(message.userId) == userId;
    return userName != null && message.userName == userName;
  }
}
