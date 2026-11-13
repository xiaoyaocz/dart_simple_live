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

/// 公开直播源元数据，保留作者完整信息
class IptvSourceMeta {
  final String name;
  final String author;
  final String projectUrl;
  final String description;
  final List<String> urls;

  const IptvSourceMeta({
    required this.name,
    required this.author,
    this.projectUrl = "",
    required this.description,
    required this.urls,
  });
}

class IptvService extends GetxService {
  static IptvService get instance => Get.find<IptvService>();

  static const String playlistBoxName = "IptvPlaylist";
  static const String favoriteBoxName = "IptvFavorite";
  static const String defaultPlaylistName = "全国IPTV直播源";

  /// 预置公开源池，不可删除
  static const List<IptvSourceMeta> presetSourcePool = [
    IptvSourceMeta(
      name: "vbskycn全量源",
      author: "vbskycn",
      description: "400+频道，省份分组完整",
      urls: [
        "https://peterhchina.github.io/iptv/IPTV-V4.m3u",
        "https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
        "https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "范明明直连源",
      author: "fanmingming",
      description: "国内直连，延迟低",
      urls: [
        "https://live.fanmingming.com/tv/m3u/ipv4.m3u",
        "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv4.m3u",
        "https://gh-proxy.com/raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv4.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "YanG聚合源",
      author: "YanG-1989",
      description: "多源聚合，频道丰富",
      urls: [
        "https://raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u",
        "https://gh-proxy.com/raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "HerbertHe CDN源",
      author: "HerbertHe",
      description: "CDN加速，稳定性高",
      urls: [
        "https://m3u.ibert.me/ipv4.m3u",
        "https://raw.githubusercontent.com/HerbertHe/iptv-sources/main/ipv4.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "peterh镜像源",
      author: "peterhchina",
      description: "vbskycn镜像，备用源",
      urls: [
        "https://peterhchina.github.io/iptv/IPTV-V4.m3u",
      ],
    ),
  ];

  late Box<IptvPlaylist> playlistBox;
  late Box<IptvFavorite> favoriteBox;

  final Uuid _uuid = const Uuid();

  /// 订阅源解析结果的内存缓存，避免重复拉取
  final Map<String, M3uParseResult> _cache = <String, M3uParseResult>{};

  /// 加载状态可观察变量，供页面显示进度
  final RxBool isLoading = false.obs;
  final RxInt currentSourceIndex = 0.obs;
  final RxInt totalSourceCount = 0.obs;
  final RxString loadingMessage = "正在加载直播源...".obs;

  // ==================== 预置源启用状态管理 ====================
  /// 用户启用的源名称列表，默认全部启用，持久化存储
  final RxList<String> enabledSourceNames = <String>[].obs;
  /// 用户自定义源列表，持久化存储
  final RxList<IptvSourceMeta> customSources = <IptvSourceMeta>[].obs;

  /// 所有可用源：预置源 + 自定义源，自定义源排在最后
  List<IptvSourceMeta> get sourcePool => [
    ...presetSourcePool,
    ...customSources,
  ];

  Future<void> init() async {
    playlistBox = await Hive.openBox<IptvPlaylist>(playlistBoxName);
    favoriteBox = await Hive.openBox<IptvFavorite>(favoriteBoxName);
    // 加载源启用状态，默认全部启用
    final savedEnabled = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvSourceEnabled,
      presetSourcePool.map((e) => e.name).toList(),
    );
    enabledSourceNames.assignAll(savedEnabled.cast<String>());
    // 加载保存的自定义源
    final savedCustom = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvCustomSources,
      [],
    );
    customSources.assignAll(savedCustom.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return IptvSourceMeta(
        name: map["name"],
        author: "自定义",
        description: "用户自定义源",
        urls: List<String>.from(map["urls"]),
      );
    }));
  }

  /// 添加自定义源，支持用户自定义名称
  Future<void> addCustomSource({required String name, required String url}) async {
    final meta = IptvSourceMeta(
      name: name,
      author: "自定义",
      description: "用户自定义源",
      urls: [url],
    );
    customSources.add(meta);
    enabledSourceNames.add(name);
    await _saveCustomSources();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  /// 删除自定义源，预置源不可删除
  Future<void> deleteCustomSource(IptvSourceMeta source) async {
    customSources.remove(source);
    enabledSourceNames.remove(source.name);
    await _saveCustomSources();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  /// 持久化自定义源列表
  Future<void> _saveCustomSources() async {
    final data = customSources.map((e) => {
      "name": e.name,
      "urls": e.urls,
    }).toList();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvCustomSources,
      data,
    );
  }

  /// 切换源启用/禁用状态，自动持久化
  Future<void> toggleSourceEnabled(IptvSourceMeta source) async {
    if (enabledSourceNames.contains(source.name)) {
      // 至少保留一个启用源，避免全部禁用无法加载
      if (enabledSourceNames.length == 1) return;
      enabledSourceNames.remove(source.name);
    } else {
      enabledSourceNames.add(source.name);
    }
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  /// 获取用户当前启用的源，按源池顺序排序
  List<IptvSourceMeta> get enabledSources => sourcePool
      .where((e) => enabledSourceNames.contains(e.name))
      .toList();

  /// 首次启动随机选择全量源，自动分摊服务器流量
  /// 首次启动自动注册默认直播源，使用第一个启用的源
  Future<void> ensureDefaultPlaylist() async {
    final storage = LocalStorageService.instance;
    if (storage.getValue(LocalStorageService.kIptvDefaultInited, false)) {
      return;
    }
    try {
      final selected = enabledSources.first;
      await addPlaylist(
        name: defaultPlaylistName,
        url: selected.urls.first,
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

  /// 拉取并解析订阅源，依次尝试所有源与镜像，全失败才抛出错误
  /// 完整保留作者原始频道、公告、赞助提示，不做任何过滤
  // ==================== 多源刷新与容灾 ====================
  /// 遍历所有启用的源与镜像地址，5秒超时自动切换，全部失败才抛出错误
  Future<M3uParseResult> refresh(IptvPlaylist playlist) async {
    isLoading.value = true;
    Object? lastError;
    final activeSources = enabledSources;
    // 统计总地址数用于进度显示
    var totalUrls = activeSources.fold<int>(0, (p, e) => p + e.urls.length);
    totalSourceCount.value = totalUrls;
    var urlIndex = 0;

    for (var sourceIndex = 0; sourceIndex < activeSources.length; sourceIndex++) {
      final source = activeSources[sourceIndex];
      for (var mirrorIndex = 0; mirrorIndex < source.urls.length; mirrorIndex++) {
        urlIndex++;
        currentSourceIndex.value = urlIndex;
        final url = source.urls[mirrorIndex];
        loadingMessage.value = "正在尝试源 $urlIndex/$totalUrls...";
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
          Log.w("直播源地址 $url 访问失败，尝试下一个地址");
        }
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
