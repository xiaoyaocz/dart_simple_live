import 'dart:async';
import 'dart:io';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_slot.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:window_manager/window_manager.dart';

class MultiViewTileRuntime {
  MultiViewTileRuntime(this.index);

  final int index;
  final Rxn<MultiViewRoomRef> room = Rxn<MultiViewRoomRef>();
  final Rxn<LiveRoomDetail> detail = Rxn<LiveRoomDetail>();
  final RxList<LivePlayQuality> qualities = RxList<LivePlayQuality>();
  final RxInt currentQualityIndex = (-1).obs;
  final RxString currentQualityName = ''.obs;
  final RxBool loading = false.obs;
  final RxBool offline = false.obs;
  final RxString errorMsg = ''.obs;
  final RxBool hasPlayer = false.obs;

  Player? player;
  VideoController? videoController;
  int generation = 0;
  bool configured = false;

  Future<void> ensurePlayer() async {
    if (player != null && videoController != null) return;
    final settings = AppSettingsController.instance;
    final createdPlayer = Player(
      configuration: PlayerConfiguration(
        title: 'Simple Live MultiView #$index',
        bufferSize: (settings.playerBufferSize.value.clamp(16, 256) ~/ 2)
                .clamp(16, 128) *
            1024 *
            1024,
        logLevel: settings.logEnable.value
            ? MPVLogLevel.info
            : MPVLogLevel.error,
      ),
    );
    final createdVideo = VideoController(
      createdPlayer,
      configuration: settings.outputPolicy.videoConfiguration(
        custom: settings.customPlayerOutput.value,
        compatibility: settings.playerCompatMode.value,
        hardwareDecode: settings.hardwareDecode.value,
        videoOutput: settings.videoOutputDriver.value,
        hardwareDecoder: settings.videoHardwareDecoder.value,
      ),
    );
    player = createdPlayer;
    videoController = createdVideo;
    configured = false;
    hasPlayer.value = true;
    await _configurePlayer(createdPlayer);
  }

  Future<void> _configurePlayer(Player target) async {
    if (configured) return;
    configured = true;
    try {
      final platform = target.platform;
      if (platform is NativePlayer) {
        if (Platform.isWindows) {
          await platform.setProperty('http-proxy', '');
        }
        await platform.setProperty('interpolation', 'no');
        await platform.setProperty('video-sync', 'audio');
        await platform.setProperty('cache-on-disk', 'no');
        await platform.setProperty('cache-secs', '15');
        await platform.setProperty('demuxer-max-back-bytes', '2097152');
        await platform.setProperty('cache-pause', 'yes');
        await platform.setProperty('cache-pause-wait', '0.5');
        await platform.setProperty('network-timeout', '10');
        await platform.setProperty(
          'stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=2',
        );
      }
    } catch (e) {
      Log.d('多画面播放器配置失败：$e');
    }
  }

  Future<void> clearAndDispose() async {
    generation++;
    room.value = null;
    detail.value = null;
    qualities.clear();
    currentQualityIndex.value = -1;
    currentQualityName.value = '';
    loading.value = false;
    offline.value = false;
    errorMsg.value = '';
    hasPlayer.value = false;
    final p = player;
    player = null;
    videoController = null;
    configured = false;
    if (p != null) {
      try {
        await p.dispose();
      } catch (e) {
        Log.d('释放多画面播放器失败：$e');
      }
    }
  }
}

class MultiViewController extends GetxController {
  final MultiViewLayoutState layoutState =
      MultiViewLayoutState(initialLayout: 2);
  late final List<MultiViewTileRuntime> tiles =
      List.generate(MultiViewLayoutState.maxSlots, MultiViewTileRuntime.new);

  final RxInt layoutCount = 2.obs;
  final RxInt activeAudioIndex = (-1).obs;
  final RxBool mutedAll = false.obs;
  final RxBool fullScreen = false.obs;
  final RxString volumeHintText = ''.obs;
  Timer? _volumeHintTimer;
  bool _togglingFullScreen = false;
  bool _openingSingleRoom = false;
  bool _closed = false;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<FollowService>() &&
        FollowService.instance.followList.isEmpty) {
      unawaited(FollowService.instance.loadData());
    }
  }

  Future<void> setLayoutCount(int count) async {
    final evicted = layoutState.setLayoutCount(count);
    layoutCount.value = layoutState.layoutCount;
    activeAudioIndex.value = layoutState.activeAudioIndex;
    for (final index in evicted) {
      await tiles[index].clearAndDispose();
    }
    await _syncAudioVolumes();
  }

  Future<void> assignFollowUser(int index, FollowUser user) async {
    final ref = MultiViewRoomRef(
      siteId: user.siteId,
      roomId: user.roomId,
      userName: user.userName,
      face: user.face,
    );
    if (!layoutState.assignSlot(index, ref)) {
      SmartDialog.showToast('该直播间已在其他窗口中播放');
      return;
    }
    activeAudioIndex.value = layoutState.activeAudioIndex;
    tiles[index].room.value = ref;
    await _loadTile(index, ref);
  }

  Future<void> removeSlot(int index) async {
    layoutState.clearSlot(index);
    activeAudioIndex.value = layoutState.activeAudioIndex;
    await tiles[index].clearAndDispose();
    await _syncAudioVolumes();
  }

  Future<void> selectAudioSlot(int index) async {
    if (!layoutState.setActiveAudio(index)) return;
    activeAudioIndex.value = layoutState.activeAudioIndex;
    mutedAll.value = layoutState.mutedAll;
    await _syncAudioVolumes();
  }

  Future<void> toggleMuteAll() async {
    layoutState.toggleMutedAll();
    mutedAll.value = layoutState.mutedAll;
    await _syncAudioVolumes();
  }

  /// 滚轮上下调节当前选中窗口音量（与单直播间步进一致：±5%，范围 0~100%）。
  Future<void> adjustActiveVolumeOnScroll(double scrollDeltaY) async {
    if (scrollDeltaY == 0) return;
    final idx = activeAudioIndex.value;
    if (idx < 0 || layoutState.slotAt(idx) == null) return;
    final settings = AppSettingsController.instance;
    final nextVolume =
        volumeAfterScroll(settings.playerVolume.value, scrollDeltaY);
    if (mutedAll.value && scrollDeltaY < 0) {
      layoutState.setMutedAll(false);
      mutedAll.value = false;
    }
    settings.setPlayerVolume(nextVolume);
    _showVolumeHint('音量 ${nextVolume.round()}%');
    await _syncAudioVolumes();
  }

  void _showVolumeHint(String text) {
    volumeHintText.value = text;
    _volumeHintTimer?.cancel();
    _volumeHintTimer = Timer(const Duration(milliseconds: 1200), () {
      volumeHintText.value = '';
    });
  }

  Future<void> refreshSlot(int index) async {
    final ref = layoutState.slotAt(index);
    if (ref == null) return;
    await _loadTile(index, ref);
  }

  /// 刷新当前选中的直播间窗口（对应快捷键 R）。
  Future<void> refreshSelectedSlot() async {
    final idx = activeAudioIndex.value;
    if (idx < 0 || layoutState.slotAt(idx) == null) return;
    await refreshSlot(idx);
  }

  Future<void> refreshAll() async {
    final futures = <Future<void>>[];
    for (var i = 0; i < layoutState.layoutCount; i++) {
      final ref = layoutState.slotAt(i);
      if (ref != null) {
        futures.add(_loadTile(i, ref));
      }
    }
    await Future.wait(futures);
  }

  Future<void> changeSlotQuality(int index, int qualityIndex) async {
    final tile = tiles[index];
    final ref = layoutState.slotAt(index);
    final roomDetail = tile.detail.value;
    if (ref == null || roomDetail == null) return;
    if (qualityIndex < 0 || qualityIndex >= tile.qualities.length) return;
    final site = Sites.allSites[ref.siteId];
    if (site == null) return;

    final gen = ++tile.generation;
    tile.loading.value = true;
    tile.errorMsg.value = '';
    try {
      final quality = tile.qualities[qualityIndex];
      final playUrl = await site.liveSite.getPlayUrls(
        detail: roomDetail,
        quality: quality,
      );
      if (_closed || gen != tile.generation) return;
      if (playUrl.urls.isEmpty) {
        tile.errorMsg.value = '未获取到播放地址';
        return;
      }
      tile.currentQualityIndex.value = qualityIndex;
      tile.currentQualityName.value =
          Utils.playbackQualityLabel(quality.quality, playUrl.actualQuality);
      await _openStream(tile, playUrl.urls.first, playUrl.headers, gen);
    } catch (e) {
      if (_closed || gen != tile.generation) return;
      tile.errorMsg.value = '切换清晰度失败';
      Log.d('多画面切换清晰度失败：$e');
    } finally {
      if (!_closed && gen == tile.generation) {
        tile.loading.value = false;
      }
    }
  }

  /// 进入当前选中直播间的完整单窗口页面（对应鼠标前侧键）。
  Future<void> openSelectedInSingleRoom() async {
    final idx = activeAudioIndex.value;
    if (idx < 0 || layoutState.slotAt(idx) == null) return;
    await openInSingleRoom(idx);
  }

  Future<void> openInSingleRoom(int index) async {
    if (_openingSingleRoom) return;
    final ref = layoutState.slotAt(index);
    if (ref == null) return;
    final site = Sites.allSites[ref.siteId];
    if (site == null) return;

    _openingSingleRoom = true;
    final wasFullScreen = fullScreen.value;
    try {
      if (wasFullScreen) {
        await exitFullScreen();
      }
      // Pause multi-view players while viewing single room to avoid audio overlap.
      final playingSlots = <int>[];
      for (var i = 0; i < layoutState.layoutCount; i++) {
        final p = tiles[i].player;
        if (p != null && p.state.playing) {
          playingSlots.add(i);
          await p.pause();
        }
      }
      await AppNavigator.toLiveRoomDetail(site: site, roomId: ref.roomId);
      if (_closed) return;
      for (final i in playingSlots) {
        if (layoutState.slotAt(i) != null) {
          await tiles[i].player?.play();
        }
      }
      await _syncAudioVolumes();
    } finally {
      _openingSingleRoom = false;
    }
  }

  Future<void> toggleFullScreen() async {
    if (!Platform.isWindows || _togglingFullScreen) return;
    _togglingFullScreen = true;
    try {
      final current = await windowManager.isFullScreen();
      final next = !current;
      fullScreen.value = next;
      await windowManager.setFullScreen(next);
      fullScreen.value = await windowManager.isFullScreen();
    } finally {
      _togglingFullScreen = false;
    }
  }

  Future<void> exitFullScreen() async {
    if (!Platform.isWindows || _togglingFullScreen) return;
    _togglingFullScreen = true;
    try {
      fullScreen.value = false;
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      fullScreen.value = await windowManager.isFullScreen();
    } finally {
      _togglingFullScreen = false;
    }
  }

  Future<void> _loadTile(int index, MultiViewRoomRef ref) async {
    final tile = tiles[index];
    final site = Sites.allSites[ref.siteId];
    if (site == null) {
      tile.errorMsg.value = '不支持的平台';
      return;
    }

    final gen = ++tile.generation;
    tile.loading.value = true;
    tile.offline.value = false;
    tile.errorMsg.value = '';
    try {
      await tile.ensurePlayer();
      if (_closed || gen != tile.generation) return;

      final roomDetail = await site.liveSite.getRoomDetail(roomId: ref.roomId);
      if (_closed || gen != tile.generation) return;
      tile.detail.value = roomDetail;
      if (!roomDetail.status && !roomDetail.isRecord) {
        tile.offline.value = true;
        await tile.player?.stop();
        return;
      }

      final qualities = await site.liveSite.getPlayQualites(detail: roomDetail);
      if (_closed || gen != tile.generation) return;
      tile.qualities.assignAll(qualities);
      if (qualities.isEmpty) {
        tile.errorMsg.value = '暂无可用清晰度';
        return;
      }

      // Default to medium quality in multi-view to balance clarity and decode load.
      final selectedIndex = _pickDefaultQualityIndex(qualities);
      tile.currentQualityIndex.value = selectedIndex;

      final playUrl = await site.liveSite.getPlayUrls(
        detail: roomDetail,
        quality: qualities[selectedIndex],
      );
      if (_closed || gen != tile.generation) return;
      if (playUrl.urls.isEmpty) {
        tile.errorMsg.value = '暂无可用播放线路';
        return;
      }

      tile.currentQualityName.value = Utils.playbackQualityLabel(
        qualities[selectedIndex].quality,
        playUrl.actualQuality,
      );
      await _openStream(tile, playUrl.urls.first, playUrl.headers, gen);
    } catch (e) {
      if (_closed || gen != tile.generation) return;
      tile.errorMsg.value = '加载失败，请点击刷新重试';
      Log.d('多画面加载房间失败(${ref.roomKey})：$e');
    } finally {
      if (!_closed && gen == tile.generation) {
        tile.loading.value = false;
      }
    }
  }

  Future<void> _openStream(
    MultiViewTileRuntime tile,
    String rawUrl,
    Map<String, String>? headers,
    int gen,
  ) async {
    final player = tile.player;
    if (player == null || _closed || gen != tile.generation) return;
    var url = rawUrl;
    if (AppSettingsController.instance.playerForceHttps.value) {
      url = url.replaceAll('http://', 'https://');
    }
    await player.open(Media(url, httpHeaders: headers));
    if (_closed || gen != tile.generation) return;
    await _syncAudioVolumes();
  }

  int _pickDefaultQualityIndex(List<LivePlayQuality> qualities) {
    if (qualities.length <= 1) return 0;
    final pref = AppSettingsController.instance.qualityLevel.value;
    if (pref == 0) return qualities.length - 1;
    if (pref == 2) return 0;
    return qualities.length ~/ 2;
  }

  Future<void> _syncAudioVolumes() async {
    final master = AppSettingsController.instance.playerVolume.value;
    for (var i = 0; i < tiles.length; i++) {
      final p = tiles[i].player;
      if (p == null) continue;
      final target = layoutState.volumeForSlot(i, masterVolume: master);
      try {
        await p.setVolume(target);
      } catch (e) {
        Log.d('设置多画面音量失败：$e');
      }
    }
  }

  @override
  void onClose() {
    _closed = true;
    _volumeHintTimer?.cancel();
    if (Platform.isWindows && fullScreen.value) {
      unawaited(windowManager.setFullScreen(false));
    }
    for (final tile in tiles) {
      unawaited(tile.clearAndDispose());
    }
    super.onClose();
  }
}
