import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  // 测试不初始化持久化设置。
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Player implements Player {
  @override
  final _Streams stream = _Streams();
  int opens = 0;
  int jumps = 0;
  Completer<void>? opening;
  @override
  PlayerState state = const PlayerState(playing: true, buffering: true);
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opens++;
    await opening?.future;
  }

  @override
  Future<void> jump(int index) async {
    jumps++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Streams implements PlayerStream {
  final playingEvents = StreamController<bool>.broadcast();
  final positionEvents = StreamController<Duration>.broadcast();
  @override
  Stream<bool> get playing => playingEvents.stream;
  @override
  Stream<Duration> get position => positionEvents.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => const Stream<Never>.empty();
}

class _Room extends LiveRoomController {
  _Room({Site? source})
      : super(pSite: source ?? Sites.allSites['huya']!, pRoomId: '1');
  final fake = _Player();
  int initializations = 0;
  @override
  Player get player => fake;
  @override
  Future<void> initializePlayer() async { initializations++; }
}

class _Huya extends HuyaSite {
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async => _liveDetail();
  int calls = 0;
  @override
  Future<LivePlayUrl> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    calls++;
    return LivePlayUrl(urls: [
      'https://first/live.flv?token=new',
      'https://next/live.flv?token=new'
    ]);
  }
}

class _FlakyHuya extends HuyaSite {
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async => _liveDetail();
  int calls = 0;
  @override
  Future<LivePlayUrl> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    calls++;
    if (calls == 1) throw StateError('暂时无法获取播放地址');
    return LivePlayUrl(urls: ['https://example.com/live.flv']);
  }
}

class _PermissionHuya extends HuyaSite {
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async => _liveDetail();
  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail,
      required LivePlayQuality quality}) async =>
      throw StateError('平台拒绝此画质，可能需要 VIP 播放权限，请切换 2K');
}

class _SlowHuya extends _Huya {
  Future<LiveRoomDetail>? statusRequest;
  Future<LivePlayUrl>? urlRequest;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) =>
      statusRequest ?? super.getRoomDetail(roomId: roomId);
  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail,
      required LivePlayQuality quality}) =>
      urlRequest ?? super.getPlayUrls(detail: detail, quality: quality);
}

class _Bili extends BiliBiliSite {
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async => _liveDetail();
  int calls = 0;
  @override
  Future<LivePlayUrl> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    calls++;
    return LivePlayUrl(urls: [
      'https://first/live.flv?token=new',
      'https://next/live.flv?token=new',
    ]);
  }
}

class _Douyin extends DouyinSite {
  int refreshes = 0;
  Future<LiveRoomDetail>? pending;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) =>
      pending ?? Future.value(_liveDetail());

  @override
  Future<LiveRoomDetail> refreshRoomDetail({required String roomId}) async {
    refreshes++;
    return (await pending) ?? _liveDetail(data: [
      LivePlayQuality(quality: '高清', sort: 1, data: ['https://fresh/low.flv']),
      LivePlayQuality(quality: '原画', sort: 2, data: ['https://fresh/live.flv']),
    ]);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoomDetail detail}) async =>
      detail.data as List<LivePlayQuality>;
}

LiveRoomDetail _liveDetail({Object? data}) => LiveRoomDetail(roomId: '1', title: '', cover: '',
    userName: '', userAvatar: '', online: 0, status: true, url: '', data: data);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('wakelock_plus'), (_) async => null);
  setUp(() => Get.put<AppSettingsController>(_Settings()));
  tearDown(() => Get.reset());
  testWidgets('连续切线只执行最后一次排队的开流', (tester) async {
    final room = _Room();
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    final gate = room.fake.opening = Completer<void>();
    final initial = room.setPlayer();
    await tester.pump();
    expect(room.fake.opens, 1);
    room.changePlayLine(1);
    room.changePlayLine(0);
    room.changePlayLine(1);
    final latest = room.setPlayer();
    gate.complete();
    await initial;
    await latest;
    expect(room.currentLineIndex, 1);
    expect(room.fake.opens, 2);
  });
  testWidgets('后台暂停看门狗，返回时继续处理仍在缓冲的线路', (tester) async {
    final room = _Room();
    room.liveStatus.value = true;
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    room.mediaBuffering(true);
    room.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 9));
    expect(room.fake.opens, 0);
    room.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 8));
    expect(room.currentLineIndex, 1);
    expect(room.fake.opens, 1);
  });
  testWidgets('首次开流和同线路操作重叠时不在首帧后再次open', (tester) async {
    final room = _Room();
    room.playUrls.add('https://first/live.flv');
    room.currentLineIndex = 0;
    final gate = room.fake.opening = Completer<void>();
    room.initPlaylist(0);
    await tester.pump();
    final overlapping = room.setPlayer();
    await tester.pump();
    gate.complete();
    await tester.pump();
    await overlapping;
    expect(room.fake.opens, 1);
  });
  test('手动开流同样等待播放器初始化', () async {
    final room = _Room();
    room.playUrls.add('https://first/live.flv');
    room.currentLineIndex = 0;
    await room.setPlayer();
    expect(room.initializations, 1);
    expect(room.fake.opens, 1);
  });
  testWidgets('同一线路重复点击在原生打开完成前合并为一次，完成后可主动重试', (tester) async {
    final room = _Room();
    room.playUrls.add('https://first/live.flv');
    room.currentLineIndex = 0;
    final gate = room.fake.opening = Completer<void>();
    final first = room.setPlayer();
    final second = room.setPlayer();
    final third = room.setPlayer();
    await tester.pump();
    expect(room.fake.opens, 1);
    gate.complete();
    await tester.pump();
    await Future.wait([first, second, third]);
    room.fake.opening = null;
    await room.setPlayer();
    expect(room.fake.opens, 2);
  });
  testWidgets('playing 通知不是实际播放进展，进度前进后才标记已播放', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    final room = _Room();
    room.initStream();
    room.fake.stream.playingEvents.add(true);
    await tester.pump();
    expect(room.hasPlayed.value, isFalse);
    room.fake.stream.positionEvents.add(const Duration(milliseconds: 100));
    await tester.pump();
    expect(room.hasPlayed.value, isTrue);
    room.disposeStream();
    await room.fake.stream.playingEvents.close();
    await room.fake.stream.positionEvents.close();
  });
  _Room stalledRoom(_SlowHuya source) {
    final room = _Room(source: Site(id: 'huya', name: '', logo: '', liveSite: source));
    room.detail.value = _liveDetail();
    room.liveStatus.value = true;
    room.qualites.add(LivePlayQuality(quality: '原画', data: {}));
    room.currentQuality = 0;
    room.currentLineIndex = 0;
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    return room;
  }
  testWidgets('状态核验期间画面恢复就不再切线', (tester) async {
    final gate = Completer<LiveRoomDetail>();
    final room = stalledRoom(_SlowHuya()..statusRequest = gate.future);
    room.mediaError('暂时断流');
    await tester.pump(const Duration(seconds: 3));
    room.fake.state = const PlayerState(playing: true, position: Duration(seconds: 1));
    gate.complete(_liveDetail());
    await tester.pump();
    expect(room.fake.opens, 0);
    expect(room.currentLineIndex, 0);
  });
  testWidgets('状态核验期间手动切线不会被迟到恢复再次切换', (tester) async {
    final gate = Completer<LiveRoomDetail>();
    final room = stalledRoom(_SlowHuya()..statusRequest = gate.future);
    room.mediaError('断流');
    await tester.pump(const Duration(seconds: 3));
    room.changePlayLine(1);
    await tester.pump();
    gate.complete(_liveDetail());
    await tester.pump();
    expect(room.fake.opens, 1);
    expect(room.currentLineIndex, 1);
  });
  testWidgets('核验期间短暂恢复进度但再次缓冲时仍保留超时保护', (tester) async {
    final gate = Completer<LiveRoomDetail>();
    final source = _SlowHuya()..statusRequest = gate.future;
    final room = stalledRoom(source)..hasPlayed.value = true;
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 8));
    room.fake.state = const PlayerState(playing: true, buffering: true,
        position: Duration(seconds: 1));
    gate.complete(_liveDetail());
    await tester.pump();
    expect(room.fake.opens, 0);
    source.statusRequest = null;
    await tester.pump(const Duration(seconds: 8));
    expect(room.fake.opens, 1);
    room.mediaBuffering(false);
  });
  testWidgets('鉴权接口卡住时仍在有限等待后使用备用线路', (tester) async {
    final gate = Completer<LivePlayUrl>();
    final room = stalledRoom(_SlowHuya()..urlRequest = gate.future);
    room.mediaError('断流');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 4));
    expect(room.fake.opens, 1);
    expect(room.currentLineIndex, 1);
    gate.complete(LivePlayUrl(urls: ['https://late/live.flv']));
    await tester.pump();
    expect(room.playUrls.first, 'https://first/live.flv');
  });
  testWidgets('播放中卡死八秒恢复但不缩短首次起播宽限', (tester) async {
    final room = stalledRoom(_SlowHuya());
    room.hasPlayed.value = true;
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 7));
    expect(room.fake.opens, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(room.fake.opens, 1);
    room.mediaBuffering(false);
  });
  _Room stalledDouyin(_Douyin source, List<String> urls) {
    final room = _Room(source: Site(id: 'douyin', name: '', logo: '', liveSite: source));
    room.detail.value = _liveDetail();
    room.liveStatus.value = true;
    room.hasPlayed.value = true;
    room.qualites.add(LivePlayQuality(quality: '原画', sort: 2, data: urls));
    room.currentQuality = 0;
    room.currentLineIndex = 0;
    room.playUrls.addAll(urls);
    return room;
  }
  testWidgets('抖音短缓冲不切线，持续卡住四秒直接使用同画质备用流', (tester) async {
    final gate = Completer<LiveRoomDetail>();
    final source = _Douyin()..pending = gate.future;
    final room = stalledDouyin(source, ['https://first/live.flv', 'https://next/live.m3u8']);
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 3));
    expect(room.fake.opens, 0);
    room.mediaBuffering(false);
    await tester.pump(const Duration(seconds: 5));
    expect(room.fake.opens, 0);
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 4));
    expect(room.currentLineIndex, 1);
    expect(room.fake.opens, 1);
    expect(source.refreshes, 0);
    room.mediaBuffering(false);
  });
  testWidgets('抖音线路用完后刷新房间，重开同一画质的新地址', (tester) async {
    final source = _Douyin();
    final room = stalledDouyin(source, ['https://expired/live.flv']);
    room.mediaError('断流');
    await tester.pump(const Duration(seconds: 3));
    expect(source.refreshes, 1);
    expect(room.playUrls, ['https://fresh/live.flv']);
    expect(room.qualites[room.currentQuality].quality, '原画');
    expect(room.fake.opens, 1);
    room.mediaError('继续断流');
    await tester.pump(const Duration(seconds: 3));
    expect(source.refreshes, 1);
    expect(room.fake.opens, 2);
    room.fake.state = const PlayerState(playing: true);
    room.mediaPosition(const Duration(seconds: 1));
    room.mediaPosition(const Duration(seconds: 11));
    room.fake.state = const PlayerState(playing: true, buffering: true);
    room.mediaError('稳定播放后再次断流');
    await tester.pump(const Duration(seconds: 3));
    expect(source.refreshes, 2);
  });
  testWidgets('抖音刷新地址期间手动重开同一线路，迟到响应不打断播放', (tester) async {
    final gate = Completer<LiveRoomDetail>();
    final source = _Douyin()..pending = gate.future;
    final room = stalledDouyin(source, ['https://first/live.flv']);
    room.mediaError('断流');
    await tester.pump(const Duration(seconds: 3));
    expect(source.refreshes, 1);
    room.changePlayLine(0);
    await tester.pump();
    gate.complete(_liveDetail(data: [
      LivePlayQuality(quality: '原画', sort: 2, data: ['https://late/live.flv']),
    ]));
    await tester.pump();
    expect(room.playUrls, ['https://first/live.flv']);
    expect(room.fake.opens, 1);
  });
  test('重试当前线路必须重新打开连接', () async {
    final room = _Room();
    room.playUrls.add('https://example.com/live.flv');
    room.currentLineIndex = 0;
    room.setPlayer();
    await Future<void>.delayed(Duration.zero);
    expect(room.fake.opens, 1);
    expect(room.fake.jumps, 0);
  });
  testWidgets('首次获取播放地址失败后只重试一次并启动播放', (tester) async {
    final source = _FlakyHuya();
    final room = _Room(
        source: Site(id: 'huya', name: '', logo: '', liveSite: source));
    room.detail.value = LiveRoomDetail(
        roomId: '1',
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: true,
        url: '',
        data: '');
    room.qualites.add(LivePlayQuality(quality: '原画', data: {}));
    room.currentQuality = 0;

    room.getPlayUrl();
    await tester.pump();
    expect(source.calls, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(source.calls, 2);
    expect(room.fake.opens, 1);
  });
  testWidgets('平台拒绝4K权限后显示原因而不是只留下黑屏', (tester) async {
    final source = _PermissionHuya();
    final room = _Room(source: Site(id: 'huya', name: '虎牙', logo: '', liveSite: source));
    room.detail.value = _liveDetail();
    room.qualites.add(LivePlayQuality(quality: '4K', data: 20000));
    room.currentQuality = 0;
    room.getPlayUrl(request: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(room.errorMsg.value, contains('VIP'));
    expect(room.fake.opens, 0);
  });
  testWidgets('首次持续缓冲8秒切换备用线路，不额外等待15秒', (tester) async {
    final room = _Room();
    room.liveStatus.value = true;
    room.playUrls.addAll([
      'https://first.example.com/live.flv',
      'https://next.example.com/live.flv'
    ]);
    room.currentLineIndex = 0;
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 7));
    expect(room.fake.opens, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(room.currentLineIndex, 1);
    expect(room.fake.opens, 1);
    room.mediaBuffering(false);
  });
  testWidgets('首次起播超时有备用线路时不等待虎牙重新签名接口', (tester) async {
    final gate = Completer<LivePlayUrl>();
    final source = _SlowHuya()..urlRequest = gate.future;
    final room = stalledRoom(source);
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 8));
    expect(room.currentLineIndex, 1);
    expect(room.fake.opens, 1);
    expect(source.calls, 0);
    gate.complete(LivePlayUrl(urls: ['https://unused/live.flv']));
    room.mediaBuffering(false);
  });
  testWidgets('缓冲恢复后不切换，后台不自动重连', (tester) async {
    final room = _Room();
    room.liveStatus.value = true;
    room.playUrls.add('https://first.example.com/live.flv');
    room.currentLineIndex = 0;
    room.mediaBuffering(true);
    room.mediaBuffering(false);
    await tester.pump(const Duration(seconds: 16));
    expect(room.fake.opens, 0);
    room.isBackground = true;
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 16));
    expect(room.fake.opens, 0);
    room.mediaBuffering(false);
  });
  testWidgets('健康播放的错误日志不重新打开视频', (tester) async {
    final room = _Room();
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    room.fake.state = const PlayerState(playing: true);
    room.mediaError('解码器暂时报告错误');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(room.fake.opens, 0);
  });
  testWidgets('同一次断流的多条错误和结束通知只切线一次', (tester) async {
    final room = _Room();
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    room.fake.state = const PlayerState(completed: true);
    room.mediaError('网络错误');
    await tester.pump();
    room.mediaError('流读取错误');
    await tester.pump();
    room.mediaEnd();
    await tester.pump();
    expect(room.fake.opens, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(room.fake.opens, 1);
  });
  testWidgets('错误后恢复进度不打断当前连接', (tester) async {
    final room = _Room();
    room.playUrls.add('https://first/live.flv');
    room.currentLineIndex = 0;
    room.mediaError('短暂网络错误');
    await tester.pump();
    room.fake.state = const PlayerState(
        playing: true, buffering: true, position: Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(room.fake.opens, 0);
  });
  testWidgets('重复缓冲通知不延长断流超时', (tester) async {
    final room = _Room();
    room.liveStatus.value = true;
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 10));
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 5));
    expect(room.fake.opens, 1);
    room.mediaBuffering(false);
  });
  testWidgets('缓冲时 playing 为 false 仍可恢复卡住的流', (tester) async {
    final room = _Room();
    room.liveStatus.value = true;
    room.fake.state = const PlayerState(buffering: true);
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    room.mediaBuffering(true);
    await tester.pump(const Duration(seconds: 15));
    expect(room.fake.opens, 1);
    room.mediaBuffering(false);
  });
  testWidgets('手动切线取消上一条流待处理的错误', (tester) async {
    final room = _Room();
    room.playUrls.addAll(['https://first/live.flv', 'https://next/live.flv']);
    room.currentLineIndex = 0;
    room.mediaError('旧线路错误');
    room.changePlayLine(1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(room.fake.opens, 1);
    expect(room.currentLineIndex, 1);
  });
  testWidgets('旧流结束通知不关闭当前正常播放的直播', (tester) async {
    final room = _Room();
    room.liveStatus.value = true;
    room.playUrls.add('https://first/live.flv');
    room.currentLineIndex = 0;
    room.fake.state = const PlayerState(playing: true);
    room.mediaEnd();
    await tester.pump(const Duration(seconds: 3));
    expect(room.fake.opens, 0);
    expect(room.liveStatus.value, isTrue);
  });
  testWidgets('虎牙真正断流恢复时重新获取鉴权', (tester) async {
    final site = _Huya();
    final room =
        _Room(source: Site(id: 'huya', name: '', logo: '', liveSite: site));
    room.detail.value = LiveRoomDetail(
        roomId: '1',
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: true,
        url: '',
        data: '');
    room.qualites.add(LivePlayQuality(quality: '原画', data: {}));
    room.currentQuality = 0;
    room.currentLineIndex = 0;
    room.playUrls.addAll([
      'https://first/live.flv?token=old',
      'https://next/live.flv?token=old'
    ]);
    room.mediaError('断流');
    await tester.pump(const Duration(seconds: 3));
    expect(site.calls, 1);
    expect(room.playUrls.last, contains('token=new'));
    expect(room.fake.opens, 1);
    expect(room.currentLineIndex, 1);
  });
  testWidgets('B站断流时刷新过期播放地址', (tester) async {
    final site = _Bili();
    final room = _Room(
        source: Site(id: 'bilibili', name: '', logo: '', liveSite: site));
    room.detail.value = LiveRoomDetail(
        roomId: '1', title: '', cover: '', userName: '', userAvatar: '',
        online: 0, status: true, url: '', data: '');
    room.qualites.add(LivePlayQuality(quality: '原画', data: 10000));
    room.currentQuality = 0;
    room.currentLineIndex = 0;
    room.playUrls.addAll([
      'https://first/live.flv?token=old',
      'https://next/live.flv?token=old',
    ]);
    room.mediaError('断流');
    await tester.pump(const Duration(seconds: 3));
    expect(site.calls, 1);
    expect(room.playUrls.last, contains('token=new'));
    expect(room.fake.opens, 1);
    expect(room.currentLineIndex, 1);
  });
}
