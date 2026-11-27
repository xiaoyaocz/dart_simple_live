import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/services/danmaku_throttle.dart';
import 'package:simple_live_app/services/live_catchup_controller.dart';
import 'package:simple_live_app/services/playback_diagnostics.dart';
import 'package:simple_live_app/services/playback_route_history.dart';
import 'package:simple_live_app/services/stream_route_prober.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _PassthroughHttpOverrides extends HttpOverrides {}

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Native implements NativePlayer {
  final properties = <String, String>{};
  @override
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    properties[property] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlayer implements Player {
  @override
  final NativePlayer platform = _Native();
  final rates = <double>[];
  final opened = <String>[];
  @override
  PlayerState state = const PlayerState(playing: true, buffering: false);

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened.add((playable as Media).uri);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlayerHarness with PlayerMixin {
  final _fake = _FakePlayer();
  @override
  Player get player => _fake;
}

class _TestSite extends HuyaSite {
  int getPlayUrlsCalls = 0;
  List<String> urls = ['https://cdn.example/live.flv'];
  LivePlayQuality? lastRequestedQuality;

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    getPlayUrlsCalls++;
    lastRequestedQuality = quality;
    return LivePlayUrl(urls: urls);
  }
}

class _RoomHarness extends LiveRoomController {
  _RoomHarness(Site site) : super(pSite: site, pRoomId: '100');
  final fake = _FakePlayer();
  @override
  Player get player => fake;
  @override
  Future<void> initializePlayer() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('优化1：MPV 底层无感重连与缓冲策略模式', () {
    setUp(() => Get.put<AppSettingsController>(_Settings()));
    tearDown(() => Get.reset());

    test('配置 stream-lavf-o 断线自动续传，并按缓冲策略切换 cache 参数', () async {
      // 模式 0：默认均衡
      AppSettingsController.instance.playerBufferMode.value = 0;
      final balanced = _PlayerHarness();
      await balanced.initializePlayer();
      final p0 = (balanced.player.platform as _Native).properties;
      expect(
        p0['stream-lavf-o'],
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=2',
      );
      expect(p0['cache-secs'], '20');
      expect(p0['cache-pause-wait'], Platform.isWindows ? '0.5' : '2');

      // 模式 1：抗抖稳流
      AppSettingsController.instance.playerBufferMode.value = 1;
      final stable = _PlayerHarness();
      await stable.initializePlayer();
      final p1 = (stable.player.platform as _Native).properties;
      expect(p1['cache-secs'], '30');
      expect(p1['cache-pause-wait'], '2.5');

      // 模式 2：低延迟
      AppSettingsController.instance.playerBufferMode.value = 2;
      final lowLatency = _PlayerHarness();
      await lowLatency.initializePlayer();
      final p2 = (lowLatency.player.platform as _Native).properties;
      expect(p2['cache-secs'], '10');
      expect(p2['cache-pause-wait'], Platform.isWindows ? '0.3' : '0.8');
    });
  });

  group('优化2：PlaybackRouteHistory HLS 同协议优选与 JSON 持久化', () {
    test('支持同文件名 .m3u8 备用 CDN 优选，且不与 .flv 跨协议混淆', () {
      var now = DateTime(2026, 11, 25, 12, 0);
      final history = PlaybackRouteHistory(now: () => now);
      const hlsUrls = [
        'https://hls1.example/stream/index.m3u8?sign=1',
        'https://hls2.example/stream/index.m3u8?sign=2',
      ];
      expect(history.hasProvenRoute('bilibili', '原画', hlsUrls), isFalse);
      history.success(
        'bilibili',
        '原画',
        hlsUrls[1],
        const Duration(milliseconds: 320),
      );
      expect(history.hasProvenRoute('bilibili', '原画', hlsUrls), isTrue);
      expect(history.select('bilibili', '原画', hlsUrls), 1);

      // 不同文件名或跨协议不乱切
      expect(
        history.select('bilibili', '原画', [
          'https://hls1.example/stream/master.m3u8',
          'https://hls2.example/stream/live.flv',
        ]),
        0,
      );
    });

    test('支持 exportJson / importJson 跨启动持久化并忽略过期记录', () async {
      var now = DateTime(2026, 11, 25, 12, 0);
      String saved = '';
      final writer = PlaybackRouteHistory(
        now: () => now,
        saveDebounce: const Duration(milliseconds: 10),
      );
      writer.attachPersistence(
        read: () => saved,
        write: (json) async => saved = json,
      );
      writer.success(
        'douyu',
        '原画',
        'https://fast.example/room.flv?token=a',
        const Duration(milliseconds: 280),
      );
      writer.failure('douyu', '原画', 'https://bad.example/room.flv?token=b');
      await writer.flushPersistence();
      expect(saved, isNotEmpty);

      final restored = PlaybackRouteHistory(now: () => now);
      restored.importJson(saved);
      expect(
        restored.select('douyu', '原画', [
          'https://bad.example/room.flv?token=new1',
          'https://fast.example/room.flv?token=new2',
        ]),
        1,
      );

      // 超过 TTL 后导入自动丢弃
      final expired = PlaybackRouteHistory(
        now: () => now.add(const Duration(minutes: 20)),
      );
      expired.importJson(saved);
      expect(
        expired.hasProvenRoute('douyu', '原画', [
          'https://bad.example/room.flv',
          'https://fast.example/room.flv',
        ]),
        isFalse,
      );
    });
  });

  group('优化3：LiveCatchupController 直播累积延迟微倍速追帧', () {
    test('满足滞回与连续确认规则，避免抖动，并在缓冲或追平后恢复 1.0x', () {
      final catchup = LiveCatchupController();
      // 单次缓存尖峰不触发
      expect(
        catchup.evaluate(9.0, enabled: true, buffering: false, active: true),
        1.0,
      );
      // 连续第二次达到 >= 8s -> 1.08x
      expect(
        catchup.evaluate(8.5, enabled: true, buffering: false, active: true),
        1.08,
      );
      // 连续两次达到 >= 14s -> 1.15x
      expect(
        catchup.evaluate(15.0, enabled: true, buffering: false, active: true),
        1.08,
      );
      expect(
        catchup.evaluate(14.5, enabled: true, buffering: false, active: true),
        1.15,
      );
      // 回落到 3..8s 区间时先缓降至 1.08x
      expect(
        catchup.evaluate(5.0, enabled: true, buffering: false, active: true),
        1.08,
      );
      // 回落到 <= 3s -> 恢复 1.0x
      expect(
        catchup.evaluate(2.8, enabled: true, buffering: false, active: true),
        1.0,
      );
      // 缓冲或关闭开关立即恢复 1.0x
      catchup.evaluate(10.0, enabled: true, buffering: false, active: true);
      expect(
        catchup.evaluate(10.0, enabled: true, buffering: false, active: true),
        1.08,
      );
      expect(
        catchup.evaluate(10.0, enabled: true, buffering: true, active: true),
        1.0,
      );
    });
  });

  group('优化4：LiveRoomController 追帧和画质保持', () {
    test('缓存充足时只追赶播放中真正累积的延迟', () {
      final room = _RoomHarness(Site(id: 'huya', name: '', logo: '', liveSite: _TestSite()));
      room.hasPlayed.value = true;
      room.liveStatus.value = true;
      AppSettingsController.instance.liveCatchupEnable.value = true;
      void sample(int elapsed, int position, double cache) {
        room.fake.state = PlayerState(playing: true, position: Duration(seconds: position));
        room.playbackSample(PlaybackSnapshot(elapsed: Duration(seconds: elapsed), cacheSeconds: cache));
      }
      sample(1, 1, 15);
      sample(2, 2, 15);
      expect(room.fake.rates, isEmpty);
      sample(12, 3, 5);
      sample(13, 4, 5);
      expect(room.fake.rates, [1.08]);
      sample(14, 5, 1);
      expect(room.fake.rates, [1.08, 1.0]);
    });

    for (final progressing in [true, false]) {
    testWidgets('后台测速未完成先开流，已有进度=$progressing', (tester) async {
      const first = 'https://fast-open.example/live.flv';
      const backup = 'https://backup-open.example/live.flv';
      final source = _TestSite()..urls = [first, backup];
      final room = _RoomHarness(Site(id: 'huya', name: '', logo: '', liveSite: source));
      final probe = Completer<int?>();
      room.enableRouteProbe = true;
      room.routeProber = StreamRouteProber(probeRequest: (uri, _, __) async {
        await probe.future;
        return uri.host == 'backup-open.example' ? 200 : 404;
      });
      AppSettingsController.instance.streamRouteProbeEnable.value = true;
      room.detail.value = LiveRoomDetail(roomId: '100', title: '', cover: '', userName: '', userAvatar: '', online: 0, status: true, url: '');
      room.liveStatus.value = true;
      room.qualites.add(LivePlayQuality(quality: '原画', data: 1));
      room.currentQuality = 0;
      room.getPlayUrl();
      await tester.pump();
      expect(room.fake.opened, [first]);
      room.hasPlayed.value = progressing;
      probe.complete(200);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(room.fake.opened, [first, if (!progressing) backup]);
    });
    }

    testWidgets('反复短卡临时提高缓冲，换线后恢复默认门槛', (tester) async {
      final room = _RoomHarness(Site(id: 'huya', name: '', logo: '', liveSite: _TestSite()));
      final native = room.fake.platform as _Native;
      AppSettingsController.instance.playerBufferMode.value = 0;
      room.liveStatus.value = true;
      room.playUrls.assignAll(['https://first.example/live.flv', 'https://next.example/live.flv']);
      room.currentLineIndex = 0;
      await room.setPlayer();
      room.hasPlayed.value = true;
      for (var i = 1; i <= 2; i++) {
        room.fake.state = PlayerState(playing: true, buffering: true, position: Duration(seconds: i * 3));
        room.mediaBuffering(true);
        await tester.pump(const Duration(seconds: 1));
        room.mediaBuffering(false);
      }
      expect(native.properties['cache-pause-wait'], Platform.isWindows ? '1.5' : '3');
      room.changePlayLine(1);
      await tester.pump();
      expect(native.properties['cache-pause-wait'], Platform.isWindows ? '0.5' : '2');
    });
    setUp(() => Get.put<AppSettingsController>(_Settings()));
    tearDown(() => Get.reset());

    test('持续丢帧时保持当前清晰度', () async {
      final testSite = _TestSite();
      final site = Site(
        id: 'huya',
        name: '虎牙',
        logo: '',
        liveSite: testSite,
      );
      final room = _RoomHarness(site);
      room.detail.value = LiveRoomDetail(
        roomId: '100',
        title: 't',
        cover: '',
        userName: 'u',
        userAvatar: '',
        online: 1,
        status: true,
        url: '',
      );
      room.qualites.addAll([
        LivePlayQuality(quality: '蓝光8M', sort: 2, data: 'a'),
        LivePlayQuality(quality: '超清', sort: 1, data: 'b'),
      ]);
      room.currentQuality = 0;
      room.hasPlayed.value = true;
      room.liveStatus.value = true;

      // 触发 LiveCatchupController 追帧 + 3 个 5s 丢帧窗口
      room.playbackSample(const PlaybackSnapshot(
        sourceFps: 60,
        voDrops: 0,
        decoderDrops: 0,
        cacheSeconds: 9.0,
        elapsed: Duration(seconds: 0),
      ));
      expect(room.fake.rates, isEmpty);

      room.playbackSample(const PlaybackSnapshot(
        sourceFps: 60,
        voDrops: 40,
        decoderDrops: 0,
        cacheSeconds: 9.5,
        elapsed: Duration(seconds: 5),
      ));
      expect(room.fake.rates, isEmpty);

      room.playbackSample(const PlaybackSnapshot(
        sourceFps: 60,
        voDrops: 80,
        decoderDrops: 0,
        cacheSeconds: 2.0,
        elapsed: Duration(seconds: 10),
      ));
      expect(room.fake.rates, isEmpty);

      room.playbackSample(const PlaybackSnapshot(
        sourceFps: 60,
        voDrops: 120,
        decoderDrops: 0,
        cacheSeconds: 2.0,
        elapsed: Duration(seconds: 15),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(room.currentQuality, 0);
      expect(testSite.getPlayUrlsCalls, 0);
      expect(testSite.lastRequestedQuality, isNull);
    });
  });

  group('优化5：DanmakuThrottle 屏幕弹幕限流与本人弹幕豁免', () {
    test('超过每秒上限或同屏数量上限时丢弃普通弹幕，本人弹幕始终放行', () {
      var now = DateTime(2026, 11, 25, 12, 0, 0);
      final throttle = DanmakuThrottle(
        maxPerSecond: 3,
        maxActiveOnScreen: 10,
        now: () => now,
      );
      expect(throttle.allow(activeOnScreen: 0), isTrue);
      expect(throttle.allow(activeOnScreen: 1), isTrue);
      expect(throttle.allow(activeOnScreen: 2), isTrue);
      // 1 秒内第 4 条被限流
      expect(throttle.allow(activeOnScreen: 3), isFalse);
      // 本人弹幕始终放行
      expect(throttle.allow(activeOnScreen: 999, selfSend: true), isTrue);

      // 超过同屏上限被拦截
      now = now.add(const Duration(seconds: 2));
      expect(throttle.allow(activeOnScreen: 10), isFalse);
      expect(throttle.allow(activeOnScreen: 9), isTrue);
    });
  });

  group('优化6：StreamRouteProber 并发响应头测速优选', () {
    test('优先选中最快返回 200 的同协议备用 CDN 并标记 403 节点失败', () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final badServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final slowServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final fastServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

        badServer.listen((req) async {
          req.response.statusCode = 403;
          await req.response.close();
        });
        slowServer.listen((req) async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          req.response.statusCode = 200;
          await req.response.close();
        });
        fastServer.listen((req) async {
          req.response.statusCode = 200;
          await req.response.close();
        });

        addTearDown(() async {
          await badServer.close(force: true);
          await slowServer.close(force: true);
          await fastServer.close(force: true);
        });

        final urls = [
          'http://127.0.0.1:${badServer.port}/live/room.flv?t=1',
          'http://127.0.0.1:${slowServer.port}/live/room.flv?t=2',
          'http://127.0.0.1:${fastServer.port}/live/room.flv?t=3',
        ];
        final history = PlaybackRouteHistory();
        final prober = StreamRouteProber(
          timeout: const Duration(milliseconds: 400),
        );
        final chosen = await prober.selectFastest(
          site: 'huya',
          quality: '原画',
          urls: urls,
          history: history,
        );
        expect(chosen, 2);
        expect(history.hasProvenRoute('huya', '原画', urls), isTrue);
      }, _PassthroughHttpOverrides());
    });

    test('全部超时时在硬超时上限内无感回退默认路线 0', () async {
      final prober = StreamRouteProber(
        timeout: const Duration(milliseconds: 80),
        probeRequest: (_, __, ___) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return 200;
        },
      );
      final chosen = await prober.selectFastest(
        site: 'bilibili',
        quality: '原画',
        urls: const [
          'https://cdn1.example/live.flv',
          'https://cdn2.example/live.flv',
        ],
        history: PlaybackRouteHistory(),
      );
      expect(chosen, 0);
    });
  });
}
