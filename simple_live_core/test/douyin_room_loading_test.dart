import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/core_error.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:test/test.dart';

// 仅替换外部 HTTP 响应，保留房间请求、Cookie 和页面解析的真实调用链。
void mockHttp(Response<dynamic> Function(RequestOptions) respond) {
  HttpClient.instance.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(respond(options));
      },
    ),
  );
}

const roomState =
    r'{"state":{"appStore":{},"roomStore":{"roomInfo":{"room":{"id_str":"123","status":2,"title":"测试直播"},"partition_road_map":{"partition":{"id_str":"100","type":1,"title":"游戏"},"sub_partition":{"partition":{"id_str":"200","type":2,"title":"射击"}}}}}}}';

String roomPage(String state) =>
    '<script>self.__next_f.push([1,${jsonEncode('7:$state\n')}])</script>';

Response<dynamic> response(
  RequestOptions options,
  dynamic data, {
  Map<String, List<String>>? headers,
}) => Response(
  requestOptions: options,
  statusCode: 200,
  data: data,
  headers: Headers.fromMap(headers ?? {}),
);

class _AccountRoom extends DouyinSite {
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    calls++;
    await gate.future;
    return LiveRoomDetail(roomId: webRid, title: '', cover: '', userName: '',
        userAvatar: '', online: 0, status: false, url: '');
  }
}

void main() {
  test('账号改变后不共享上一账号仍在进行的详情请求', () async {
    final site = _AccountRoom()..cookie = 'a';
    final first = site.getRoomDetail(roomId: '123');
    site.cookie = 'b';
    final second = site.getRoomDetail(roomId: '123');
    expect(site.calls, 2);
    site.gate.complete();
    await Future.wait([first, second]);
  });
  late Dio original;
  setUp(() {
    CoreLog.enableLog = false;
    original = HttpClient.instance.dio;
    HttpClient.instance.dio = Dio();
  });
  tearDown(() {
    HttpClient.instance.dio.close();
    HttpClient.instance.dio = original;
  });

  test('读取完整 Next 数据对象，不依赖旧正则的尾部数组格式', () async {
    mockHttp(
      (options) => response(
        options,
        options.method == 'HEAD' ? '' : roomPage(roomState),
      ),
    );
    final category = await DouyinSite().getRoomGameCategory('557481980778');
    expect(category?.id, '200,2');
    expect(category?.parentId, '100,1');
    expect(category?.name, '射击');
  });

  test('数据字符串内的括号和转义字符不截断房间对象', () async {
    final state = roomState.replaceFirst('测试直播', r'标题 } ] \" 直播');
    mockHttp(
      (options) =>
          response(options, options.method == 'HEAD' ? '' : roomPage(state)),
    );
    expect(
      (await DouyinSite().getRoomGameCategory('557481980778'))?.id,
      '200,2',
    );
  });

  test('读取页面实际使用的 pace 数据通道', () async {
    mockHttp(
      (options) => response(
        options,
        options.method == 'HEAD'
            ? ''
            : roomPage(roomState).replaceAll('__next_f', '__pace_f'),
      ),
    );
    expect(
      (await DouyinSite().getRoomGameCategory('557481980778'))?.id,
      '200,2',
    );
  });

  test('HEAD 未发放 Cookie 时网页请求仍保留已有账号会话', () async {
    final site = DouyinSite()..cookie = 'ttwid=user; sessionid=account';
    mockHttp((options) {
      if (options.method == 'HEAD') return response(options, '');
      expect(options.headers['Cookie'], contains('ttwid=user'));
      expect(options.headers['Cookie'], contains('sessionid=account'));
      return response(options, roomPage(roomState));
    });
    expect((await site.getRoomGameCategory('557481980778'))?.id, '200,2');
  });

  test('HEAD 新会话与已有账号 Cookie 合并，不带入响应属性', () async {
    final site = DouyinSite()..cookie = 'ttwid=old; sessionid=account';
    mockHttp((options) {
      if (options.method == 'HEAD') {
        return response(
          options,
          '',
          headers: {
            'set-cookie': [
              'ttwid=fresh; Path=/; HttpOnly',
              '__ac_nonce=nonce; Path=/',
              'other=ignored',
            ],
          },
        );
      }
      expect(options.headers['Cookie'], contains('ttwid=fresh'));
      expect(options.headers['Cookie'], contains('sessionid=account'));
      expect(options.headers['Cookie'], contains('__ac_nonce=nonce'));
      expect(options.headers['Cookie'], isNot(contains('Path=')));
      expect(options.headers['Cookie'], isNot(contains('other=')));
      return response(options, roomPage(roomState));
    });
    expect((await site.getRoomGameCategory('557481980778'))?.id, '200,2');
  });

  test('验证页面不交给 JSON 解码，返回可识别的房间数据错误', () async {
    mockHttp((options) => response(options, '<html>captcha 验证页面</html>'));
    await expectLater(
      DouyinSite().getRoomGameCategory('557481980778'),
      throwsA(isA<CoreError>()),
    );
  });

  test('网页兜底也失败时保留接口的原始错误码', () async {
    HttpClient.instance.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.path == '/webcast/room/web/enter/') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: options, statusCode: 503),
              ),
            );
          } else {
            handler.resolve(response(options, '<html>captcha</html>'));
          }
        },
      ),
    );
    await expectLater(
      DouyinSite().getRoomDetailByWebRid('557481980778'),
      throwsA(isA<CoreError>().having((e) => e.statusCode, '原始错误码', 503)),
    );
  });

  test('明确的请求错误不重复整个房间加载流程', () async {
    final site = _PermanentFailureSite();
    await expectLater(
      site.getRoomDetail(roomId: '557481980778'),
      throwsA(isA<CoreError>()),
    );
    expect(site.attempts, 1);
  });
}

class _PermanentFailureSite extends DouyinSite {
  var attempts = 0;
  @override
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    attempts++;
    throw CoreError('错误的请求', statusCode: 400);
  }
}
