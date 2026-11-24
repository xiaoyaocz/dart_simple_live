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

  group('DouyinSite.resolveCategoryInfo', () {
    test(
      'reads sibling partition_road_map Map and game_tag_info when sub title is empty',
      () {
        final container = {
          'partition_road_map': {
            'partition': {'id_str': '2', 'type': 1, 'title': '竞技游戏'},
            'sub_partition': {
              'partition': {'id_str': '1010235', 'type': 1, 'title': ''},
            },
          },
        };
        final room = {
          'id_str': '760000000000',
          'game_data': {
            'game_tag_info': {
              'is_game': 1,
              'game_tag_id': 1010235,
              'game_tag_name': '王者万象棋',
            },
          },
        };

        final info = DouyinSite.resolveCategoryInfo(room, container: container);
        expect(info['categoryId'], '1010235,1');
        expect(info['categoryName'], '王者万象棋');
        expect(info['categoryParentId'], '2,1');
        expect(info['categoryParentName'], '竞技游戏');
        expect(info['categoryPic'], isNull);
      },
    );

    test(
      'uses game_tag_info under top partition when sub_partition is absent',
      () {
        final container = {
          'partition_road_map': {
            'partition': {'id_str': '2', 'type': 1, 'title': '竞技游戏'},
          },
        };
        final room = {
          'game_data': {
            'game_tag_info': {
              'is_game': 1,
              'game_tag_id': 1010235,
              'game_tag_name': '王者万象棋',
            },
          },
        };

        final info = DouyinSite.resolveCategoryInfo(room, container: container);
        expect(info['categoryId'], '1010235,1');
        expect(info['categoryName'], '王者万象棋');
        expect(info['categoryParentId'], '2,1');
        expect(info['categoryParentName'], '竞技游戏');
        expect(info['categoryPic'], isNull);
      },
    );

    test(
      'keeps top partition without duplicating parent on non-game rooms',
      () {
        final container = {
          'partition_road_map': {
            'partition': {'id_str': '1', 'type': 1, 'title': '娱乐'},
          },
        };
        final room = {
          'game_data': {
            'game_tag_info': {
              'is_game': 0,
              'game_tag_id': 0,
              'game_tag_name': '',
            },
          },
        };

        final info = DouyinSite.resolveCategoryInfo(room, container: container);
        expect(info['categoryId'], '1,1');
        expect(info['categoryName'], '娱乐');
        expect(info['categoryParentId'], isNull);
        expect(info['categoryParentName'], isNull);
      },
    );

    test(
      'falls back to SceneTags.douyin_game_tag inside stream_data for reflow rooms',
      () {
        final room = {
          'stream_url': {
            'live_core_sdk_data': {
              'pull_data': {
                'stream_data':
                    '{"common":{"common_trace":"{\\"SceneTags\\":{\\"douyin_game_tag\\":\\"1010235\\"}}"}}',
              },
            },
          },
        };

        final info = DouyinSite.resolveCategoryInfo(room);
        expect(info['categoryId'], '1010235,1');
        expect(info['categoryName'], isNull);
      },
    );
  });
}
