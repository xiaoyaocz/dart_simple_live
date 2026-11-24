import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('PlayerErrorClassifier', () {
    test('recognizes recoverable audio diagnostics', () {
      expect(
        PlayerErrorClassifier.isRecoverableAudioDiagnostic(
          'Error decoding audio.',
        ),
        isTrue,
      );
      expect(
        PlayerErrorClassifier.isRecoverableAudioDiagnostic(
          'Could not open/initialize audio device -> no sound.',
        ),
        isTrue,
      );
      expect(
        PlayerErrorClassifier.isRecoverableAudioDiagnostic('network timeout'),
        isFalse,
      );
    });
  });

  group('PlayerVolumePolicy', () {
    test(
      'keeps mobile internal volume at 100 and desktop persisted volume',
      () {
        expect(
          PlayerVolumePolicy.internalVolume(
            mobile: true,
            muted: false,
            persisted: 20,
          ),
          100,
        );
        expect(
          PlayerVolumePolicy.internalVolume(
            mobile: true,
            muted: true,
            persisted: 20,
          ),
          0,
        );
        expect(
          PlayerVolumePolicy.internalVolume(
            mobile: false,
            muted: false,
            persisted: 35,
          ),
          35,
        );
      },
    );
  });

  group('KuaishouSite.overviewLiveStreams', () {
    test('does not substitute category recommendations for a room search', () {
      final liveStreams = KuaishouSite.overviewLiveStreams({
        'list': [
          {
            'type': 'categories',
            'list': [
              {'categoryId': 'game', 'title': '节奏盒子'},
            ],
          },
          {
            'type': 'liveStreams',
            'list': [
              {
                'author': {'id': 'live-room'},
              },
            ],
          },
        ],
      });

      expect(liveStreams, hasLength(1));
      expect((liveStreams.single as Map)['author']['id'], 'live-room');
    });

    test('returns no rooms when the overview has categories only', () {
      expect(
        KuaishouSite.overviewLiveStreams({
          'list': [
            {
              'type': 'categories',
              'list': [
                {'categoryId': 'game', 'title': '节奏盒子'},
              ],
            },
          ],
        }),
        isEmpty,
      );
    });
  });

  group('KuaishouLiveLink', () {
    test('builds the public live-room URL used for sharing', () {
      expect(
        KuaishouLiveLink.publicRoomUri('abc_123')?.toString(),
        'https://live.kuaishou.com/u/abc_123',
      );
      expect(KuaishouLiveLink.publicRoomUri(''), isNull);
      expect(KuaishouLiveLink.publicRoomUri('中文房间'), isNull);
    });

    test('accepts official desktop and mobile live-room URLs', () {
      expect(
        KuaishouLiveLink.roomIdFromUri(
          Uri.parse('https://live.kuaishou.com/u/abc_123'),
        ),
        'abc_123',
      );
      expect(
        KuaishouLiveLink.roomIdFromUri(
          Uri.parse('https://live.m.chenzhongtech.com/fw/live/mobile-room-1'),
        ),
        'mobile-room-1',
      );
      expect(
        KuaishouLiveLink.roomIdFromUri(
          KuaishouLiveLink.parseHttpUrl('live.kuaishou.com/u/abc_123')!,
        ),
        'abc_123',
      );
    });

    test('rejects spoofed hosts and non-live paths', () {
      for (final url in [
        'https://live.kuaishou.com.evil.example/u/abc',
        'https://evil.live.kuaishou.com/u/abc',
        'https://live.kuaishou.com/profile/abc',
        'https://live.kuaishou.com/photo/abc',
        'ftp://live.kuaishou.com/u/abc',
      ]) {
        expect(KuaishouLiveLink.roomIdFromUri(Uri.parse(url)), isNull);
      }
    });
  });

  group('KuaishouSite.resolveRoomTitle', () {
    test('prefers the room caption over the author name', () {
      expect(
        KuaishouSite.resolveRoomTitle({
          'caption': '今晚冲榜',
          'author': {'name': '测试主播'},
          'gameInfo': {'name': '王者荣耀'},
        }),
        '今晚冲榜',
      );
    });

    test('falls back through stream, game, and author fields', () {
      expect(
        KuaishouSite.resolveRoomTitle({
          'liveStream': {'caption': '直播流标题'},
          'author': {'name': '测试主播'},
        }),
        '直播流标题',
      );
      expect(
        KuaishouSite.resolveRoomTitle({
          'gameInfo': {'name': '主机游戏'},
          'author': {'name': '测试主播'},
        }),
        '主机游戏',
      );
      expect(
        KuaishouSite.resolveRoomTitle({
          'author': {'name': '测试主播'},
        }),
        '测试主播',
      );
    });
  });

  group('KuaishouSite.resolveLiveStatus', () {
    test('accepts explicit live flags', () {
      expect(KuaishouSite.resolveLiveStatus({'isLiving': true}), isTrue);
      expect(KuaishouSite.resolveLiveStatus({'living': 1}), isTrue);
    });

    test('uses stream identity when play URLs are temporarily absent', () {
      expect(
        KuaishouSite.resolveLiveStatus({
          'isLiving': false,
          'liveStream': {'id': 'stream-id', 'playUrls': const {}},
        }),
        isTrue,
      );
    });

    test('does not mark an empty stream as live', () {
      expect(
        KuaishouSite.resolveLiveStatus({
          'isLiving': false,
          'liveStream': {'id': '', 'playUrls': const {}},
        }),
        isFalse,
      );
    });

    test('selects a live entry for the requested room from a playlist', () {
      final room = KuaishouSite.selectLiveRoomFromPlayList([
        {
          'author': {'id': 'target-room'},
          'isLiving': false,
          'liveStream': {'id': ''},
        },
        {
          'author': {'id': 'target-room'},
          'isLiving': false,
          'liveStream': {'id': 'active-stream'},
        },
        {
          'author': {'id': 'other-room'},
          'isLiving': true,
          'liveStream': {'id': 'other-stream'},
        },
      ], 'target-room');

      expect(room, isNotNull);
      expect((room!['liveStream'] as Map)['id'], 'active-stream');
    });
  });
}
