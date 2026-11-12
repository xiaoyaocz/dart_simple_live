import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';
import 'package:simple_live_tv_app/models/db/iptv_playlist.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/iptv_channel.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/iptv_program.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/xmltv_parser.dart';
import 'package:simple_live_tv_app/requests/http_client.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';

class IptvPlayerController extends GetxController {
  late final List<PlayItem> items;
  late final List<String> epgUrls;
  int currentIndex;

  late final Player player;
  late final VideoController videoController;

  final currentTitle = "".obs;
  final epgData = Rxn<EpgData>();
  final nowProgram = Rxn<IptvProgram>();
  final nextProgram = Rxn<IptvProgram>();
  final loadingEpg = false.obs;

  final userPaused = false.obs;
  final controlsVisible = true.obs;
  // 收藏状态版本号，驱动 Obx 重建
  final favoriteVersion = 0.obs;

  final FocusNode focusNode = FocusNode();
  Timer? _epgTimer;
  Timer? _hideTimer;

  IptvPlayerController() : currentIndex = 0;

  @override
  void onInit() {
    final args = Get.arguments as Map<String, dynamic>;
    final playlist = args["playlist"] as IptvPlaylist?;
    final channels = args["channels"] as List<IptvChannel>?;
    final favorites = args["favorites"] as List<IptvFavorite>?;
    if (channels != null) {
      items = channels
          .map((channel) => PlayItem.fromChannel(playlist!, channel))
          .toList();
    } else {
      items = favorites!.map((favorite) => PlayItem.fromFavorite(favorite)).toList();
    }
    epgUrls = (args["epgUrls"] as List?)?.cast<String>() ?? const [];
    currentIndex = args["index"] as int;

    player = Player(
      configuration: const PlayerConfiguration(title: "Simple Live IPTV"),
    );
    videoController = VideoController(
      player,
      configuration: MpvOptionsService.videoControllerConfiguration(),
    );
    _setup();
    super.onInit();
  }

  Future<void> _setup() async {
    await MpvOptionsService.applyToPlayer(player);
    // 播放失败仅提示，不中断使用
    player.stream.error.listen((message) {
      Log.w("IPTV 播放失败: $message");
      SmartDialog.showToast("播放失败，可尝试切换其他频道");
    });
    WakelockPlus.enable();
    showControls();
    // 先开播，节目单后台加载，避免大 EPG 拖慢起播
    play(currentIndex);
    await loadEpg();
    // 每分钟刷新当前/下一档节目
    _epgTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => updateEpgView(),
    );
  }

  PlayItem get current => items[currentIndex];

  /// 打开指定位置的频道
  void play(int index) {
    if (index < 0 || index >= items.length) return;
    currentIndex = index;
    currentTitle.value = current.name;
    userPaused.value = false;
    player.open(Media(current.url), play: true);
    updateEpgView();
    showControls();
  }

  void switchChannel(int delta) => play(currentIndex + delta);

  void togglePlayPause() {
    if (player.state.playing) {
      player.pause();
      userPaused.value = true;
    } else {
      player.play();
      userPaused.value = false;
    }
  }

  void adjustVolume(int delta) {
    final target = (player.state.volume + delta).clamp(0, 100);
    player.setVolume(target.toDouble());
  }

  // ===== 控制栏显隐 =====

  void showControls() {
    controlsVisible.value = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      controlsVisible.value = false;
    });
  }

  void hideControls() {
    controlsVisible.value = false;
    _hideTimer?.cancel();
  }

  void toggleControls() {
    if (controlsVisible.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  // ===== EPG =====

  /// 拉取并解析第一份 EPG，失败不影响播放
  Future<void> loadEpg() async {
    if (epgUrls.isEmpty) return;
    loadingEpg.value = true;
    try {
      final content = await HttpClient.instance.getText(epgUrls.first);
      epgData.value = XmltvParser.parse(content);
      updateEpgView();
    } catch (e) {
      Log.w("IPTV EPG 加载失败: $e");
    } finally {
      loadingEpg.value = false;
    }
  }

  void updateEpgView() {
    final data = epgData.value;
    if (data == null) {
      nowProgram.value = null;
      nextProgram.value = null;
      return;
    }
    nowProgram.value = data.nowPlaying(current.epgId);
    nextProgram.value = data.nextProgram(current.epgId);
  }

  // ===== 收藏 =====

  bool get isFavorite => isItemFavorite(current);

  void toggleFavorite() => toggleItemFavorite(current);

  bool isItemFavorite(PlayItem item) =>
      IptvService.instance.isFavorite(item.favoriteId);

  /// 收藏/取消收藏指定频道，不改变当前播放
  void toggleItemFavorite(PlayItem item) {
    final service = IptvService.instance;
    if (service.isFavorite(item.favoriteId)) {
      service.favoriteBox.delete(item.favoriteId);
    } else {
      service.favoriteBox.put(
        item.favoriteId,
        IptvFavorite(
          id: item.favoriteId,
          playlistId: item.playlistId,
          channelId: item.epgId,
          name: item.name,
          logo: item.logo,
          group: item.group,
          url: item.url,
        ),
      );
    }
    favoriteVersion.value++;
  }

  @override
  void onClose() {
    _epgTimer?.cancel();
    _hideTimer?.cancel();
    WakelockPlus.disable();
    player.dispose();
    focusNode.dispose();
  }
}

/// 播放页统一的频道数据，屏蔽订阅频道与收藏频道的类型差异
class PlayItem {
  final String name;
  final String logo;
  final String url;
  final String epgId;
  final String playlistId;
  final String favoriteId;
  final String group;

  const PlayItem({
    required this.name,
    required this.logo,
    required this.url,
    required this.epgId,
    required this.playlistId,
    required this.favoriteId,
    required this.group,
  });

  factory PlayItem.fromChannel(IptvPlaylist playlist, IptvChannel channel) {
    return PlayItem(
      name: channel.name,
      logo: channel.logo,
      url: channel.url,
      epgId: channel.id,
      playlistId: playlist.id,
      favoriteId: IptvService.favoriteId(playlist.id, channel.url),
      group: channel.group,
    );
  }

  factory PlayItem.fromFavorite(IptvFavorite favorite) {
    return PlayItem(
      name: favorite.name,
      logo: favorite.logo,
      url: favorite.url,
      epgId: favorite.channelId,
      playlistId: favorite.playlistId,
      favoriteId: favorite.id,
      group: favorite.group,
    );
  }
}
