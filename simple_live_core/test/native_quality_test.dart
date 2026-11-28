import 'package:test/test.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test(
    'FPS accepts explicit metadata, not resolution, bitrate or quality names',
    () {
      expect(nativeFrameRate('60000/1001'), closeTo(59.94, .01));
      for (final invalid in [
        null,
        '120Hz',
        '120fps',
        '4K',
        0,
        -1,
        double.nan,
        '1/0',
      ]) {
        expect(nativeFrameRate(invalid), isNull);
      }
      expect(
        LivePlayQuality(quality: '120帧原画', data: {'bitrate': 12000}).frameRate,
        isNull,
      );
    },
  );
  test('120fps wins over 4K60; same FPS preserves platform quality order', () {
    final qualities = [
      LivePlayQuality(quality: '4K', data: 0, frameRate: 60),
      LivePlayQuality(quality: '1080P', data: 1, frameRate: 120),
      LivePlayQuality(quality: '720P', data: 2, frameRate: 120),
    ];
    expect(preferredNativeQuality(qualities, fallback: 0), 1);
    expect(preferredNativeQuality(qualities, fallback: 0, displayHz: 60), 0);
    expect(preferredNativeQuality(qualities, fallback: 0, displayHz: 120), 1);
  });
  test('missing FPS keeps existing selection, not invented 120fps', () {
    final qualities = [
      LivePlayQuality(quality: '原画', data: 0),
      LivePlayQuality(quality: '高清', data: 1),
    ];
    expect(preferredNativeQuality(qualities, fallback: 1), 1);
  });
  test('HLS picks native120 over 4K60 and resolves relative signed URI', () {
    const text =
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=20000000,RESOLUTION=3840x2160,FRAME-RATE=60\n4k.m3u8?token=a\n#EXT-X-STREAM-INF:BANDWIDTH=12000000,RESOLUTION=1920x1080,FRAME-RATE=120\n../120.m3u8?token=b\n';
    final selected = preferredHlsVariant(
      Uri.parse('https://example.com/live/master.m3u8'),
      text,
    );
    expect(selected?.uri.toString(), 'https://example.com/120.m3u8?token=b');
    expect(selected?.frameRate, 120);
    expect(
      preferredHlsVariant(
        Uri.parse('https://example.com/master.m3u8'),
        text,
        displayHz: 60,
      )?.frameRate,
      60,
    );
  });
  test('media playlists and separate audio groups preserve master playback', () {
    final uri = Uri.parse('https://example.com/master.m3u8');
    expect(preferredHlsVariant(uri, '#EXTM3U\n#EXTINF:2,\nseg.ts'), isNull);
    expect(
      preferredHlsVariant(
        uri,
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=100,FRAME-RATE=120,AUDIO="aac"\nvideo.m3u8',
      ),
      isNull,
    );
    expect(
      preferredHlsVariant(
        uri,
        '#EXTM3U\n#EXT-X-STREAM-INF:FRAME-RATE=120\nfile:///private',
      ),
      isNull,
    );
  });
  test('overload ceiling is strict even when no advertised variant fits', () {
    const text = '#EXTM3U\n#EXT-X-STREAM-INF:FRAME-RATE=120\n120.m3u8\n';
    expect(
      preferredHlsVariant(
        Uri.parse('https://example.com/master.m3u8'),
        text,
        maxFrameRate: 60,
      ),
      isNull,
    );
  });
}
