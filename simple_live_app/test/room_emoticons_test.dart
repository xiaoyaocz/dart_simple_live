import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/room_emoticons.dart';

void main() {
  test('虎牙发送表情使用原生转义码，保留草稿标签和其他平台原文', () async {
    final room = RoomEmoticons(platform: 'huya', roomId: '1');
    expect(room.encodeForSend('你好[666] /{66 [未知]'), '你好/{66 /{66 [未知]');
    expect(room.available.any((e) => e.text == '[666]'), isTrue);
    room.dispose();
    final other = RoomEmoticons(platform: 'douyu', roomId: '1');
    expect(other.encodeForSend('[666]'), '[666]');
    other.dispose();
  });
  test('picker catalog includes the full seeded library and deduplicates aliases', () async {
    final room = RoomEmoticons(platform: 'douyin', roomId: '1', fetch: () async => []);
    expect(room.available.length, greaterThan(100));
    room.dispose();
    final other = RoomEmoticons(platform: 'test', roomId: '1', fetch: () async => [
      const LiveEmoticon(text: '[笑]', url: 'https://cdn.example/a'),
      const LiveEmoticon(text: '/alias', url: 'https://cdn.example/a'),
      const LiveEmoticon(text: '[坏]', url: 'javascript:bad'),
    ]);
    await other.load();
    expect(other.available.map((e) => e.text), ['[笑]']);
    other.dispose();
  });
  test('unknown tokens retry after backoff, bounded to three attempts per room',
      () async {
    var now = DateTime(2026, 11, 5), calls = 0;
    final room = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        clock: () => now,
        fetch: () {
          calls++;
          throw StateError('offline');
        });
    await room.load();
    expect(room.retryIfDue(), isNull);
    now = now.add(const Duration(seconds: 2));
    await room.retryIfDue();
    expect(calls, 2);
    now = now.add(const Duration(seconds: 4));
    await room.retryIfDue();
    expect(calls, 3);
    now = now.add(const Duration(minutes: 10));
    expect(room.retryIfDue(), isNull);
    room.dispose();
  });
  test('synchronous catalog failure can be retried', () async {
    var calls = 0;
    final room = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        fetch: () {
          calls++;
          throw StateError('offline');
        });
    await room.load();
    await room.load();
    expect(calls, 2);
    room.dispose();
  });
  test(
      'catalog is single flight and enriches raw text without replacing native images',
      () async {
    final reply = Completer<List<LiveEmoticon>>();
    var calls = 0, changes = 0;
    final room = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        fetch: () {
          calls++;
          return reply.future;
        });
    room.addListener(() => changes++);
    final a = room.load(), b = room.load();
    final native = LiveEmoticon(text: '[看]', url: 'https://native.example/x');
    final msg = LiveMessage(
        type: LiveMessageType.chat,
        userName: 'u',
        message: '[看]',
        color: LiveMessageColor.white,
        parts: [LiveMessagePart.image(native)]);
    reply.complete(
        [const LiveEmoticon(text: '[看]', url: 'https://catalog.example/x')]);
    await Future.wait([a, b]);
    expect(calls, 1);
    expect(changes, 1);
    expect(room.resolve(msg).single.emoticon!.url, native.url);
    room.dispose();
  });
  test('late reply from disposed room is ignored', () async {
    final reply = Completer<List<LiveEmoticon>>();
    var changes = 0;
    final room =
        RoomEmoticons(platform: 'test', roomId: '1', fetch: () => reply.future);
    room.addListener(() => changes++);
    final pending = room.load();
    room.dispose();
    reply.complete(
        [const LiveEmoticon(text: '[看]', url: 'https://cdn.example/x')]);
    await pending;
    expect(changes, 0);
  });
  test(
      'offline directory preserves official bundled seeds and allows later retry',
      () async {
    var calls = 0;
    final room = RoomEmoticons(
        platform: 'douyin',
        roomId: '1',
        fetch: () async {
          calls++;
          throw StateError('offline');
        });
    await room.load();
    await room.load();
    final msg = LiveMessage(
        type: LiveMessageType.chat,
        userName: 'u',
        message: '[微笑]',
        color: LiveMessageColor.white);
    expect(room.resolve(msg).single.emoticon, isNotNull);
    expect(calls, 2);
    room.dispose();
  });
  test('斗鱼 gag image keeps actual text as the failure label', () async {
    final room = RoomEmoticons(
        platform: 'test',
        roomId: '1',
        fetch: () async => [
              const LiveEmoticon(
                  text: '[gag:197]',
                  url: 'https://cdn.example/x',
                  width: 266,
                  height: 64)
            ]);
    await room.load();
    final msg = LiveMessage(
        type: LiveMessageType.chat,
        userName: 'u',
        message: '泰裤辣',
        emoticonKey: '[gag:197]',
        color: LiveMessageColor.white);
    expect(room.resolve(msg).single.text, '泰裤辣');
    expect(room.resolve(msg).single.emoticon!.aspectRatio,
        closeTo(266 / 64, 0.01));
    room.dispose();
  });
}
