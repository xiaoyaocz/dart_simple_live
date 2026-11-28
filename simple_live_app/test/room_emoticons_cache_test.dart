import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/room_emoticons.dart';

LiveMessage _message(String text) => LiveMessage(
    type: LiveMessageType.chat,
    userName: 'u',
    message: text,
    color: LiveMessageColor.white);
void main() {
  test(
      'room reuses resolved immutable parts and evicts least recently used messages',
      () {
    final room = RoomEmoticons(platform: 'test', roomId: '1');
    final oldest = _message('old'), recent = _message('recent');
    final oldParts = room.resolve(oldest), recentParts = room.resolve(recent);
    expect(identical(room.resolve(recent), recentParts), isTrue);
    for (var i = 0; i < 511; i++) {
      room.resolve(_message('message $i'));
      room.resolve(recent);
    }
    expect(identical(room.resolve(recent), recentParts), isTrue);
    expect(identical(room.resolve(oldest), oldParts), isFalse);
    expect(() => recentParts.add(const LiveMessagePart.text('bad')),
        throwsUnsupportedError);
    room.dispose();
  });
  test('loading catalog invalidates previously unresolved message parts',
      () async {
    final room = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        fetch: () async => [
              const LiveEmoticon(text: '[看]', url: 'https://cdn.example/a.gif')
            ]);
    final message = _message('[看]');
    expect(room.resolve(message).single.emoticon, isNull);
    await room.load();
    final after = room.resolve(message);
    expect(after.single.emoticon!.url, 'https://cdn.example/a.gif');
    expect(identical(room.resolve(message), after), isTrue);
    room.dispose();
  });
}
