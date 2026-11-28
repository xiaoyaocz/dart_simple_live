import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/simple_live_core.dart';

// No visible renderer: VO:null measures decoded output, not screen presentation.
Future<void> main(List<String> args) async {
  final baseline = args.contains('--baseline');
  final rounds = args.contains('--three-rounds') ? 3 : 1;
  final results = <Map<String, Object?>>[];
  CoreLog.enableLog = false;
  MediaKit.ensureInitialized(
    libmpv: File(
      'simple_live_app/build/windows/x64/runner/Release/libmpv-2.dll',
    ).absolute.path,
  );
  final site = HuyaSite();
  for (var round = 0; round < rounds; round++) {
    for (final name in args.contains('--2k-only') ? ['2K'] : ['2K', '4K']) {
      final total = Stopwatch()..start();
      final result = <String, Object?>{
        'mode': baseline ? 'previous' : 'fixed',
        'round': round + 1,
        'quality': name,
      };
      Player? player;
      StreamSubscription<PlayerLog>? subscription;
      try {
        final detail = await site.getRoomDetail(roomId: '660000');
        result['detailMs'] = total.elapsedMilliseconds;
        final qualities = await site.getPlayQualites(detail: detail);
        final quality = qualities.firstWhere((q) => q.quality == name);
        LivePlayUrl urls;
        if (baseline) {
          final lines = List<HuyaLineModel>.from(quality.data['urls']);
          final ordered = [
            ...lines.where((l) => l.lineType == HuyaLineType.hls),
            ...lines.where((l) => l.lineType == HuyaLineType.flv),
          ];
          urls = LivePlayUrl(
            urls: await Future.wait(
              ordered.map(
                (l) => site.getPlayUrl(l, quality.data['bitRate'], codec: 265),
              ),
            ),
            headers: {'user-agent': HuyaSite.HYSDK_UA},
          );
        } else {
          urls = await site.getPlayUrls(detail: detail, quality: quality);
        }
        result['urlReadyMs'] = total.elapsedMilliseconds;
        result['host'] = Uri.parse(urls.urls.first).host;
        result['transport'] = Uri.parse(urls.urls.first).path.endsWith('.m3u8')
            ? 'hls'
            : 'flv';
        player = Player(
          configuration: const PlayerConfiguration(
            vo: 'null',
            bufferSize: 64 * 1024 * 1024,
            logLevel: MPVLogLevel.info,
          ),
        );
        final native = player.platform as NativePlayer;
        for (final e in {
          'ao': 'null',
          'vid': 'auto',
          'cache-on-disk': 'no',
          'cache-secs': '20',
          'demuxer-max-back-bytes': '4194304',
          'cache-pause': 'yes',
          'cache-pause-wait': '0.5',
          'cache-pause-initial': 'yes',
          'network-timeout': '5',
        }.entries) {
          await native.setProperty(e.key, e.value);
        }
        final output = Completer<void>();
        final opening = Stopwatch()..start();
        subscription = player.stream.log.listen((log) {
          if (log.text.startsWith('VO:') && !output.isCompleted) {
            final size = RegExp(r'(\d+)x(\d+)').firstMatch(log.text);
            result['width'] = int.tryParse(size?.group(1) ?? '');
            result['height'] = int.tryParse(size?.group(2) ?? '');
            result['decodedOutputMs'] = opening.elapsedMilliseconds;
            result['totalToDecodedOutputMs'] = total.elapsedMilliseconds;
            output.complete();
          }
        });
        await player.open(Media(urls.urls.first, httpHeaders: urls.headers));
        await output.future.timeout(const Duration(seconds: 12));
        result['status'] = 'decoded';
      } catch (e) {
        result['status'] = 'failed';
        result['errorType'] = e.runtimeType.toString();
      } finally {
        await subscription?.cancel();
        await player?.dispose();
        results.add(result);
        stdout.writeln(jsonEncode(result));
      }
    }
  }
  exit(results.any((r) => r['status'] != 'decoded') ? 1 : 0);
}
