import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';
import 'package:simple_live_tv_app/models/db/iptv_playlist.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/iptv_channel.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/m3u_parser.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';

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
    playlists.value = IptvService.instance.getPlaylists();
    refreshFavorites();
    // 优先打开订阅源页传入的源，否则取第一个
    final arg = Get.arguments;
    if (arg is IptvPlaylist) {
      selectPlaylist(arg);
    } else if (playlists.isNotEmpty) {
      selectPlaylist(playlists.first);
    }
    super.onInit();
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

  void toggleSearch() {
    searching.value = !searching.value;
    if (!searching.value) setKeyword("");
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
    var list =
        IptvService.instance.channelsOfGroup(result, currentGroup.value);
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

  /// 跳转订阅源管理，返回后处理当前源被删除的情况
  Future<void> goManage() async {
    await Get.toNamed(RoutePath.kIptvPlaylist);
    playlists.value = IptvService.instance.getPlaylists();
    refreshFavorites();
    final current = currentPlaylist.value;
    if (current != null &&
        !playlists.any((item) => item.id == current.id)) {
      if (playlists.isNotEmpty) {
        selectPlaylist(playlists.first);
      } else {
        currentPlaylist.value = null;
        parseResult.value = null;
        channels.clear();
      }
    }
  }
}
