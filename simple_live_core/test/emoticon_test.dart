import 'dart:convert';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import 'package:test/test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/danmaku/emoticon_parser.dart';
import 'package:simple_live_core/src/danmaku/proto/douyin.pb.dart' as dy;

void main() {
  test('B站 websocket parser delivers native image parts to the app', () {
    LiveMessage? received;
    final dm = BiliBiliDanmaku()..onMessage = (m) => received = m;
    dm.parseMessage(
      jsonEncode({
        'cmd': 'DANMU_MSG',
        'info': [
          [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            {},
            {'url': 'https://cdn.example/native.png'},
          ],
          '[会员表情]',
          [1, '用户'],
        ],
      }),
    );
    expect(received, isNotNull);
    expect(received!.userId, '1');
    expect(
      received!.parts.single.emoticon!.url,
      'https://cdn.example/native.png',
    );
  });
  test('斗鱼 websocket parser delivers gag ID without losing original text', () {
    LiveMessage? received;
    final dm = DouyuDanmaku()..onMessage = (m) => received = m;
    dm.decodeMessage(
      dm.serializeDouyu('type@=chatmsg/dms@=1/uid@=123/nn@=u/txt@=hello/gag@=197/'),
    );
    expect(received, isNotNull);
    expect(received!.message, 'hello');
    expect(received!.userId, '123');
    expect(received!.emoticonKey, '[gag:197]');
  });
  test('截图中的抖音表情均映射原图，大小写不丢原文', () {
    final catalog = EmoticonCatalog(emoticonSeeds('douyin'));
    for (final label in ['[打call]', '[打Call]', '[看]', '[杀马特]']) {
      final p = catalog.split(label).single;
      expect(p.emoticon, isNotNull, reason: label);
      expect(p.text, label);
    }
  });
  test('抖音 independent emoji chat event preserves image and sender', () {
    final image = dy.Image()
      ..urlListList.add('https://cdn.example/emote.gif')
      ..content = (dy.ImageContent()..alternativeText = '[看]');
    final text = dy.Text()
      ..piecesList.add(
        dy.TextPiece()..imageValue = (dy.TextPieceImage()..image = image),
      );
    final writer = CodedBufferWriter()
      ..writeField(
        2,
        PbFieldType.OY,
        (dy.User()..nickName = '主播'..idStr = '9007199254740993').writeToBuffer(),
      )
      ..writeField(4, PbFieldType.OY, text.writeToBuffer())
      ..writeField(5, PbFieldType.OS, '[看]');
    final msg = EmoticonParser.douyinEmoji(writer.toBuffer())!;
    expect(msg.userName, '主播');
    expect(msg.userId, '9007199254740993');
    expect(msg.parts.single.emoticon!.url, endsWith('emote.gif'));
    expect(msg.message, '[看]');
  });
  test('plain and unknown bracket text survives unchanged', () {
    final parts = EmoticonCatalog().split('你好[未知]🙂');
    expect(parts.map((e) => e.text).join(), '你好[未知]🙂');
    expect(parts.every((e) => e.emoticon == null), isTrue);
  });
  test('longest literal match, repeats and ordering', () {
    final c = EmoticonCatalog([
      LiveEmoticon(text: '[看]', url: 'https://cdn.example/a.png'),
      LiveEmoticon(text: '[看][看]', url: 'https://cdn.example/b.gif'),
    ]);
    final p = c.split('a[看][看]b[看]');
    expect(p.map((e) => e.text).toList(), ['a', '[看][看]', 'b', '[看]']);
    expect(p[1].emoticon!.url, endsWith('b.gif'));
  });
  test('reject unsafe and malformed URLs, normalize protocol relative', () {
    expect(LiveEmoticon.normalizeUrl('javascript:alert(1)'), isNull);
    expect(LiveEmoticon.normalizeUrl('file:///c:/x.png'), isNull);
    expect(LiveEmoticon.normalizeUrl('https:///x'), isNull);
    expect(
      LiveEmoticon.normalizeUrl('//cdn.example/a.png'),
      'https://cdn.example/a.png',
    );
  });
  test('B站 whole-message and mixed extra emots metadata', () {
    final info = [
      [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        {'url': '//cdn.example/whole.png', 'width': 200, 'height': 100},
        {
          'extra': jsonEncode({
            'emots': {
              '[打call]': {
                'url': 'https://cdn.example/call.gif',
                'width': 40,
                'height': 40,
              },
            },
          }),
        },
      ],
      '[打call]',
    ];
    final p = EmoticonParser.bilibili(info, '[打call]');
    expect(p.single.emoticon!.url, endsWith('whole.png'));
    expect(p.single.emoticon!.aspectRatio, 2);
    (info[0] as List)[12] = {};
    expect(
      EmoticonParser.bilibili(info, 'a[打call]')[1].emoticon!.url,
      endsWith('call.gif'),
    );
  });
  test('B站 malformed extra never loses the message', () {
    expect(
      EmoticonParser.bilibili([
        [
          {'extra': 'bad'},
        ],
      ], '[看]').single.text,
      '[看]',
    );
  });
  test('抖音 rich text preserves ordered inline images, not user badges', () {
    final image = dy.Image()
      ..urlListList.add('https://cdn.example/watch.webp')
      ..width = Int64(30)
      ..height = Int64(30)
      ..content = (dy.ImageContent()..alternativeText = '[看]');
    final rich = dy.Text()
      ..piecesList.addAll([
        dy.TextPiece()..stringValue = '你好',
        dy.TextPiece()..imageValue = (dy.TextPieceImage()..image = image),
      ]);
    final m = dy.ChatMessage()
      ..content = '你好[看]'
      ..rtfContent = rich;
    final p = EmoticonParser.douyin(m);
    expect(p.map((e) => e.text).join(), '你好[看]');
    expect(p[1].emoticon!.url, endsWith('watch.webp'));
  });
  test('message keeps raw text while exposing immutable rich parts', () {
    final parts = [LiveMessagePart.text('原文')];
    final m = LiveMessage(
      type: LiveMessageType.chat,
      userName: 'u',
      message: '原文',
      color: LiveMessageColor.white,
      parts: parts,
    );
    parts.clear();
    expect(m.parts.single.text, '原文');
    expect(() => m.parts.clear(), throwsUnsupportedError);
  });
}
