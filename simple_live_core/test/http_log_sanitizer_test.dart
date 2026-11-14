import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test('redacts sensitive map keys recursively', () {
    final value = HttpLogSanitizer.redact({
      'headers': {'Cookie': 'sessionid=private', 'X-Trace': 'visible'},
      'items': [
        {'token': 'private-token'},
      ],
    });

    expect(value['headers']['Cookie'], '<redacted>');
    expect(value['headers']['X-Trace'], 'visible');
    expect(value['items'].single['token'], '<redacted>');
  });

  test('redacts sensitive query parameters and error text', () {
    final uri = Uri.parse('https://example.test/live?token=private&id=42');
    expect(HttpLogSanitizer.redactUri(uri), contains('token=%3Credacted%3E'));
    expect(HttpLogSanitizer.redactUri(uri), contains('id=42'));

    final text = HttpLogSanitizer.redactText(
      'GET https://example.test/live?token=private Cookie: sid=private',
      requestUri: uri,
    );
    expect(text, isNot(contains('private')));
    expect(text, contains('token=<redacted>'));
  });

  test('redacts douyu ltp0 credential in text', () {
    final text = HttpLogSanitizer.redactText(
      'POST safeAuth cookie: dy_did=abc;LTP0=secret-ltp0-value',
    );
    expect(text, isNot(contains('secret-ltp0-value')));
    expect(text, contains('cookie=<redacted>'));
  });

  test('redacts standalone ltp0 key-value pair', () {
    final text = HttpLogSanitizer.redactText(
      'Passport response LTP0=secret-ltp0-value; acf_uid=42',
    );
    expect(text, isNot(contains('secret-ltp0-value')));
    expect(text, contains('LTP0=<redacted>'));
    expect(text, contains('acf_uid=42'));
  });
}
