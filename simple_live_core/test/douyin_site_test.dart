import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('DouyinCookieHelper.extractTtwid', () {
    test('extracts only ttwid from a complete Cookie header', () {
      expect(
        DouyinCookieHelper.extractTtwid(
          'sessionid=fake-session; ttwid=playback-token; msToken=fake-token',
        ),
        'ttwid=playback-token',
      );
    });

    test('accepts copied header text and ignores missing ttwid', () {
      expect(
        DouyinCookieHelper.extractTtwid(
          'Accept: application/json\nCookie: ttwid=from-header; sid_guard=x',
        ),
        'ttwid=from-header',
      );
      expect(DouyinCookieHelper.extractTtwid('sessionid=fake-session'), isNull);
    });
  });

  group('DouyinSite request headers', () {
    test(
      'uses a fresh minimal Cookie for playback and the full Cookie for search',
      () async {
        final site = DouyinSite()
          ..cookie =
              'sessionid=fake-session; ttwid=playback-token; msToken=fake-token';

        final playbackHeaders = await site.getRequestHeaders();
        expect(playbackHeaders['cookie'], 'ttwid=playback-token');
        expect(playbackHeaders['cookie'], isNot(contains('sessionid')));
        playbackHeaders['Referer'] = 'https://invalid.example';

        final nextPlaybackHeaders = await site.getRequestHeaders();
        expect(nextPlaybackHeaders['Referer'], DouyinSite.kDefaultReferer);

        final searchHeaders = await site.getRequestHeaders(
          includeFullCookie: true,
        );
        expect(searchHeaders['cookie'], contains('sessionid=fake-session'));
        expect(searchHeaders['cookie'], contains('ttwid=playback-token'));
      },
    );

    test(
      'uses the anonymous default when the custom Cookie has no ttwid',
      () async {
        final site = DouyinSite()..cookie = 'sessionid=fake-session';

        final playbackHeaders = await site.getRequestHeaders();
        expect(playbackHeaders['cookie'], startsWith('ttwid='));
        expect(playbackHeaders['cookie'], isNot(contains('sessionid')));
      },
    );
  });
}
