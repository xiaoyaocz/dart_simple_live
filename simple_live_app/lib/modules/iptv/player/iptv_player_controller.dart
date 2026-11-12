import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/modules/iptv/parser/iptv_channel.dart';
import 'package:simple_live_app/modules/iptv/parser/iptv_program.dart';
import 'package:simple_live_app/modules/iptv/parser/xmltv_parser.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';

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
  final controlsVisible = true.obs;

  Timer? _epgTimer;

  IptvPlayerController() : currentIndex = 0;

  @override
  void onInit() {
    final args = Get.arguments as Map<String, dynamic>;
    final channels = args["channels"] as List<IptvChannel>?;
    final favorites = args["favorites"] as List<IptvFavorite>?;
    if (channels != null) {
      items = channels
          .map((channel) => PlayItem(
                name: channel.name,
                logo: channel.logo,
                url: channel.url,
                epgId: channel.id,
              ))
          .toList();
    } else {
      items = favorites!
          .map((favorite) => PlayItem(
                name: favorite.name,
                logo: favorite.logo,
                url: favorite.url,
                epgId: favorite.channelId,
              ))
          .toList();
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
    player.open(Media(current.url), play: true);
    updateEpgView();
  }

  void switchChannel(int delta) => play(currentIndex + delta);

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

  void toggleControls() => controlsVisible.value = !controlsVisible.value;

  @override
  void onClose() {
    _epgTimer?.cancel();
    player.dispose();
  }
}

/// 播放页统一的频道数据，屏蔽订阅频道与收藏频道的类型差异
class PlayItem {
  final String name;
  final String logo;
  final String url;
  final String epgId;

  const PlayItem({
    required this.name,
    required this.logo,
    required this.url,
    required this.epgId,
  });
}
