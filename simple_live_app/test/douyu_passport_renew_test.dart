import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// 按 URI 返回预置响应；requests 记录实际发生的跳转链
class _ChainAdapter implements HttpClientAdapter {
  _ChainAdapter(this.handler);

  final ResponseBody Function(Uri uri) handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options.uri);
  }
}

ResponseBody _redirect(String location) {
  return ResponseBody.fromString(
    '',
    302,
    headers: {
      'location': [location],
    },
  );
}

ResponseBody _ok(String body, {List<String>? setCookie}) {
  return ResponseBody.fromString(
    body,
    200,
    headers: {
      if (setCookie != null) 'set-cookie': setCookie,
    },
  );
}

String _jwt({required int exp}) {
  final payload =
      base64Url.encode(utf8.encode('{"exp":$exp}')).replaceAll('=', '');
  return 'eyJhbGciOiJub25lIn0.$payload.sig';
}

Dio _dioWith(_ChainAdapter adapter) => Dio()..httpClientAdapter = adapter;

bool _isSafeAuth(Uri uri) =>
    uri.host == 'passport.douyu.com' &&
    uri.path == '/lapi/passport/iframe/safeAuth';

void main() {
  group('DouyuPassport.refreshPlayCookie', () {
    test('follows the safeAuth 302 and keeps cookies from every hop', () async {
      final adapter = _ChainAdapter((uri) {
        if (_isSafeAuth(uri)) {
          return _redirect(
            '//www.douyu.com/api/passport/login?code=abc&loginType=safeAuth',
          );
        }
        if (uri.host == 'www.douyu.com') {
          return _ok(
            'axiosJsonpCallback({"error":0})',
            setCookie: [
              'acf_uid=12345; Path=/; Domain=.douyu.com',
              'acf_auth=authvalue; Path=/; Domain=.douyu.com',
              'acf_jwt_token=${_jwt(exp: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600)}; Path=/',
            ],
          );
        }
        throw DioException(
          requestOptions: RequestOptions(path: uri.toString()),
          type: DioExceptionType.badResponse,
        );
      });

      final cookie = await DouyuPassport.refreshPlayCookie(
        dyDid: 'did-value',
        ltp0: 'ltp0-value',
        dio: _dioWith(adapter),
      );

      expect(cookie, contains('acf_uid=12345'));
      expect(cookie, contains('acf_auth=authvalue'));
      expect(cookie, contains('acf_jwt_token='));
      expect(adapter.requests, hasLength(2));
      for (final request in adapter.requests) {
        expect(request.headers['Cookie'], contains('LTP0=ltp0-value'));
        expect(request.headers['Cookie'], contains('dy_did=did-value'));
      }
    });

    test('accepts acf_* cookies without an acf_jwt_token', () async {
      final adapter = _ChainAdapter((uri) {
        if (_isSafeAuth(uri)) {
          return _ok(
            'axiosJsonpCallback({"error":0})',
            setCookie: [
              'acf_uid=777; Path=/',
              'acf_auth=authtoken; Path=/',
            ],
          );
        }
        throw DioException(requestOptions: RequestOptions(path: uri.toString()));
      });

      final cookie = await DouyuPassport.refreshPlayCookie(
        dyDid: 'did',
        ltp0: 'ltp0',
        dio: _dioWith(adapter),
      );

      expect(cookie, contains('acf_uid=777'));
      expect(cookie, contains('acf_auth=authtoken'));
    });

    test('throws when the chain returns no usable cookie', () async {
      final adapter = _ChainAdapter((uri) {
        return _ok('axiosJsonpCallback({"error":1,"msg":"未登录"})');
      });

      await expectLater(
        DouyuPassport.refreshPlayCookie(
          dyDid: 'did',
          ltp0: 'ltp0',
          dio: _dioWith(adapter),
        ),
        throwsA(isA<CoreError>()),
      );
    });

    test('rejects an expired acf_jwt_token', () async {
      final adapter = _ChainAdapter((uri) {
        return _ok(
          'axiosJsonpCallback({"error":0})',
          setCookie: [
            'acf_uid=1; Path=/',
            'acf_jwt_token=${_jwt(exp: 1)}; Path=/',
          ],
        );
      });

      await expectLater(
        DouyuPassport.refreshPlayCookie(
          dyDid: 'did',
          ltp0: 'ltp0',
          dio: _dioWith(adapter),
        ),
        throwsA(isA<CoreError>()),
      );
    });

    test('refuses to follow a redirect outside douyu', () async {
      final adapter = _ChainAdapter((uri) {
        return _redirect('https://evil.example/steal');
      });

      await expectLater(
        DouyuPassport.refreshPlayCookie(
          dyDid: 'did',
          ltp0: 'ltp0',
          dio: _dioWith(adapter),
        ),
        throwsA(isA<CoreError>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  });
}
