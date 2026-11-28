import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// Headless Windows libmpv soak probe. Measures playback clock/network/RSS,
/// not on-screen frames, decoder throughput or mobile rendering performance.
Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (final arg in args) {
    final split = arg.indexOf('=');
    if (!arg.startsWith('--') || split < 3) {
      stderr.writeln('Arguments must use --name=value');
      exit(64);
    }
    options[arg.substring(2, split)] = arg.substring(split + 1);
  }
  const allowed = {'libmpv', 'seconds', 'rounds', 'platforms', 'output', 'line'};
  final line = int.tryParse(options['line'] ?? '0') ?? -1;
  final seconds = int.tryParse(options['seconds'] ?? '60') ?? 0;
  final rounds = int.tryParse(options['rounds'] ?? '1') ?? 0;
  final dll = options['libmpv'] ??
      'simple_live_app/build/windows/x64/runner/Release/libmpv-2.dll';
  final output = File(options['output'] ?? 'native-live-performance.json');
  final selected = (options['platforms'] ?? 'huya,bilibili,douyu,douyin').split(',');
  if (!Platform.isWindows || line < 0 || seconds < 10 || seconds > 7200 ||
      rounds < 1 || rounds > 100 || options.keys.any((k) => !allowed.contains(k)) ||
      selected.any((s) => !{'huya','bilibili','douyu','douyin'}.contains(s)) ||
      !File(dll).existsSync() || output.existsSync()) {
    stderr.writeln('Requires Windows, existing --libmpv, seconds=10..7200, '
        'rounds=1..100, known platforms and a new output path.');
    exit(64);
  }
  MediaKit.ensureInitialized(libmpv: File(dll).absolute.path);
  CoreLog.enableLog = false;
  final results = <Map<String, Object?>>[];
  // Some upstream parsers print responses directly. Never emit signed URLs.
  await runZoned(() async {
    for (var round = 0; round < rounds; round++) {
      for (final name in selected) {
        final LiveSite site = switch (name) {
          'huya' => HuyaSite(), 'bilibili' => BiliBiliSite(),
          'douyu' => DouyuSite(), _ => DouyinSite(),
        };
        final watch = Stopwatch()..start();
        final result = <String, Object?>{'platform':name, 'round':round + 1};
        Player? player;
        final subscriptions = <StreamSubscription<dynamic>>[];
        try {
          final rooms = await site.getRecommendRooms().timeout(const Duration(seconds: 20));
          LiveRoomDetail? detail;
          for (final room in rooms.items.take(3)) {
            final candidate = await site.getRoomDetail(roomId: room.roomId)
                .timeout(const Duration(seconds: 20));
            if (candidate.status || candidate.isRecord) { detail = candidate; break; }
          }
          if (detail == null) throw StateError('No live room in sample');
          result['roomId'] = detail.roomId;
          final qualities = await site.getPlayQualites(detail:detail)
              .timeout(const Duration(seconds:20));
          final urls = await site.getPlayUrls(detail:detail, quality:qualities.first)
              .timeout(const Duration(seconds:20));
          result['availableLines'] = urls.urls.length;
          result['line'] = line;
          if (line >= urls.urls.length) throw StateError('Requested stream line unavailable');
          result['requestMs'] = watch.elapsedMilliseconds;
          result['cdnHost'] = Uri.parse(urls.urls[line]).host;
          player = Player(configuration:const PlayerConfiguration(
              vo:'null', bufferSize:64 * 1024 * 1024, logLevel:MPVLogLevel.error));
          final native = player.platform as NativePlayer;
          for (final entry in const {
            'ao':'null', 'cache-on-disk':'no', 'cache-secs':'20',
            'demuxer-max-back-bytes':'4194304', 'cache-pause':'yes',
            'cache-pause-wait':'0.5', 'cache-pause-initial':'yes', 'network-timeout':'10',
          }.entries) {
            await native.setProperty(entry.key,entry.value);
          }
          int? firstProgress;
          var buffering = false, rebufferEvents = 0, errors = 0;
          watch.reset();
          subscriptions.add(player.stream.position.listen((position) {
            if (position > Duration.zero) firstProgress ??= watch.elapsedMilliseconds;
          }));
          subscriptions.add(player.stream.buffering.listen((value) {
            if (value && !buffering && firstProgress != null) rebufferEvents++;
            buffering = value;
          }));
          subscriptions.add(player.stream.error.listen((_) => errors++));
          await player.open(Media(urls.urls[line],httpHeaders:urls.headers));
          var lastPosition = Duration.zero, lastAdvance = 0, longestGap = 0;
          final samples = <Map<String,Object?>>[];
          for (var second = 0; second < seconds; second++) {
            await Future<void>.delayed(const Duration(seconds:1));
            final state = player.state;
            final now = watch.elapsedMilliseconds;
            if (state.position > lastPosition) {
              lastPosition = state.position;
              lastAdvance = now;
            } else if (firstProgress != null && now - lastAdvance > longestGap) {
              longestGap = now - lastAdvance;
            }
            samples.add({'elapsedMs':now, 'positionMs':state.position.inMilliseconds,
              'bufferMs':state.buffer.inMilliseconds, 'buffering':state.buffering,
              'rssBytes':ProcessInfo.currentRss});
          }
          result.addAll({'status':firstProgress == null ? 'no-progress':'sampled',
            'headless':true, 'firstProgressMs':firstProgress,
            'sdkRebufferEvents':rebufferEvents, 'playerErrors':errors,
            'longestObservedNoProgressMs':longestGap, 'samples':samples});
        } catch (error) {
          result.addAll({'status':'failed', 'errorType':error.runtimeType.toString()});
        } finally {
          for (final sub in subscriptions) { await sub.cancel(); }
          await player?.dispose();
          results.add(result);
        }
      }
    }
  },zoneSpecification:ZoneSpecification(print:(_,__,___,____){}));
  await output.parent.create(recursive:true);
  final temporary = File('${output.path}.tmp');
  await temporary.writeAsString(const JsonEncoder.withIndent('  ').convert({
    'schema':1,'utc':DateTime.now().toUtc().toIso8601String(),
    'secondsPerStream':seconds,'rounds':rounds,'results':results,
    'limits':'Headless playback clock and process RSS only; not video FPS or mobile validation.',
  }));
  await temporary.rename(output.path);
  stdout.writeln('Saved ${output.absolute.path}');
  for (final result in results) {
    stdout.writeln('${result['platform']} round=${result['round']} '
        'status=${result['status']} firstProgressMs=${result['firstProgressMs']} '
        'sdkRebufferEvents=${result['sdkRebufferEvents']}');
  }
  exit(results.any((r) => r['status'] != 'sampled') ? 1 : 0);
}
