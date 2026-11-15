import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test(
      'signed native URL preserves the session token exactly once and Unicode text',
      () {
    final unsigned = Uri.https('live.douyin.com', '/webcast/room/chat/', {
      'room_id': '1234567890123456789',
      'content': "你好' 👋 [比心]",
      'msToken': 'current-session-token',
    });
    final signed = Uri.parse(DouyinSign.getAbogusUrl(
        unsigned.toString(), DouyinSign.defaultUserAgent));
    expect(signed.queryParametersAll['msToken'], ['current-session-token']);
    expect(signed.queryParameters['content'], "你好' 👋 [比心]");
    expect(signed.queryParameters['a_bogus'], isNotEmpty);
  });
}
