import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/common/core_error.dart';
import 'package:test/test.dart';

void main() {
  late Dio original;
  final requests = <RequestOptions>[];
  var primary = '<!DOCTYPE html><html>房间已关闭</html>';
  var resolvedId = '5526219';
  var live = 2;
  setUp(() {
    CoreLog.enableLog = false;
    requests.clear();
    primary = '<!DOCTYPE html><html>房间已关闭</html>';
    resolvedId = '5526219';
    live = 2;
    original = HttpClient.instance.dio;
    HttpClient.instance.dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            dynamic data;
            if (request.uri.path == '/betard/123455') {
              data = primary;
            } else if (request.uri.host == 'm.douyu.com') {
              data =
                  '<script id="vike_pageContext" type="application/json">${jsonEncode({
                    'pageProps': {
                      'room': {
                        'roomInfo': {
                          'roomInfo': {'rid': resolvedId},
                        },
                      },
                    },
                  })}</script>';
            } else if (request.uri.path == '/betard/5526219') {
              data = {
                'room': {
                  'room_id': 5526219,
                  'room_name': '测试房间',
                  'owner_name': '测试主播',
                  'show_status': live,
                  'videoLoop': 0,
                  'room_biz_all': {'hot': '10'},
                },
              };
            } else if (request.uri.path == '/swf_api/h5room/5526219') {
              data = {
                'error': 0,
                'data': {'show_time': '0'},
              };
            } else if (request.uri.path == '/swf_api/homeH5Enc') {
              // Deliberately unavailable signing data: no native JS runtime in unit tests.
              data = '{"error":0,"data":{}}';
            }
            if (data == null) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  error: 'Unexpected request',
                ),
              );
            } else {
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            }
          },
        ),
      );
  });
  tearDown(() {
    HttpClient.instance.dio.close();
    HttpClient.instance.dio = original;
  });

  test(
    'VIP alias with an HTML API response resolves the real room ID',
    () async {
      final detail = await DouyuSite().getRoomDetail(roomId: '123455');
      expect(detail.roomId, '5526219');
      expect(detail.userName, '测试主播');
      expect(detail.status, isFalse);
      expect(requests.map((r) => r.uri.path), [
        '/betard/123455',
        '/123455',
        '/betard/5526219',
      ]);
    },
  );
  test(
    'live alias uses canonical ID for both H5 and signing requests',
    () async {
      live = 1;
      await expectLater(
        DouyuSite().getRoomDetail(roomId: '123455'),
        throwsA(
          isA<CoreError>().having((e) => e.message, 'message', contains('签名')),
        ),
      );
      expect(
        requests.where((r) => r.uri.path.contains('h5room')).single.uri.path,
        '/swf_api/h5room/5526219',
      );
      expect(
        requests
            .where((r) => r.uri.path.endsWith('homeH5Enc'))
            .single
            .uri.queryParameters['rids'],
        '5526219',
      );
    },
  );
  test(
    'unresolvable HTML response is a readable room error, not a JSON crash',
    () async {
      resolvedId = '123455';
      await expectLater(
        DouyuSite().getRoomDetail(roomId: '123455'),
        throwsA(isA<CoreError>()),
      );
      expect(requests.length, 2);
    },
  );
  test('a valid canonical room response needs no fallback page', () async {
    primary = jsonEncode({
      'room': {'room_id': 5526219, 'show_status': 2, 'videoLoop': 0},
    });
    expect(
      (await DouyuSite().getRoomDetail(roomId: '123455')).roomId,
      '5526219',
    );
    expect(requests.length, 1);
  });
}
