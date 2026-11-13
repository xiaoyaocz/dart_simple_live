import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../app/log.dart';
import '../models/db/iptv_favorite.dart';
import '../models/db/iptv_playlist.dart';
import '../modules/iptv/parser/iptv_channel.dart';
import '../modules/iptv/parser/m3u_parser.dart';
import '../requests/http_client.dart';
import 'local_storage_service.dart';

class IptvService extends GetxService {
  static IptvService get instance => Get.find<IptvService>();

  static const String playlistBoxName = "IptvPlaylist";
  static const String favoriteBoxName = "IptvFavorite";
  static const String defaultPlaylistName = "全国IPTV直播源";

  /// 按优先级排序的备用源地址，前一个失败自动切换下一个
  static const List<String> sourceUrls = [
    "https://live.zbds.top/tv/iptv4.m3u",
    "https://peterhchina.github.io/iptv/IPTV-V4.m3u",
    "https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
    "https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
  ];

  late Box<IptvPlaylist> playlistBox;
  late Box<IptvFavorite> favoriteBox;

  final Uuid _uuid = const Uuid();

  /// 订阅源解析结果的内存缓存，避免重复拉取
  final Map<String, M3uParseResult> _cache = <String, M3uParseResult>{};

  /// 加载状态可观察变量，供页面显示进度
  final RxBool isLoading = false.obs;
  final RxInt currentSourceIndex = 0.obs;
  final RxInt totalSourceCount = sourceUrls.length.obs;
  final RxString loadingMessage = "正在加载直播源...".obs;

  Future<void> init() async {
    playlistBox = await Hive.openBox<IptvPlaylist>(playlistBoxName);
    favoriteBox = await Hive.openBox<IptvFavorite>(favoriteBoxName);
  }

  /// 首次启动自动注册全国直播源，用户删除后不再自动重建
  Future<void> ensureDefaultPlaylist() async {
    final storage = LocalStorageService.instance;
    if (storage.getValue(LocalStorageService.kIptvDefaultInited, false)) {
      return;
    }
    try {
      await addPlaylist(
        name: defaultPlaylistName,
        url: sourceUrls.first,
        type: IptvPlaylist.typeRemote,
      );
      await storage.setValue(LocalStorageService.kIptvDefaultInited, true);
    } catch (e) {
      Log.w("IPTV 源初始化失败: $e");
    }
  }

  // ============ 订阅源 ============

  List<IptvPlaylist> getPlaylists() {
    return playlistBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<IptvPlaylist> addPlaylist({
    required String name,
    required String url,
    required int type,
  }) async {
    final playlist = IptvPlaylist(
      id: _uuid.v4(),
      name: name,
      url: url,
      type: type,
      updateTime: DateTime.now(),
    );
    await playlistBox.put(playlist.id, playlist);
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    _cache.remove(id);
    await playlistBox.delete(id);
  }

  /// 拉取并解析订阅源，依次尝试所有备用地址，全失败才抛出最后一个错误
  Future<M3uParseResult> refresh(IptvPlaylist playlist) async {
    isLoading.value = true;
    Object? lastError;
    for (var i = 0; i < sourceUrls.length; i++) {
      currentSourceIndex.value = i;
      final url = sourceUrls[i];
      loadingMessage.value = "正在尝试直播源 ${i + 1}/${sourceUrls.length}...";
      try {
        final content = await HttpClient.instance.getText(
          url,
          header: {},
        ).timeout(const Duration(seconds: 5));
        final result = M3uParser.parse(content, baseUrl: url);
        _cache[playlist.id] = result;
        playlist.updateTime = DateTime.now();
        playlist.url = url;
        await playlistBox.put(playlist.id, playlist);
        isLoading.value = false;
        return result;
      } catch (e) {
        lastError = e;
        Log.w("直播源地址 $url 访问失败，尝试下一个备用地址");
      }
    }
    isLoading.value = false;
    throw lastError ?? Exception("所有直播源地址均无法访问");
  }

  /// 优先用缓存，未缓存时拉取
  Future<M3uParseResult> getOrLoad(IptvPlaylist playlist) async {
    final cached = _cache[playlist.id];
    return cached ?? await refresh(playlist);
  }

  /// 仅查询内存缓存，不发起网络请求
  M3uParseResult? cachedParse(String playlistId) => _cache[playlistId];

  // ============ 频道与分组 ============

  List<String> getGroups(M3uParseResult result) {
    return result.channels.map((channel) => channel.group).toSet().toList();
  }

  List<IptvChannel> channelsOfGroup(M3uParseResult result, String group) {
    return result.channels
        .where((channel) => group.isEmpty || channel.group == group)
        .toList();
  }

  // ============ 收藏 ============

  List<IptvFavorite> getFavorites() => favoriteBox.values.toList();

  bool isFavorite(String id) => favoriteBox.containsKey(id);

  static String favoriteId(String playlistId, String url) =>
      "${playlistId}_$url";

  Future<void> toggleFavorite({
    required String playlistId,
    required IptvChannel channel,
  }) async {
    final id = favoriteId(playlistId, channel.url);
    if (favoriteBox.containsKey(id)) {
      await favoriteBox.delete(id);
      return;
    }
    await favoriteBox.put(
      id,
      IptvFavorite(
        id: id,
        playlistId: playlistId,
        channelId: channel.id,
        name: channel.name,
        logo: channel.logo,
        group: channel.group,
        url: channel.url,
      ),
    );
  }
}
