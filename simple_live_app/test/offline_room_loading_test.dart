import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/room_startup_cache.dart';
import 'package:simple_live_app/services/playback_route_history.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _DB extends DBService {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool getFollowExist(String id) => false;
}

class _Chat extends LiveDanmaku {
  int starts = 0;
  int stops = 0;
  @override
  Future<void> start(dynamic args) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

LiveRoomDetail _detail({bool live = true, bool replay = false}) =>
    LiveRoomDetail(
        roomId: '1',
        title: '直播间',
        cover: '',
        userName: '主播',
        userAvatar: '',
        online: 0,
        status: live,
        isRecord: replay,
        url: 'https://example.com/1');

class _Site extends LiveSite {
  final chat = _Chat();
  Future<LiveRoomDetail> Function() request = () async => _detail(live: false);
  int details = 0;
  int qualities = 0;
  int urls = 0;
  int sc = 0;
  int failUrls = 0;
  int failQualities = 0;
  @override
  LiveDanmaku getDanmaku() => chat;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) {
    details++;
    return request();
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoomDetail detail}) async {
    qualities++;
    if (failQualities-- > 0) throw StateError('qualities no longer exist');
    return [LivePlayQuality(quality: '原画', data: 1)];
  }

  @override
  Future<LivePlayUrl> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    urls++;
    if (failUrls-- > 0) throw StateError('stream no longer exists');
    return LivePlayUrl(urls: ['https://example.com/live.flv']);
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) async {
    sc++;
    return [];
  }
}

class _MultiSite extends _Site {
  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail,
      required LivePlayQuality quality}) async => LivePlayUrl(urls: [
        'https://startup-first.example/live.flv',
        'https://startup-fast.example/live.flv',
      ]);
}

class _Player implements Player {
  int opens = 0;
  int stops = 0;
  Completer<void>? opening;
  bool failOpen = false;
  @override
  PlayerState state = const PlayerState(buffering: true);
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opens++;
    if (failOpen) throw StateError('native open failed');
    await opening?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    state = const PlayerState();
  }

  @override
  PlayerStream get stream => _Stream();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stream implements PlayerStream {
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _VideoController implements VideoController {
  _VideoController(this.player);
  @override
  final Player player;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _VideoState with Diagnosticable implements VideoState {
  _VideoState(this.context, this.fake);
  final Player fake;
  @override
  final BuildContext context;
  @override
  Video get widget => Video(controller: _VideoController(fake));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room extends LiveRoomController {
  _Room(_Site source)
      : super(
            pSite: Site(id: 'test', name: '', logo: '', liveSite: source),
            pRoomId: '1');
  final fake = _Player();
  @override
  Player get player => fake;
  @override
  Future<void> initializePlayer() async {}
  @override
  Future<int> getQualityLevel() async => 2;
  @override
  void addHistory() {}
}

void _seed(_Room room) {
  room.detail.value = _detail();
  room.liveStatus.value = true;
  room.qualites.add(LivePlayQuality(quality: '原画', data: 1));
  room.currentQuality = 0;
}

void main() {
  setUp(() {
    Get.put<AppSettingsController>(_Settings());
    Get.put<DBService>(_DB());
  });
  tearDown(() => Get.reset());
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(MaterialApp(
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: const Scaffold()));

  testWidgets('进入消费预取详情，刷新仍强制请求，不重复开流', (tester) async {
    await mount(tester);
    final source = _Site()..request = () async => _detail();
    RoomStartupCache.instance.prefetch(source, '1');
    await tester.pump();
    expect(source.details, 1);
    final room = _Room(source);
    room.loadData(reusePrefetch: true);
    await tester.pump();
    expect(source.details, 1);
    expect(room.fake.opens, 1);
    room.refreshRoom();
    await tester.pump();
    expect(source.details, 2);
    expect(room.fake.opens, 2);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('同画质已验证快线路置前，备用线路不丢失', (tester) async {
    await mount(tester);
    final room = _Room(_MultiSite());
    _seed(room);
    PlaybackRouteHistory.instance.success('test', '原画',
        'https://startup-fast.example/previous.flv?token=old',
        const Duration(milliseconds: 500));
    room.getPlayUrl();
    await tester.pump();
    expect(room.playUrls.first, 'https://startup-fast.example/live.flv');
    expect(room.playUrls.last, 'https://startup-first.example/live.flv');
    expect(room.qualites[room.currentQuality].quality, '原画');
    expect(room.fake.opens, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  for (final platform in ['huya', 'douyin']) {
    testWidgets('$platform 已下播时从APP菜单打开网页，不依赖弹幕参数', (tester) async {
      await mount(tester);
      final urls = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') urls.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final source = _Site();
      final room = _Room(source);
      room.rxSite.value = Site(id: platform, name: '', logo: '', liveSite: source);
      room.detail.value = _detail(live: false);
      room.openNaviteAPP();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(urls, [platform == 'huya' ? 'https://www.huya.com/1' : 'https://live.douyin.com/1']);
    });
  }

  testWidgets('已下播状态不等待上一条卡住的播放器打开操作', (tester) async {
    await mount(tester);
    final site = _Site();
    final room = _Room(site);
    _seed(room);
    final opening = room.fake.opening = Completer<void>();
    room.getPlayUrl();
    await tester.pump();
    expect(room.fake.opens, 1);
    room.loadData();
    await tester.pump();
    expect(room.roomOffline.value, isTrue);
    expect(room.loadError.value, isFalse);
    expect(site.chat.starts, 0);
    expect(room.fake.stops, 0);
    opening.complete();
    await tester.pump();
    expect(room.fake.stops, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('清晰度失效后确认下播不再重复读取清晰度', (tester) async {
    await mount(tester);
    final site = _Site()..failQualities = 10;
    site.request = () async => _detail();
    final room = _Room(site);
    room.loadData();
    site.request = () async => _detail(live: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(room.roomOffline.value, isTrue);
    expect(site.qualities, 1);
    expect(site.urls, 0);
  });

  testWidgets('原生播放器打开失败且确认下播，清空错误并停止', (tester) async {
    await mount(tester);
    final site = _Site();
    final room = _Room(site);
    _seed(room);
    room.fake.failOpen = true;
    room.getPlayUrl();
    await tester.pump();
    expect(room.roomOffline.value, isTrue);
    expect(room.errorMsg.value, isEmpty);
    expect(room.fake.stops, 1);
    expect(site.urls, 1);
  });

  testWidgets('状态核验超时仍允许重试，超时后的下播响应不反写', (tester) async {
    await mount(tester);
    final gate = Completer<LiveRoomDetail>();
    final site = _Site()..failUrls = 1;
    site.request = () => gate.future;
    final room = _Room(site);
    _seed(room);
    room.getPlayUrl();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(room.fake.opens, 1);
    expect(room.roomOffline.value, isFalse);
    gate.complete(_detail(live: false));
    await tester.pump();
    expect(room.liveStatus.value, isTrue);
    expect(room.roomOffline.value, isFalse);
  });

  for (final fullscreen in [false, true]) {
    testWidgets('${fullscreen ? "全屏" : "普通"}控制层：已下播时隐藏迟到的缓冲提示', (tester) async {
      final room = _Room(_Site());
      room.fullScreenState.value = fullscreen;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
        builder: (context) => fullscreen
            ? buildFullControls(_VideoState(context, room.fake), room)
            : buildControls(false, _VideoState(context, room.fake), room),
      ))));
      // 开播瞬间不出现任何加载符号
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('缓冲中'), findsNothing);
      // 起播前即使持续缓冲也不提示，避免每次进房闪一下
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('缓冲中'), findsNothing);
      // 出过画面后再持续缓冲才提示
      room.hasPlayed.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      expect(find.text('缓冲中'), findsOneWidget);
      room.roomOffline.value = true;
      await tester.pump();
      expect(room.fake.state.buffering, isTrue);
      expect(find.text('缓冲中'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('已下播后手动刷新检测到重新开播，恢复正常播放', (tester) async {
    await mount(tester);
    final site = _Site();
    final room = _Room(site);
    room.loadData();
    await tester.pump();
    expect(room.roomOffline.value, isTrue);
    site.request = () async => _detail();
    room.refreshRoom();
    await tester.pump();
    expect(room.roomOffline.value, isFalse);
    expect(room.liveStatus.value, isTrue);
    expect(room.fake.opens, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('房间已下播：停止播放器，不再读SC、连接弹幕或获取流', (tester) async {
    await mount(tester);
    final site = _Site();
    final room = _Room(site);
    room.loadData();
    await tester.pump();
    expect(room.loadError.value, isFalse);
    expect(room.liveStatus.value, isFalse);
    expect(site.qualities, 0);
    expect(site.urls, 0);
    expect(site.sc, 0);
    expect(site.chat.starts, 0);
    expect(room.fake.stops, 1);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('获取地址失败后确认已下播，不再重试失效地址', (tester) async {
    await mount(tester);
    final site = _Site()..failUrls = 10;
    final room = _Room(site);
    _seed(room);
    room.getPlayUrl();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(site.details, 1);
    expect(site.urls, 1);
    expect(room.liveStatus.value, isFalse);
    expect(room.loadError.value, isFalse);
    expect(room.playUrls, isEmpty);
  });
  testWidgets('播放断流确认下播后不再换备用线', (tester) async {
    await mount(tester);
    final site = _Site();
    final room = _Room(site);
    _seed(room);
    room.playUrls
        .addAll(['https://example.com/old', 'https://example.com/backup']);
    room.currentLineIndex = 0;
    room.mediaError('stream ended');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(site.details, 1);
    expect(room.liveStatus.value, isFalse);
    expect(room.fake.opens, 0);
    expect(room.fake.stops, 1);
    await tester.pump(const Duration(seconds: 20));
    expect(room.fake.opens, 0);
  });
  testWidgets('播放地址重试前核验状态失败，不误判为下播', (tester) async {
    await mount(tester);
    final site = _Site()..failUrls = 1;
    site.request = () async => throw StateError('network unavailable');
    final room = _Room(site);
    _seed(room);
    room.getPlayUrl();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(room.liveStatus.value, isTrue);
    expect(site.urls, 2);
    expect(room.fake.opens, 1);
  });
  testWidgets('平台录像轮播仍正常加载', (tester) async {
    await mount(tester);
    final site = _Site();
    site.request = () async => _detail(live: false, replay: true);
    final room = _Room(site);
    room.loadData();
    await tester.pump();
    expect(room.liveStatus.value, isTrue);
    expect(site.qualities, 1);
    expect(site.urls, 1);
    expect(room.fake.opens, 1);
    expect(room.fake.stops, 0);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('旧状态核验迟到，不能覆盖手动刷新的新直播', (tester) async {
    await mount(tester);
    final gate = Completer<LiveRoomDetail>();
    final site = _Site()..failUrls = 1;
    site.request = () => gate.future;
    final room = _Room(site);
    _seed(room);
    room.getPlayUrl();
    await tester.pump();
    site.request = () async => _detail();
    room.loadData();
    await tester.pump();
    gate.complete(_detail(live: false));
    await tester.pump();
    expect(room.liveStatus.value, isTrue);
    expect(room.detail.value!.status, isTrue);
    expect(room.fake.opens, 1);
    await tester.pump(const Duration(seconds: 1));
  });
}
