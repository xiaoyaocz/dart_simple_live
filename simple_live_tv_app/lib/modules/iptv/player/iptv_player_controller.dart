import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';

class IptvPlayerController extends GetxController {
  late final List<AggregatedChannel> channels;
  int currentIndex;
  int currentLineIndex = 0;

  late final Player player;
  late final VideoController videoController;

  final currentTitle = "".obs;
  final controlsVisible = true.obs;
  final currentVolume = 100.0.obs;
  final FocusNode focusNode = FocusNode();

  Timer? _hideTimer;
  Timer? _bufferingTimer;

  /// 当前频道内已确认失败的线路 URL，自动换线时跳过
  final Set<String> _failedLineUrls = <String>{};
  /// 当前线路上因缓冲触发的重载次数，缓冲恢复后清零
  int _bufferReloadCount = 0;
  /// 最近一次实际打开的播放地址，用于丢弃换线后旧线路的迟到错误事件
  String _openedUrl = "";

  IptvPlayerController() : currentIndex = 0;

  @override
  void onInit() {
    final args = Get.arguments as Map<String, dynamic>;
    channels = args["channels"] as List<AggregatedChannel>;
    currentIndex = args["index"] as int;

    player = Player(configuration: const PlayerConfiguration(title: "Simple Live IPTV"));
    videoController = VideoController(
      player,
      configuration: MpvOptionsService.videoControllerConfiguration(),
    );
    _setup();
    super.onInit();
  }

  Future<void> _setup() async {
    await MpvOptionsService.applyToPlayer(player);
    player.stream.error.listen((msg) {
      Log.w("IPTV播放失败: $msg");
      _autoSwitchOnFailure("播放失败");
    });
    player.stream.volume.listen((v) => currentVolume.value = v);
    // 监听缓冲状态：超8秒先重载当前线路，重载后仍在缓冲则自动换线
    player.stream.buffering.listen((buffering) {
      _bufferingTimer?.cancel();
      if (buffering) {
        _bufferingTimer = Timer(const Duration(seconds: 8), _onBufferingTimeout);
      } else {
        // 缓冲恢复，当前线路恢复正常
        _bufferReloadCount = 0;
      }
    });
    WakelockPlus.enable();
    play(currentIndex);
    showControls();
  }

  AggregatedChannel get currentChannel => channels[currentIndex];
  IptvLine get currentLine => currentChannel.lines[currentLineIndex];

  void play(int index) {
    if (index < 0 || index >= channels.length) return;
    currentIndex = index;
    currentLineIndex = _initialLineIndex();
    _failedLineUrls.clear();
    _bufferReloadCount = 0;
    currentTitle.value = currentChannel.name;
    _bufferingTimer?.cancel();
    _openedUrl = currentLine.url;
    player.open(Media(currentLine.url), play: true);
    showControls();
  }

  /// 当前频道线路探测状态（播放页线路列表用）：0=检测中 1绿 2黄 3红
  final lineStatus = <String, int>{}.obs;
  /// 当前频道线路探测进行中
  final probing = false.obs;
  bool _probeCancelled = false;
  Dio? _probeDio;

  /// 线路排序权重：优先本次探测结果，其次最近已知状态；绿0 黄1 红或其他2
  int lineRank(String url) {
    final s = lineStatus[url] ??
        IptvService.instance.lastKnownLineInfo(url)?.status ??
        0;
    return switch (s) { 1 => 0, 2 => 1, _ => 2 };
  }

  /// 展示用状态：本次探测结果优先，回退最近已知
  int? displayStatus(String url) {
    final s = lineStatus[url];
    if (s != null && s > 0) return s;
    return IptvService.instance.lastKnownLineInfo(url)?.status;
  }

  /// 重新探测当前频道全部线路：忽略缓存强制刷新，结果实时更新并落盘
  Future<void> probeCurrentChannelLines() async {
    if (probing.value) return;
    _probeCancelled = false;
    probing.value = true;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {"Range": "bytes=0-1023"},
    ));
    _probeDio = dio;
    final urls = <String>[];
    final seen = <String>{};
    for (final l in currentChannel.lines) {
      if (seen.add(l.url)) {
        urls.add(l.url);
        lineStatus[l.url] = 0;
      }
    }
    const concurrency = 10;
    for (var i = 0; i < urls.length; i += concurrency) {
      if (_probeCancelled) break;
      final batch = urls.skip(i).take(concurrency).toList();
      await Future.wait(batch.map((url) async {
        final sw = Stopwatch()..start();
        try {
          await dio.get(url);
          final ms = sw.elapsedMilliseconds;
          _recordProbe(url, ms < 2000 ? 1 : 2, ms);
        } catch (e) {
          final ms = sw.elapsedMilliseconds;
          // 403/401但能连通也算可用，仅网络超时/连接失败标红
          if (e is DioException && (e.response?.statusCode ?? 0) > 0) {
            _recordProbe(url, ms < 2000 ? 1 : 2, ms);
          } else {
            _recordProbe(url, 3, ms);
          }
        }
      }));
    }
    probing.value = false;
    dio.close();
    if (_probeDio == dio) _probeDio = null;
  }

  void _recordProbe(String url, int status, int latencyMs) {
    if (_probeCancelled) return;
    lineStatus[url] = status;
    IptvService.instance.cacheLineStatus(url, status, latencyMs: latencyMs);
  }

  /// 频道起播线路自动寻优：上次手动选择的源优先；该源线路探测为红时改选
  /// 探测连通最快的线路，其次连通慢的线路；无探测结果时维持原优先级
  int _initialLineIndex() {
    final lines = currentChannel.lines;
    if (lines.isEmpty) return 0;
    final preferred = IptvService.instance.preferredLineSource;
    final preferredIndex = preferred.isEmpty
        ? -1
        : lines.indexWhere((e) => e.sourceName == preferred);
    if (preferredIndex >= 0 &&
        (IptvService.instance.freshLineStatus(lines[preferredIndex].url) ?? 1) != 3) {
      return preferredIndex;
    }
    final green = lines.indexWhere(
        (e) => IptvService.instance.freshLineStatus(e.url) == 1);
    if (green >= 0) return green;
    final yellow = lines.indexWhere(
        (e) => IptvService.instance.freshLineStatus(e.url) == 2);
    if (yellow >= 0) return yellow;
    return preferredIndex >= 0 ? preferredIndex : 0;
  }

  void switchLine(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= currentChannel.lines.length) return;
    currentLineIndex = lineIndex;
    // 手动选择的线路视为全新开始，并记忆该源偏好
    _failedLineUrls.clear();
    _bufferReloadCount = 0;
    _bufferingTimer?.cancel();
    _openedUrl = currentLine.url;
    IptvService.instance.setPreferredLineSource(currentLine.sourceName);
    player.open(Media(currentLine.url), play: true);
    SmartDialog.showToast("已切换到 ${currentLine.sourceName} 线路");
  }

  void switchChannel(int delta) => play(currentIndex + delta);

  /// 重新加载当前线路，解决临时卡顿问题
  void reloadCurrent() {
    _bufferingTimer?.cancel();
    _openedUrl = currentLine.url;
    player.open(Media(currentLine.url), play: true);
    showControls();
  }

  /// 缓冲超时：先重载当前线路一次，仍缓冲则判定线路不稳定并自动换线
  void _onBufferingTimeout() {
    // 定时器触发时若已切到其他地址，说明是旧线路的遗留状态，直接忽略
    if (_openedUrl != currentLine.url) return;
    if (_bufferReloadCount < 1) {
      _bufferReloadCount++;
      reloadCurrent();
    } else {
      _autoSwitchOnFailure("线路缓冲超时");
    }
  }

  /// 当前线路不可用时自动切换到本频道下一条未失败的线路，全部失败才提示
  void _autoSwitchOnFailure(String reason) {
    // 换线后旧线路的迟到错误事件，不再触发新的换线
    if (_openedUrl != currentLine.url) return;
    final lines = currentChannel.lines;
    var next = currentLineIndex + 1;
    while (next < lines.length && _failedLineUrls.contains(lines[next].url)) {
      next++;
    }
    if (next >= lines.length) {
      SmartDialog.showToast("$reason，本频道其余线路均不可用，可稍后重试或切换频道");
      return;
    }
    Log.w("IPTV自动换线: $reason，切到 ${lines[next].sourceName}");
    _failedLineUrls.add(currentLine.url);
    currentLineIndex = next;
    _bufferReloadCount = 0;
    _bufferingTimer?.cancel();
    _openedUrl = currentLine.url;
    player.open(Media(currentLine.url), play: true);
    SmartDialog.showToast("$reason，已自动切换到 ${currentLine.sourceName} 线路");
  }

  void togglePlayPause() {
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void setVolume(double value) {
    currentVolume.value = value;
    player.setVolume(value);
  }

  void toggleControls() {
    if (controlsVisible.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  void showControls() {
    controlsVisible.value = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () => controlsVisible.value = false);
  }

  void hideControls() {
    controlsVisible.value = false;
    _hideTimer?.cancel();
  }

  @override
  void onClose() {
    _hideTimer?.cancel();
    _bufferingTimer?.cancel();
    _probeCancelled = true;
    _probeDio?.close();
    _probeDio = null;
    player.dispose();
    WakelockPlus.disable();
    focusNode.dispose();
  }
}
