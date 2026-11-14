import 'dart:async';
import 'dart:io';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';

class IptvPlayerController extends GetxController {
  late final List<AggregatedChannel> channels;
  int currentIndex;
  int currentLineIndex = 0;

  late final Player player;
  late final VideoController videoController;

  final currentTitle = "".obs;
  final controlsVisible = true.obs;
  final isFullScreen = false.obs;
  final currentVolume = 100.0.obs;
  /// 响应式播放状态，驱动按钮图标切换
  final isPlaying = false.obs;

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
    // 同步播放器播放状态到响应式变量
    player.stream.playing.listen((v) => isPlaying.value = v);
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
    play(currentIndex);
    showControls();
  }

  AggregatedChannel get currentChannel => channels[currentIndex];
  IptvLine get currentLine => currentChannel.lines[currentLineIndex];

  /// 播放指定频道，默认使用第一条线路
  void play(int index) {
    if (index < 0 || index >= channels.length) return;
    currentIndex = index;
    currentLineIndex = 0;
    _failedLineUrls.clear();
    _bufferReloadCount = 0;
    currentTitle.value = currentChannel.name;
    _bufferingTimer?.cancel();
    _openedUrl = currentLine.url;
    player.open(Media(currentLine.url), play: true);
    showControls();
  }

  /// 切换当前频道的线路，无缝切换播放地址
  void switchLine(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= currentChannel.lines.length) return;
    currentLineIndex = lineIndex;
    // 手动选择的线路视为全新开始
    _failedLineUrls.clear();
    _bufferReloadCount = 0;
    _bufferingTimer?.cancel();
    _openedUrl = currentLine.url;
    player.open(Media(currentLine.url), play: true);
    SmartDialog.showToast("已切换到 ${currentLine.sourceName} 线路");
  }

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

  void switchChannel(int delta) => play(currentIndex + delta);

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

  /// 双击切换全屏
  Future<void> onDoubleTap() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (isFullScreen.value) {
        await windowManager.setFullScreen(false);
        isFullScreen.value = false;
      } else {
        await windowManager.setFullScreen(true);
        isFullScreen.value = true;
      }
    }
  }

  void onLongPress() {
    SmartDialog.showToast("快捷入口");
  }

  @override
  void onClose() {
    _hideTimer?.cancel();
    _bufferingTimer?.cancel();
    player.dispose();
    if (isFullScreen.value) windowManager.setFullScreen(false);
  }
}
