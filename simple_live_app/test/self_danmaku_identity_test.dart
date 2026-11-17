import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/self_danmaku_identity.dart';
import 'package:simple_live_core/simple_live_core.dart';

LiveMessage message(String id, String name, String text) => LiveMessage(
    type: LiveMessageType.chat,
    userId: id,
    userName: name,
    message: text,
    color: LiveMessageColor.white);
void main() {
  for (final platform in ['bilibili', 'douyu', 'huya', 'douyin']) {
    test('$platform uses UID over nickname or identical text', () {
      final identity = SelfDanmakuIdentity();
      identity.update('123', '本人');
      expect(identity.matches(message('123', '改名后', 'x')), isTrue);
      expect(identity.matches(message('456', '本人', 'x')), isFalse);
      expect(identity.matches(message('', '本人', 'x')), isFalse);
      identity.update(null, '确认昵称');
      expect(identity.matches(message('', '确认昵称', 'x')), isTrue);
      expect(identity.matches(message('', '其他人', 'x')), isFalse);
      identity.update(null, null);
      expect(identity.matches(message('123', '确认昵称', 'x')), isFalse);
    });
  }
}
