import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';

class IptvPlayerController extends GetxController {
  late final List<AggregatedChannel> channels;
  late final List<String> epgUrls;
  int currentIndex;
  int currentLineIndex = 0;

  late final Player player;
  late final VideoController videoController;

  final currentTitle = "".obs;
  final controlsVisible = true.obs;
  final currentVolume = 100.0.obs;
  final FocusNode focusNode = FocusNode();

  Timer? _hideTimer;

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
    WakelockPlus.enable();
    play(currentIndex);
    showControls();
  }

  AggregatedChannel get currentChannel => channels[currentIndex];
  IptvLine get currentLine => currentChannel.lines[currentLineIndex];

  void play(int index) {
    if (index < 0 || index >= channels.length) return;
    currentIndex = index;
    currentLineIndex = 0;
    currentTitle.value = currentChannel.name;
    player.open(Media(currentLine.url), play: true);
    showControls();
  }

  void switchLine(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= currentChannel.lines.length) return;
    currentLineIndex = lineIndex;
    player.open(Media(currentLine.url), play: true);
    SmartDialog.showToast("已切换到 ${currentLine.sourceName} 线路");
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

  @override
  void onClose() {
    _hideTimer?.cancel();
    player.dispose();
    WakelockPlus.disable();
    focusNode.dispose();
  }
}
