import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/playback_route_history.dart';

void main() {
  const urls = [
    'https://a.example/live.flv?token=old',
    'https://b.example/live.flv?token=new'
  ];
  test('默认保留平台顺序；成功线路跨签名复用，不改传入列表', () {
    final history = PlaybackRouteHistory();
    expect(history.select('huya', '原画', urls), 0);
    history.success('huya', '原画', urls[1], const Duration(milliseconds: 600));
    expect(history.select('huya', '原画', urls), 1);
    expect(
        history.select('huya', '原画', [
          'https://a.example/other.flv',
          'https://b.example/other.flv?token=changed'
        ]),
        1);
    expect(urls.first, contains('a.example'));
  });
  test('不同平台/画质不共享，HLS与协议切换保持平台原顺序', () {
    final history = PlaybackRouteHistory();
    history.success('huya', '原画', urls[1], const Duration(milliseconds: 600));
    expect(history.select('douyu', '原画', urls), 0);
    expect(history.select('huya', '高清', urls), 0);
    expect(
        history.select('huya', '原画',
            ['https://a.example/master.m3u8', 'https://b.example/live.flv']),
        0);
    expect(history.select('huya', '原画', ['http://a.example/live.flv', urls[1]]),
        0);
    expect(
        history
            .select('huya', '原画', [urls[0], 'https://b.example/live_hevc.flv']),
        0);
  });
  test('多个成功线路选更快的；失败冷却后恢复，旧记录过期', () {
    var now = DateTime(2026);
    final history = PlaybackRouteHistory(now: () => now);
    history.success('huya', '原画', urls[0], const Duration(seconds: 3));
    history.success('huya', '原画', urls[1], const Duration(milliseconds: 600));
    expect(history.select('huya', '原画', urls), 1);
    history.failure('huya', '原画', urls[1]);
    expect(history.select('huya', '原画', urls), 0);
    now = now.add(const Duration(minutes: 2));
    expect(history.select('huya', '原画', urls), 1);
    now = now.add(const Duration(minutes: 15));
    expect(history.select('huya', '原画', urls), 0);
  });
  test('失败的默认线路暂时避开，没有可用备用线路时仍返回首条', () {
    final history = PlaybackRouteHistory();
    history.failure('huya', '原画', urls[0]);
    expect(history.select('huya', '原画', urls), 1);
    expect(history.select('huya', '原画', [urls[0]]), 0);
    expect(history.select('huya', '原画', []), -1);
  });
  test('持续缓冲降低线路优先级，短抖动忽略，重新起播不抹掉缓冲历史', () {
    final history = PlaybackRouteHistory();
    history.success('douyin', '原画', urls[0], const Duration(milliseconds: 500));
    history.success('douyin', '原画', urls[1], const Duration(milliseconds: 900));
    history.rebuffer('douyin', '原画', urls[0], const Duration(milliseconds: 800));
    expect(history.select('douyin', '原画', urls), 0);
    history.rebuffer('douyin', '原画', urls[0], const Duration(seconds: 2));
    history.success('douyin', '原画', urls[0], const Duration(milliseconds: 450));
    expect(history.select('douyin', '原画', urls), 1);
  });
}
