import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/src/common/http_client.dart' as core;
import 'package:simple_live_app/services/playback_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Source extends LiveSite {
  final List<LivePlayQuality> qualities;
  _Source(this.qualities);
  @override
  LiveDanmaku getDanmaku() => LiveDanmaku();
  @override
  Future<List<LivePlayQuality>> getPlayQualites(
          {required LiveRoomDetail detail}) async =>
      qualities;
}

class _Room extends LiveRoomController {
  final double hz;
  final bool mobileQuality;
  int? opened;
  _Room(_Source source, {this.hz = 120, this.mobileQuality = false})
      : super(
            pSite: Site(id: 'huya', name: '', logo: '', liveSite: source),
            pRoomId: '1');
  @override
  bool get usesCellularQuality => mobileQuality;
  @override
  Future<int> getQualityLevel() async =>
      mobileQuality ? await super.getQualityLevel() : 2;
  @override
  double get nativeDisplayHz => hz;
  @override
  void getPlayUrl({int? request}) {
    opened = currentQuality;
  }
}

class _HlsSource extends _Source {
  _HlsSource()
      : super([
          LivePlayQuality(quality: '自动', data: 0, frameRate:120),
          LivePlayQuality(quality: '手动60', data: 1, frameRate:60)
        ]);
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async =>
      LiveRoomDetail(
          roomId: roomId,
          title: '',
          cover: '',
          userName: '',
          userAvatar: '',
          online: 0,
          status: true,
          url: '');
  @override
  Future<LivePlayUrl> getPlayUrls(
          {required LiveRoomDetail detail,
          required LivePlayQuality quality}) async =>
      LivePlayUrl(urls: [
        quality.data == 0
            ? 'https://example.com/master.m3u8'
            : 'https://example.com/manual.flv'
      ]);
}

class _Player implements Player {
  final opened = <String>[];
  @override
  PlayerState state = const PlayerState(playing: true);
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened.add((playable as Media).uri);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlayableRoom extends LiveRoomController {
  _PlayableRoom(_Source source)
      : super(
            pSite: Site(id: 'huya', name: '', logo: '', liveSite: source),
            pRoomId: '1');
  final fake = _Player();
  @override
  Player get player => fake;
  @override
  Future<int> getQualityLevel() async => 2;
  @override
  double get nativeDisplayHz => 120;
  @override
  Future<void> initializePlayer() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These scenarios explicitly opt into FPS priority; new installs prefer the
  // highest platform quality instead, while the opt-in feature remains intact.
  setUp(() => Get.put<AppSettingsController>(
      _Settings()..preferNativeFrameRate.value = true));
  tearDown(() => Get.reset());
  test('highest quality preference without FPS priority keeps 4K on a 120Hz display',
      () async {
    AppSettingsController.instance.preferNativeFrameRate.value = false;
    final room = _Room(_Source([
      LivePlayQuality(quality: '4K', data: 0, frameRate: 60),
      LivePlayQuality(quality: '1080P', data: 1, frameRate: 120),
    ]));
    room.detail.value = LiveRoomDetail(
        roomId: '1', title: '', cover: '', userName: '', userAvatar: '',
        online: 0, status: true, url: '');
    room.getPlayQualites(0);
    await Future<void>.delayed(Duration.zero);
    expect(room.opened, 0);
  });
  for (final hz in [60.0, 120.0]) {
    test('explicit FPS priority chooses fitting native FPS on ${hz}Hz display',
        () async {
      final source = _Source([
        LivePlayQuality(quality: '4K', data: 0, frameRate: 60),
        LivePlayQuality(quality: '1080P', data: 1, frameRate: 120),
      ]);
      final room = _Room(source, hz: hz);
      room.detail.value = LiveRoomDetail(
          roomId: '1',
          title: '',
          cover: '',
          userName: '',
          userAvatar: '',
          online: 0,
          status: true,
          url: '');
      room.getPlayQualites(0);
      await Future<void>.delayed(Duration.zero);
      expect(room.opened, hz == 120 ? 1 : 0);
    });
  }
  test('移动流量下优先采用流量画质设置，即使开启了原生帧率优先', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => ['mobile']);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    AppSettingsController.instance.qualityLevelCellular.value = 0;
    final room = _Room(_Source([
      LivePlayQuality(quality: '1080P', data: 0, frameRate: 120),
      LivePlayQuality(quality: '流畅', data: 1, frameRate: 30),
    ]), mobileQuality: true);
    addTearDown(room.scrollController.dispose);
    room.detail.value = LiveRoomDetail(
        roomId: '1', title: '', cover: '', userName: '', userAvatar: '',
        online: 0, status: true, url: '');
    room.getPlayQualites(0);
    await Future<void>.delayed(Duration.zero);
    expect(room.opened, 1);
  });
  testWidgets(
      'HLS-only 120/60 alternatives downgrade on sustained loss; manual choice stops adaptation',
      (tester) async {
    final original = core.HttpClient.instance.dio;
    final dio = Dio();
    core.HttpClient.instance.dio = dio;
    dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(Response(
            requestOptions: o,
            data: ResponseBody.fromString(
                '#EXTM3U\n#EXT-X-STREAM-INF:FRAME-RATE=120\n120.m3u8\n#EXT-X-STREAM-INF:FRAME-RATE=60\n60.m3u8\n',
                200)))));
    try {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      final room = _PlayableRoom(_HlsSource());
      room.detail.value = LiveRoomDetail(
          roomId: '1',
          title: '',
          cover: '',
          userName: '',
          userAvatar: '',
          online: 0,
          status: true,
          url: '');
      room.getPlayQualites(0);
      await tester.pumpAndSettle();
      expect(room.fake.opened.single, 'https://example.com/120.m3u8');
      room.hasPlayed.value = true;
      for (var i = 0; i < 4; i++) {
        room.playbackSample(PlaybackSnapshot(
            sourceFps: 120,
            voDrops: i * 100,
            decoderDrops: 0,
            elapsed: Duration(seconds: i * 5)));
      }
      await tester.pumpAndSettle();
      expect(room.fake.opened.last, 'https://example.com/60.m3u8');
      expect(room.fake.opened.length, 2);
      room.fake.state = const PlayerState(playing: true, buffering: true);
      room.mediaError('test recovery');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(room.fake.opened.length, 3);
      expect(room.fake.opened.last, 'https://example.com/60.m3u8',
          reason: 'Recovery must preserve the overload ceiling');
      room.fake.state = const PlayerState(playing: true);
      room.showQualitySheet();
      await tester.pumpAndSettle();
      expect(find.textContaining('平台标称'),findsNothing);
      await tester.tap(find.text('手动60'));
      await tester.pumpAndSettle();
      expect(room.fake.opened.last, 'https://example.com/manual.flv');
      room.hasPlayed.value = true;
      final opens = room.fake.opened.length;
      for (var i = 0; i < 4; i++) {
        room.playbackSample(PlaybackSnapshot(
            sourceFps: 120,
            voDrops: i * 100,
            decoderDrops: 0,
            elapsed: Duration(seconds: 30 + i * 5)));
      }
      await tester.pumpAndSettle();
      expect(room.fake.opened.length, opens);
    } finally {
      core.HttpClient.instance.dio = original;
      dio.close(force: true);
    }
  });
}
