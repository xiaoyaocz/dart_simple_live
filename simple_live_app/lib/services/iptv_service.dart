import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../app/log.dart';
import '../models/db/iptv_favorite.dart';
import '../models/db/iptv_playlist.dart';
import '../modules/iptv/parser/aggregated_channel.dart';
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

  late Box<IptvPlaylist> playlistBox;
  late Box<IptvFavorite> favoriteBox;

  final Uuid _uuid = const Uuid();

  /// 订阅源解析结果的内存缓存，避免重复拉取
  final Map<String, M3uParseResult> _cache = <String, M3uParseResult>{};
  /// 跨源聚合结果缓存
  AggregatedParseResult? aggregatedCache;
  /// 聚合缓存生成时间，控制自动过期，同步源更新
  DateTime? _aggregatedCacheTime;
  /// 缓存自动过期时间：4小时，匹配公开源6小时/每日更新频率
  static const Duration _cacheMaxAge = Duration(hours: 4);

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
  /// 用户已删除的预置源名称列表，持久化存储
  final RxList<String> deletedPresetNames = <String>[].obs;

  /// 当前实际展示的预置源，过滤已删除的默认源
  List<IptvSourceMeta> get currentPresetSourcePool => defaultPresetSourcePool
      .where((e) => !deletedPresetNames.contains(e.name))
      .toList();

  /// 所有可用源：当前未删除的预置源 + 自定义源，自定义源排在最后
  List<IptvSourceMeta> get sourcePool => [
    ...currentPresetSourcePool,
    ...customSources,
  ];

  /// 默认预置公开源池，不可直接修改，用户删除后可通过恢复默认还原，按优先级排序
  static const List<IptvSourceMeta> defaultPresetSourcePool = [
    IptvSourceMeta(
      name: "DataShare海外源",
      author: "DataShare-duo",
      projectUrl: "https://github.com/DataShare-duo/IPTV-Source",
      description: "海外节点直连，CDN加速，央视频道完整，适配境外网络",
      urls: [
        "https://raw.githubusercontent.com/DataShare-duo/IPTV-Source/refs/heads/main/movie_live.txt",
      ],
    ),
    IptvSourceMeta(
      name: "suxuang全量源",
      author: "suxuang",
      projectUrl: "https://github.com/suxuang/myIPTV",
      description: "频道数量全，多节点容灾，每日自动更新，央视频道完整",
      urls: [
        "https://raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u",
        "https://gh-proxy.com/raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "vbskycn全量源",
      author: "vbskycn",
      projectUrl: "https://github.com/vbskycn/iptv",
      description: "400+频道，省份分组完整，6小时自动更新",
      urls: [
        "https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
        "https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
        "https://peterhchina.github.io/iptv/IPTV-V4.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "peterh镜像源",
      author: "peterhchina",
      projectUrl: "https://peterhchina.github.io/iptv/",
      description: "vbskycn镜像，备用源，每日自动更新",
      urls: [
        "https://peterhchina.github.io/iptv/IPTV-V4.m3u",
      ],
    ),
  ];

  Future<void> init() async {
    playlistBox = await Hive.openBox<IptvPlaylist>(playlistBoxName);
    favoriteBox = await Hive.openBox<IptvFavorite>(favoriteBoxName);
    // 加载用户删除的预置源
    final savedDeleted = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvDeletedSources,
      [],
    );
    deletedPresetNames.assignAll(savedDeleted.cast<String>());
    // 加载源启用状态，默认全部当前预置源启用
    final defaultEnabled = currentPresetSourcePool.map((e) => e.name).toList();
    final savedEnabled = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvSourceEnabled,
      defaultEnabled,
    );
    enabledSourceNames.assignAll(savedEnabled.cast<String>().where((name) =>
      currentPresetSourcePool.any((e) => e.name == name) || customSources.any((e) => e.name == name)
    ).toList());
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

  /// 修改自定义源的名称与地址
  Future<void> updateCustomSource(IptvSourceMeta oldSource, {required String name, required String url}) async {
    final index = customSources.indexOf(oldSource);
    if (index < 0) return;
    final updated = IptvSourceMeta(
      name: name,
      author: "自定义",
      description: "用户自定义源",
      urls: [url],
    );
    customSources[index] = updated;
    // 同步更新启用状态中的名称
    final enabledIndex = enabledSourceNames.indexOf(oldSource.name);
    if (enabledIndex >= 0) {
      enabledSourceNames[enabledIndex] = name;
    }
    await _saveCustomSources();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  /// 删除任意源，预置源加入删除列表，自定义源直接移除
  Future<void> deleteSource(IptvSourceMeta source) async {
    if (source.author == "自定义") {
      customSources.remove(source);
      await _saveCustomSources();
    } else {
      deletedPresetNames.add(source.name);
      await LocalStorageService.instance.setValue(
        LocalStorageService.kIptvDeletedSources,
        deletedPresetNames.toList(),
      );
    }
    enabledSourceNames.remove(source.name);
    // 若删除后没有启用源，自动启用第一个剩余源
    if (enabledSourceNames.isEmpty && sourcePool.isNotEmpty) {
      enabledSourceNames.add(sourcePool.first.name);
    }
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  /// 恢复默认预置源，清空自定义源与删除状态，重置启用状态为全部默认源启用
  Future<void> restoreDefaultSources() async {
    deletedPresetNames.clear();
    customSources.clear();
    enabledSourceNames.assignAll(defaultPresetSourcePool.map((e) => e.name));
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvDeletedSources,
      [],
    );
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

  // ==================== 收藏功能 ====================
  List<IptvFavorite> getFavorites() => favoriteBox.values.toList();
  bool isFavorite(String id) => favoriteBox.containsKey(id);
  static String favoriteId(String playlistId, String url) => "${playlistId}_$url";

  /// 聚合频道收藏/取消
  Future<void> toggleFavorite({
    required String playlistId,
    required AggregatedChannel channel,
    required IptvLine line,
  }) async {
    final id = favoriteId(playlistId, line.url);
    if (favoriteBox.containsKey(id)) {
      await favoriteBox.delete(id);
      return;
    }
    await favoriteBox.put(
      id,
      IptvFavorite(
        id: id,
        playlistId: playlistId,
        channelId: line.channelId,
        name: channel.name,
        logo: line.logo,
        group: channel.group,
        url: line.url,
        sourceName: line.sourceName,
      ),
    );
  }

  // ==================== 跨源聚合逻辑 ====================

  /// 标准化频道名称，用于跨源同名匹配：去除空格、横杠、转小写
  String _normalizeName(String name) {
    return name.replaceAll(RegExp(r'[\s\-_]+'), "").toLowerCase();
  }

  /// 拉取所有启用源并聚合频道，单源失败自动跳过，带进度提示
  Future<AggregatedParseResult> refreshAggregated() async {
    isLoading.value = true;
    final activeSources = enabledSources;
    totalSourceCount.value = activeSources.length;
    final allSourceResults = <M3uParseResult>[];
    final allEpg = <String>{};

    for (var i = 0; i < activeSources.length; i++) {
      currentSourceIndex.value = i + 1;
      final source = activeSources[i];
      loadingMessage.value = "正在拉取 ${source.name}（${i+1}/${activeSources.length}）...";
      // 每个源尝试所有镜像，成功即停止
      M3uParseResult? sourceResult;
      for (final url in source.urls) {
        try {
          final content = await HttpClient.instance.getText(
            url,
            header: {},
          ).timeout(const Duration(seconds: 5));
          sourceResult = M3uParser.parse(content, baseUrl: url);
          break;
        } catch (e) {
          Log.w("源 ${source.name} 地址 $url 拉取失败，尝试下一个镜像");
        }
      }
      if (sourceResult != null) {
        allSourceResults.add(sourceResult);
        allEpg.addAll(sourceResult.epgUrls);
      }
    }

    if (allSourceResults.isEmpty) {
      isLoading.value = false;
      throw Exception("所有启用源均无法访问");
    }

    // 按标准化名称聚合频道
    final channelMap = <String, List<IptvLine>>{};
    final channelBaseInfo = <String, ({String name, String group, String logo})>{};

    for (var sourceIndex = 0; sourceIndex < allSourceResults.length; sourceIndex++) {
      final result = allSourceResults[sourceIndex];
      final sourceName = activeSources[sourceIndex].name;
      for (final ch in result.channels) {
        final key = _normalizeName(ch.name);
        final line = IptvLine(
          sourceName: sourceName,
          url: ch.url,
          logo: ch.logo,
          channelId: ch.id,
        );
        if (!channelMap.containsKey(key)) {
          channelMap[key] = <IptvLine>[];
          channelBaseInfo[key] = (name: ch.name, group: ch.group, logo: ch.logo);
        }
        channelMap[key]!.add(line);
      }
    }

    // 构建聚合频道列表
    var channels = channelMap.entries.map((entry) {
      final base = channelBaseInfo[entry.key]!;
      return AggregatedChannel(
        name: base.name,
        group: base.group,
        logo: base.logo,
        lines: entry.value,
      );
    }).toList();

    // 排序：央视、卫视置顶，央视按数字自然排序，其余按名称
    channels = _sortAggregatedChannels(channels);

    final result = AggregatedParseResult(
      channels: channels,
      epgUrls: allEpg.toList(),
    );
    aggregatedCache = result;
    _aggregatedCacheTime = DateTime.now();
    isLoading.value = false;
    return result;
  }

  /// 聚合频道排序：央视、卫视置顶，央视数字自然排序
  List<AggregatedChannel> _sortAggregatedChannels(List<AggregatedChannel> list) {
    list.sort((a, b) {
      final aGroup = a.group == "央视频道" ? 0 : (a.group == "卫视频道" ? 1 : 2);
      final bGroup = b.group == "央视频道" ? 0 : (b.group == "卫视频道" ? 1 : 2);
      if (aGroup != bGroup) return aGroup.compareTo(bGroup);
      if (aGroup == 0) {
        final aNum = _extractCctvNumber(a.name);
        final bNum = _extractCctvNumber(b.name);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  /// 提取CCTV数字
  int? _extractCctvNumber(String name) {
    final match = RegExp(r'CCTV-?(\d+)').firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// 获取聚合结果，优先未过期缓存，支持手动强制刷新
  Future<AggregatedParseResult> getAggregated({bool forceRefresh = false}) async {
    final cacheValid = aggregatedCache != null &&
        _aggregatedCacheTime != null &&
        DateTime.now().difference(_aggregatedCacheTime!) < _cacheMaxAge;
    if (!forceRefresh && cacheValid) return aggregatedCache!;
    return await refreshAggregated();
  }

  /// 获取聚合分组列表
  List<String> getAggregatedGroups(AggregatedParseResult result) {
    final groups = result.channels.map((e) => e.group).toSet().toList();
    // 央视/卫视置顶，其余按名称；比较器必须自洽（同组互比返回 0）
    int rank(String g) => g == "央视频道" ? 0 : (g == "卫视频道" ? 1 : 2);
    groups.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.compareTo(b);
    });
    return groups;
  }
}
