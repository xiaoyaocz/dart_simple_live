import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/danmaku/proto/douyin.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  test('Douyu exposes six domain-based WebSocket endpoints', () {
    expect(DouyuDanmaku.serverUrls, hasLength(6));
    expect(
      DouyuDanmaku.serverUrls,
      containsAll(<String>[
        'wss://danmuproxy.douyu.com:8501',
        'wss://danmuproxy.douyu.com:8502',
        'wss://danmuproxy.douyu.com:8503',
        'wss://danmuproxy.douyu.com:8504',
        'wss://danmuproxy.douyu.com:8505',
        'wss://danmuproxy.douyu.com:8506',
      ]),
    );
    expect(DouyuDanmaku.serverUrls.toSet(), hasLength(6));
  });

  test(
    'WebSocket candidates are de-duplicated without changing host names',
    () {
      final socket = WebScoketUtils(
        url: 'wss://example.test:1',
        backupUrl: 'wss://example.test:2',
        backupUrls: const ['wss://example.test:2', 'wss://example.test:3'],
        heartBeatTime: 1000,
      );

      expect(socket.connectUrls, const [
        'wss://example.test:1',
        'wss://example.test:2',
        'wss://example.test:3',
      ]);
    },
  );

  test('Douyin IM context fields round-trip through protobuf', () {
    final source = Response()
      ..pushServer = 'wss://webcast5-ws-web-lq.douyin.com'
      ..cursor = 'cursor-from-server'
      ..internalExt = 'internal-ext-from-server'
      ..heartbeatDuration = Int64(30000);
    final decoded = Response.fromBuffer(source.writeToBuffer());

    expect(decoded.pushServer, source.pushServer);
    expect(decoded.cursor, source.cursor);
    expect(decoded.internalExt, source.internalExt);
    expect(decoded.heartbeatDuration.toInt(), 30000);
  });
}
