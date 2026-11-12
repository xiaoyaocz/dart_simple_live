import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
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
  static const String defaultPlaylistName = "默认精选频道";

  late Box<IptvPlaylist> playlistBox;
  late Box<IptvFavorite> favoriteBox;

  final Uuid _uuid = const Uuid();

  /// 订阅源解析结果的内存缓存，避免重复拉取
  final Map<String, M3uParseResult> _cache = <String, M3uParseResult>{};

  Future<void> init() async {
    playlistBox = await Hive.openBox<IptvPlaylist>(playlistBoxName);
    favoriteBox = await Hive.openBox<IptvFavorite>(favoriteBoxName);
  }

  /// 首次启动把内置精选源复制到文档目录并注册，成功后才标记；
  /// 已初始化时若内置清单版本更新且默认源未被删除，静默同步本地副本；用户删除后不再重建
  Future<void> ensureDefaultPlaylist() async {
    final storage = LocalStorageService.instance;
    final String content;
    try {
      content = await rootBundle.loadString("assets/iptv/default.m3u");
    } catch (e) {
      Log.w("内置 IPTV 源读取失败: $e");
      return;
    }
    final hash = sha256.convert(utf8.encode(content)).toString();

    if (!storage.getValue(LocalStorageService.kIptvDefaultInited, false)) {
      try {
        final target = await _defaultFile();
        await target.writeAsString(content);
        await addPlaylist(
          name: defaultPlaylistName,
          url: target.path,
          type: IptvPlaylist.typeLocal,
        );
        await storage.setValue(LocalStorageService.kIptvDefaultInited, true);
        await storage.setValue(LocalStorageService.kIptvDefaultVersion, hash);
      } catch (e) {
        Log.w("内置 IPTV 源初始化失败: $e");
      }
      return;
    }

    // 已初始化：内置清单有更新且默认源仍存在时同步本地副本
    if (storage.getValue(LocalStorageService.kIptvDefaultVersion, "") == hash) {
      return;
    }
    await storage.setValue(LocalStorageService.kIptvDefaultVersion, hash);
    try {
      final target = await _defaultFile();
      final playlist = playlistBox.values
          .firstWhereOrNull((item) => item.url == target.path);
      if (playlist == null) {
        // 用户已删除默认源，尊重其选择
        return;
      }
      await target.writeAsString(content);
      _cache.remove(playlist.id);
      playlist.updateTime = DateTime.now();
      await playlistBox.put(playlist.id, playlist);
      Log.d("内置 IPTV 源已同步到新版本");
    } catch (e) {
      Log.w("内置 IPTV 源同步失败: $e");
    }
  }

  Future<File> _defaultFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File(
      "${docDir.path}${Platform.pathSeparator}iptv_default.m3u",
    );
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
