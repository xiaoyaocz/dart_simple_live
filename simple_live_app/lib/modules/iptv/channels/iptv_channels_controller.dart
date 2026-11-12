import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/models/db/iptv_playlist.dart';
import 'package:simple_live_app/modules/iptv/parser/iptv_channel.dart';
import 'package:simple_live_app/modules/iptv/parser/m3u_parser.dart';
import 'package:simple_live_app/services/iptv_service.dart';

class IptvChannelsController extends BaseController {
  final playlists = <IptvPlaylist>[].obs;
  final currentPlaylist = Rxn<IptvPlaylist>();
  final parseResult = Rxn<M3uParseResult>();

  final groups = <String>[].obs;
  final currentGroup = "".obs;
  final channels = <IptvChannel>[].obs;
  final favorites = <IptvFavorite>[].obs;

  final showFavorites = false.obs;
  final searching = false.obs;
  final keyword = "".obs;

  @override
  void onInit() {
    loadPlaylists();
    super.onInit();
  }

  /// 从本地读取订阅源，首次进入自动加载第一个源
  void loadPlaylists() {
    playlists.value = IptvService.instance.getPlaylists();
    refreshFavorites();
    if (currentPlaylist.value == null && playlists.isNotEmpty) {
      selectPlaylist(playlists.first);
    }
  }

  /// 选择订阅源并加载其频道
  Future<void> selectPlaylist(IptvPlaylist playlist) async {
    currentPlaylist.value = playlist;
    showFavorites.value = false;
    pageLoadding.value = true;
    try {
      final result = await IptvService.instance.getOrLoad(playlist);
      parseResult.value = result;
      groups.value = IptvService.instance.getGroups(result);
      currentGroup.value = "";
      keyword.value = "";
      applyFilter();
    } catch (e) {
      handleError(e, showPageError: true);
    } finally {
      pageLoadding.value = false;
    }
  }

  void selectGroup(String group) {
    currentGroup.value = group;
    applyFilter();
  }

  void setKeyword(String value) {
    keyword.value = value;
    applyFilter();
  }

  void toggleFavoritesMode() {
    showFavorites.value = !showFavorites.value;
    refreshFavorites();
  }

  /// 按当前分组与关键词过滤频道
  void applyFilter() {
    final result = parseResult.value;
    if (result == null) {
      channels.clear();
      return;
    }
    var list = IptvService.instance.channelsOfGroup(result, currentGroup.value);
    if (keyword.value.isNotEmpty) {
      final kw = keyword.value.toLowerCase();
      list = list
          .where((channel) => channel.name.toLowerCase().contains(kw))
          .toList();
    }
    channels.value = list;
  }

  void refreshFavorites() {
    favorites.value = IptvService.instance.getFavorites();
  }

  bool isFavoriteChannel(IptvChannel channel) {
    final playlist = currentPlaylist.value;
    return playlist != null &&
        IptvService.instance.isFavorite(
          IptvService.favoriteId(playlist.id, channel.url),
        );
  }

  void toggleFavorite(IptvChannel channel) {
    final playlist = currentPlaylist.value;
    if (playlist == null) return;
    IptvService.instance.toggleFavorite(
      playlistId: playlist.id,
      channel: channel,
    );
    refreshFavorites();
  }

  /// 进入播放页，携带当前频道列表与起始位置以便切台
  void openPlayer(IptvChannel channel, int index) {
    final playlist = currentPlaylist.value;
    if (playlist == null) return;
    Get.toNamed(
      RoutePath.kIptvPlayer,
      arguments: {
        "playlist": playlist,
        "channels": channels,
        "index": index,
        "epgUrls": parseResult.value?.epgUrls ?? const <String>[],
      },
    );
  }

  /// 收藏频道进入播放页
  void openFavoritePlayer(IptvFavorite favorite, int index) {
    Get.toNamed(
      RoutePath.kIptvPlayer,
      arguments: {
        "playlist": null,
        "favorites": favorites,
        "index": index,
        "epgUrls": const <String>[],
      },
    );
  }

  /// 管理订阅源后返回，重新加载
  Future<void> goManage() async {
    await Get.toNamed(RoutePath.kIptvPlaylists);
    loadPlaylists();
  }
}
