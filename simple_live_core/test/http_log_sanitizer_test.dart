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
}
