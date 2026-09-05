import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test('builds server Kww from the kwfv1 cookie', () {
    expect(
      KuaishouSite.resolveServerKww('did=1; kwfv1=abc%2B123', 'fallback'),
      'abc+123###ssrc',
    );
    expect(KuaishouSite.resolveServerKww('did=1', 'fallback'), 'fallback');
  });
  test('decodes Kuaishou comment feed', () {
    final messages = <LiveMessage>[];
    final danmaku = KuaishouDanmaku()..onMessage = messages.add;

    danmaku.decodeMessage(_socketMessage(_feedPush(), compressionType: 0));

    expect(messages, hasLength(1));
    expect(messages.single.type, LiveMessageType.chat);
    expect(messages.single.userName, '测试用户');
    expect(messages.single.message, '测试弹幕');
    expect(messages.single.color.toString(), '#ff6600');
  });

  test('decodes gzip-compressed Kuaishou comment feed', () {
    final messages = <LiveMessage>[];
    final danmaku = KuaishouDanmaku()..onMessage = messages.add;

    danmaku.decodeMessage(_socketMessage(_feedPush(), compressionType: 2));

    expect(messages.single.message, '测试弹幕');
  });
}

Uint8List _feedPush() {
  final user = _ProtoWriter()..writeString(2, '测试用户');
  final comment = _ProtoWriter()
    ..writeBytes(2, user.takeBytes())
    ..writeString(3, '测试弹幕')
    ..writeString(6, '#ff6600');
  return (_ProtoWriter()..writeBytes(5, comment.takeBytes())).takeBytes();
}

Uint8List _socketMessage(Uint8List feedPush, {required int compressionType}) {
  final payload = compressionType == 2 ? gzip.encode(feedPush) : feedPush;
  final writer = _ProtoWriter()..writeVarint(1, 310);
  if (compressionType != 0) {
    writer.writeVarint(2, compressionType);
  }
  writer.writeBytes(3, payload);
  return writer.takeBytes();
}

class _ProtoWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void writeVarint(int fieldNumber, int value) {
    _writeValue(fieldNumber << 3);
    _writeValue(value);
  }

  void writeString(int fieldNumber, String value) {
    writeBytes(fieldNumber, utf8.encode(value));
  }

  void writeBytes(int fieldNumber, List<int> value) {
    _writeValue((fieldNumber << 3) | 2);
    _writeValue(value.length);
    _builder.add(value);
  }

  void _writeValue(int value) {
    var current = value;
    while (current >= 0x80) {
      _builder.addByte((current & 0x7f) | 0x80);
      current >>= 7;
    }
    _builder.addByte(current);
  }

  Uint8List takeBytes() => _builder.takeBytes();
}
