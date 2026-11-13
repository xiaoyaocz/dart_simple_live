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
  late final List<String> epgUrls;
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

  IptvPlayerController() : currentIndex = 0;

  @override
  void onInit() {
    final args = Get.arguments as Map<String, dynamic>;
    channels = args["channels"] as List<AggregatedChannel>;
    epgUrls = (args["epgUrls"] as List?)?.cast<String>() ?? const [];
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
      SmartDialog.showToast("播放失败，可尝试切换线路");
    });
    player.stream.volume.listen((v) => currentVolume.value = v);
    // 同步播放器播放状态到响应式变量
    player.stream.playing.listen((v) => isPlaying.value = v);
    // 监听缓冲状态，长时间缓冲自动重试，避免卡死暂停
    player.stream.buffering.listen((buffering) {
      _bufferingTimer?.cancel();
      if (buffering) {
        _bufferingTimer = Timer(const Duration(seconds: 8), reloadCurrent);
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
    currentTitle.value = currentChannel.name;
    player.open(Media(currentLine.url), play: true);
    showControls();
  }

  /// 切换当前频道的线路，无缝切换播放地址
  void switchLine(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= currentChannel.lines.length) return;
    currentLineIndex = lineIndex;
    player.open(Media(currentLine.url), play: true);
    SmartDialog.showToast("已切换到 ${currentLine.sourceName} 线路");
  }

  /// 重新加载当前线路，解决临时卡顿问题
  void reloadCurrent() {
    player.open(Media(currentLine.url), play: true);
    showControls();
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
