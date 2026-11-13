import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/iptv_playlist.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';

class IptvPlaylistController extends BaseController {
  final playlists = <IptvPlaylist>[].obs;

  /// 正在刷新的订阅源 id
  final refreshingIds = <String>{}.obs;

  @override
  void onInit() {
    loadPlaylists();
    super.onInit();
  }

  void loadPlaylists() {
    playlists.value = IptvService.instance.getPlaylists();
  }

  /// 拉取并解析订阅源，自动切换备用地址
  Future<void> refreshPlaylist(IptvPlaylist playlist) async {
    if (refreshingIds.contains(playlist.id)) return;
    refreshingIds.add(playlist.id);
    try {
      final result = await IptvService.instance.refresh(playlist);
      SmartDialog.showToast("已更新，共 ${result.channels.length} 个频道");
    } catch (e) {
      handleError(e);
    } finally {
      refreshingIds.remove(playlist.id);
      loadPlaylists();
    }
  }

  Future<void> delete(IptvPlaylist playlist) async {
    final confirmed = await Utils.showAlertDialog(
      "确定删除该直播源？删除后可通过重置应用恢复，收藏频道不会被删除。",
      title: "删除直播源",
      confirm: "删除",
    );
    if (!confirmed) return;
    await IptvService.instance.deletePlaylist(playlist.id);
    loadPlaylists();
  }
}
