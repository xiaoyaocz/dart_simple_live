import 'dart:io';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/db/iptv_favorite.dart';
import '../models/db/iptv_playlist.dart';
import '../modules/iptv/parser/iptv_channel.dart';
import '../modules/iptv/parser/m3u_parser.dart';
import '../requests/http_client.dart';

class IptvService extends GetxService {
  static IptvService get instance => Get.find<IptvService>();

  static const String playlistBoxName = "IptvPlaylist";
  static const String favoriteBoxName = "IptvFavorite";

  late Box<IptvPlaylist> playlistBox;
  late Box<IptvFavorite> favoriteBox;

  final Uuid _uuid = const Uuid();

  /// 订阅源解析结果的内存缓存，避免重复拉取
  final Map<String, M3uParseResult> _cache = <String, M3uParseResult>{};

  Future<void> init() async {
    playlistBox = await Hive.openBox<IptvPlaylist>(playlistBoxName);
    favoriteBox = await Hive.openBox<IptvFavorite>(favoriteBoxName);
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

  /// 拉取并解析订阅源，成功后更新缓存与刷新时间
  Future<M3uParseResult> refresh(IptvPlaylist playlist) async {
    final content = playlist.isLocal
        ? await File(playlist.url).readAsString()
        : await HttpClient.instance.getText(playlist.url);
    final result = M3uParser.parse(
      content,
      baseUrl: playlist.isLocal ? null : playlist.url,
    );
    _cache[playlist.id] = result;
    playlist.updateTime = DateTime.now();
    await playlistBox.put(playlist.id, playlist);
    return result;
  }

  /// 优先用缓存，未缓存时拉取
  Future<M3uParseResult> getOrLoad(IptvPlaylist playlist) async {
    final cached = _cache[playlist.id];
    return cached ?? await refresh(playlist);
  }

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
