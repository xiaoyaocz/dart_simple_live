import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:test/test.dart';

void main() {
  late Dio original;
  var pageCount = 0;
  var count = 40;
  var error = 0;
  final pages = <int>[];
  setUp(() {
    CoreLog.enableLog = false;
    original = HttpClient.instance.dio;
    pageCount = 0;
    count = 40;
    error = 0;
    pages.clear();
    HttpClient.instance.dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final page = int.parse(options.uri.pathSegments.last);
            pages.add(page);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'error': error,
                  // Live endpoint returns pgcnt=0 even with distinct, full next pages.
                  'data': {
                    'pgcnt': pageCount,
                    'rl': List.generate(
                      count,
                      (i) => {
                        'type': 1,
                        'rid': page * 100 + i,
                        'rs16': 'cover',
                        'ol': 100,
                        'rn': 'room',
                        'nn': 'anchor',
                      },
                    ),
                  },
                },
              ),
            );
          },
        ),
      );
  });
  tearDown(() {
    HttpClient.instance.dio.close();
    HttpClient.instance.dio = original;
  });
  test('pgcnt为0不是末页，后续页面继续返回不同房间', () async {
    final site = DouyuSite();
    final first = await site.getRecommendRooms();
    final second = await site.getRecommendRooms(page: 2);
    expect(first.hasMore, isTrue);
    expect(second.hasMore, isTrue);
    expect(first.items.length, 40);
    expect(second.items.first.roomId, '200');
    expect(pages, [1, 2]);
  });
  test('明确总页数时仍尊重末页', () async {
    pageCount = 2;
    expect((await DouyuSite().getRecommendRooms(page: 2)).hasMore, isFalse);
  });
  test('无总页数且空页时结束', () async {
    count = 0;
    expect((await DouyuSite().getRecommendRooms()).hasMore, isFalse);
  });
  test('业务错误不是正常末页', () async {
    error = 1;
    await expectLater(DouyuSite().getRecommendRooms(), throwsA(anything));
  });
}
