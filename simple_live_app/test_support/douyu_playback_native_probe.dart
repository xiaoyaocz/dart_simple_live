import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/simple_live_core.dart';

// Real public room metadata and playback only. Never logs signed URLs or sends chat.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  CoreLog.enableLog = false;
  final log = File(args.single);
  void record(String line) =>
      log.writeAsStringSync('$line\n', mode: FileMode.append);
  final watchdog = Timer(const Duration(seconds: 110), () {
    record('FAIL watchdog');
    exit(1);
  });
  runApp(const SizedBox());
  String stage = 'detail';
  Player? player;
  try {
    final site = DouyuSite();
    final watch = Stopwatch()..start();
    site.prefetchRoom('123455');
    final detail = await site.getRoomDetail(roomId: '123455');
    record(
        'PASS alias=123455 canonical=${detail.roomId} live=${detail.status} detailMs=${watch.elapsedMilliseconds}');
    if (detail.roomId != '5526219') throw StateError('Wrong canonical room');
    if (!detail.status && !detail.isRecord)
      throw StateError('Room is offline during probe');
    stage = 'qualities';
    final qualities = await site.getPlayQualites(detail: detail);
    record('PASS qualities=${qualities.length}');
    if (qualities.isEmpty) throw StateError('No qualities');
    stage = 'stream_urls';
    final urls =
        await site.getPlayUrls(detail: detail, quality: qualities.last);
    record('PASS playableCandidates=${urls.urls.length}');
    if (urls.urls.isEmpty) throw StateError('No stream');
    stage = 'native_playback';
    player = Player();
    final dynamic native = player.platform;
    await native.setProperty('vo', 'null');
    await native.setProperty('ao', 'null');
    // MediaKit defaults to vid=no until a VideoController is attached. This
    // headless probe explicitly enables decoding without opening a video UI.
    await native.setProperty('vid', 'auto');
    await native.setProperty('network-timeout', '10');
    await player.setVolume(0);
    await player.open(Media(urls.urls.first, httpHeaders: urls.headers));
    final deadline = Stopwatch()..start();
    while (deadline.elapsed < const Duration(seconds: 25)) {
      final state = player.state;
      if (state.position >= const Duration(seconds: 1) &&
          (state.videoParams.w ?? 0) > 0) {
        record(
            'PASS nativePlayback positionMs=${state.position.inMilliseconds} width=${state.videoParams.w} height=${state.videoParams.h}');
        await player.dispose();
        watchdog.cancel();
        record(
            'PASS real public Douyu alias -> detail -> signing -> quality -> CDN -> native playback; no chat sent');
        exit(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    record('FAIL playerState playing=${player.state.playing} '
        'positionMs=${player.state.position.inMilliseconds} '
        'width=${player.state.videoParams.w}');
    throw TimeoutException('Native playback did not advance');
  } catch (error, stack) {
    record('FAIL stage=$stage type=${error.runtimeType}\n$stack');
    await player?.dispose();
    watchdog.cancel();
    exit(1);
  }
}
