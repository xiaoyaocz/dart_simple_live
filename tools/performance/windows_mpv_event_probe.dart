import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/modules/live_room/player/windows_playback_events.dart';

/// Run with the app package config and the path to the bundled libmpv DLL.
Future<void> main(List<String> args) async {
  MediaKit.ensureInitialized(libmpv: File(args.single).absolute.path);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  });
  final player = Player(configuration: const PlayerConfiguration(vo: 'null'));
  final native = player.platform as NativePlayer;
  final received = <int>[];
  final failed = Completer<void>();
  final events = WindowsPlaybackEvents(await native.handle, (revision, _) {
    received.add(revision);
    if (!failed.isCompleted) failed.complete();
  });
  Future<int> open(String path) async {
    await player.open(Media('http://127.0.0.1:${server.port}/$path'));
    return int.parse(await native.getProperty('playlist/0/id'));
  }

  try {
    final old = await open('old.flv');
    await Future<void>.delayed(const Duration(seconds: 1));
    final current = await open('current.flv');
    if (old == current) throw StateError('mpv reused the entry ID');
    events.track(2, current);
    await failed.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (received.length != 1 || received.single != 2) {
      throw StateError('Unexpected failure attribution: $received');
    }
    stdout.writeln(
      'PASS: stale native failure ignored, current failure attributed',
    );
  } finally {
    events.dispose();
    await player.dispose();
    await server.close(force: true);
  }
}
