import 'dart:convert';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

/// 构造一个带 acf_jwt_token 的假播放 Cookie，JWT exp 可控
String buildCookie({required int expSecondsSinceEpoch}) {
  String encodePayload(Map payload) {
    final normalized = base64Url.encode(utf8.encode(json.encode(payload)));
    return normalized.replaceAll('=', '');
  }

  final jwt = '${encodePayload({'alg': 'none'})}.'
      '${encodePayload({'exp': expSecondsSinceEpoch})}.sig';
  return 'dy_did=1234567890abcdef1234567890abcdef; '
      'acf_did=1234567890abcdef1234567890abcdef; '
      'acf_jwt_token=$jwt; LTP0=renewal-ltp0-token';
}

void main() {
  test('isCookieExpired detects expired and valid jwt', () {
    final expired = buildCookie(
      expSecondsSinceEpoch:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
    );
    final valid = buildCookie(
      expSecondsSinceEpoch:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
    expect(DouyuPassport.isCookieExpired(expired), isTrue);
    expect(DouyuPassport.isCookieExpired(valid), isFalse);
  });

  test('isCookieExpired treats missing or malformed jwt as expired', () {
    expect(DouyuPassport.isCookieExpired('dy_did=abc'), isTrue);
    expect(DouyuPassport.isCookieExpired('acf_jwt_token=not-a-jwt'), isTrue);
    expect(DouyuPassport.isCookieExpired(''), isTrue);
  });

  test('cookiesFromSetCookie joins name=value pairs from set-cookie', () {
    final cookie = DouyuPassport.cookiesFromSetCookie([
      'acf_jwt_token=abc.def.ghi; Path=/; HttpOnly',
      'dy_did=1234; Domain=.douyu.com; Max-Age=31536000',
      'invalid-cookie-without-value',
    ]);
    expect(cookie, 'acf_jwt_token=abc.def.ghi; dy_did=1234');
  });

  test('cookieValue extracts credentials from cookie string', () {
    final cookie = buildCookie(
      expSecondsSinceEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    expect(DouyuPassport.cookieValue(cookie, 'LTP0'), 'renewal-ltp0-token');
    expect(DouyuPassport.cookieValue(cookie, 'ltp0'), 'renewal-ltp0-token');
    expect(
      DouyuPassport.cookieValue(cookie, 'dy_did'),
      '1234567890abcdef1234567890abcdef',
    );
    expect(DouyuPassport.cookieValue(cookie, 'acf_uid'), '');
  });
}
