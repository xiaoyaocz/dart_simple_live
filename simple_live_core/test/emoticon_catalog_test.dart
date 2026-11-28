import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/danmaku/platform_emoticons.dart';
import 'package:simple_live_core/src/danmaku/huya_emoticons.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';

void main() {
  test('真实虎牙公开目录 TUP3 响应可完整解析', () {
    final data=File('test/fixtures/huya-emoticons-public-20261105.bin').readAsBytesSync();
    final items=HuyaEmoticons.parse(data);
    expect(items.length,180);
    final c=EmoticonCatalog(items);
    for(final text in ['[666]','/{66','[滑稽]']) {
      expect(c.split(text).single.emoticon!.url,startsWith('https://'));
    }
  });
  test('抖音 official emoji_list and URL variants', () {
    final c = EmoticonCatalog(
      PlatformEmoticons.parseDouyin({
        'emoji_list': [
          {
            'display_name': '[看]',
            'emoji_url': {
              'url_list': ['bad', 'https://cdn.example/a.webp'],
            },
          },
        ],
      }),
    );
    expect(c.split('[看]').single.emoticon!.url, 'https://cdn.example/a.webp');
  });
  test('斗鱼 room config and image message IDs', () {
    final data = {
      'pageProps': {
        'room': {
          'faceInfo': {
            'faceConfig': [
              {'title': '胖头跳舞', 'url1': 'https://cdn.example/a.webp'},
            ],
            'genDanmuConfig': [
              {
                'msgId': 197,
                'name': '泰裤辣',
                'webPic': 'https://cdn.example/b.png',
                'webPicWidth': 266,
                'webPicHeight': 64,
              },
            ],
          },
        },
      },
    };
    final c = EmoticonCatalog(
      PlatformEmoticons.parseDouyuPage(
        '<script id="vike_pageContext" type="application/json">${jsonEncode(data)}</script>',
      ),
    );
    expect(c.split('[胖头跳舞]').single.emoticon, isNotNull);
    expect(c.split('[emot:dy胖头跳舞]').single.emoticon, isNotNull);
    expect(
      c.split('[gag:197]').single.emoticon!.aspectRatio,
      closeTo(266 / 64, 0.01),
    );
  });
  test('B站 all packs, not only first or entitled emojis', () {
    final list = PlatformEmoticons.parseBilibili({
      'data': {
        'data': [
          {
            'emoticons': [
              {'emoji': '[看]', 'url': '//cdn.example/a.png'},
            ],
          },
          {
            'emoticons': [
              {'emoji': '[会员]', 'url': 'https://cdn.example/b.gif'},
            ],
          },
        ],
      },
    }).toList();
    expect(list.map((e) => e.text), ['[看]', '[会员]']);
  });
  test(
    'catalog failure is bounded and does not become a successful empty cache',
    () async {
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            calls++;
            h.resolve(Response(requestOptions: r, data: {'code': -101}));
          },
        ),
      );
      final loader = PlatformEmoticons(dio: dio);
      await expectLater(
        loader.load('bilibili', '6'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        loader.load('bilibili', '6'),
        throwsA(isA<StateError>()),
      );
      expect(calls, 2);
    },
  );
  test('Huya WUP request uses actual presenter UID and TUP3 map', () {
    final bytes = HuyaEmoticons.request(presenterUid: 12345);
    expect(ByteData.sublistView(bytes).getInt32(0), bytes.length);
    final input = TarsInputStream(bytes, pos: 4);
    expect(input.read(0, 1, true), 3);
    expect(input.read('', 5, true), 'wupui');
    expect(input.read('', 6, true), 'getExpressionEmoticonPackage');
    final body = input.readBytes(7, true);
    final params = TarsInputStream(
      body,
    ).readMap<String, Uint8List>({'': Uint8List(0)}, 0, true);
    expect(params.containsKey('tReq'), isTrue);
    // Decode nested struct boundary then skip tId to presenter.
    final req = TarsInputStream(params['tReq']);
    final head = HeadData();
    req.readHead(head);
    expect(req.read(0, 1, true), 12345);
  });
}
