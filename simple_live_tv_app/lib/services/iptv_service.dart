import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../app/log.dart';
import '../models/db/iptv_favorite.dart';
import '../models/db/iptv_tag.dart';
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

/// 源拉取健康统计：驱动镜像寻优与「优秀/可用」分级，不做差评——
/// 持续拉不到的源由用户直接删除，而不是打标签
class IptvSourceHealth {
  int successCount;
  int failCount;
  int consecutiveFailures;
  int lastLatencyMs;
  DateTime? lastSuccessTime;
  String lastSuccessUrl;
  Map<String, int> mirrorFailures;

  IptvSourceHealth({
    this.successCount = 0,
    this.failCount = 0,
    this.consecutiveFailures = 0,
    this.lastLatencyMs = 0,
    this.lastSuccessTime,
    this.lastSuccessUrl = "",
    Map<String, int>? mirrorFailures,
  }) : mirrorFailures = mirrorFailures ?? <String, int>{};

  factory IptvSourceHealth.fromJson(Map<dynamic, dynamic> json) {
    final mirrors = json["mirrorFailures"];
    return IptvSourceHealth(
      successCount: (json["successCount"] as num?)?.toInt() ?? 0,
      failCount: (json["failCount"] as num?)?.toInt() ?? 0,
      consecutiveFailures: (json["consecutiveFailures"] as num?)?.toInt() ?? 0,
      lastLatencyMs: (json["lastLatencyMs"] as num?)?.toInt() ?? 0,
      lastSuccessTime: json["lastSuccessTime"] == null
          ? null
          : DateTime.tryParse(json["lastSuccessTime"].toString()),
      lastSuccessUrl: json["lastSuccessUrl"]?.toString() ?? "",
      mirrorFailures: mirrors is Map
          ? mirrors.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : <String, int>{},
    );
  }

  Map<String, dynamic> toJson() => {
        "successCount": successCount,
        "failCount": failCount,
        "consecutiveFailures": consecutiveFailures,
        "lastLatencyMs": lastLatencyMs,
        "lastSuccessTime": lastSuccessTime?.toIso8601String(),
        "lastSuccessUrl": lastSuccessUrl,
        "mirrorFailures": mirrorFailures,
      };
}

class IptvService extends GetxService {
  static IptvService get instance => Get.find<IptvService>();

  static const String playlistBoxName = "IptvPlaylist";
  static const String favoriteBoxName = "IptvFavorite";
  static const String tagBoxName = "IptvTag";
  static const String defaultPlaylistName = "全国IPTV直播源";

  late Box<IptvPlaylist> playlistBox;
  late Box<IptvFavorite> favoriteBox;
  late Box<IptvTag> tagBox;

  final Uuid _uuid = const Uuid();

  /// 订阅源解析结果的内存缓存，避免重复拉取
  final Map<String, M3uParseResult> _cache = <String, M3uParseResult>{};
  /// 各源最近一次成功拉取的解析结果，「仅刷新部分源」时范围外源沿用此缓存
  final Map<String, M3uParseResult> _sourceResultCache = <String, M3uParseResult>{};
  /// 源拉取健康统计，驱动镜像寻优与分级，持久化
  final Map<String, IptvSourceHealth> _sourceHealth = <String, IptvSourceHealth>{};
  /// 跨源聚合结果缓存
  AggregatedParseResult? aggregatedCache;
  /// 聚合缓存生成时间，控制自动过期，同步源更新
  DateTime? _aggregatedCacheTime;
  /// 缓存按自然日失效：公开源均为日更，当天有效、次日进入频道页自动重拉
  static bool isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
  /// 全部为日更级公开源，地址均经直连实测可达；镜像链按「原始 → ghfast.top → gh-proxy」兜底，
  /// 致谢与来源详见 THANKS.md 与 IPTV_SOURCES.md
  static const List<IptvSourceMeta> defaultPresetSourcePool = [
    IptvSourceMeta(
      name: "suxuang全量源",
      author: "suxuang",
      projectUrl: "https://github.com/suxuang/myIPTV",
      description: "频道数量全，多节点容灾，每日自动更新，央视频道完整",
      urls: [
        "https://raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u",
        "https://ghfast.top/https://raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u",
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
        "https://ghfast.top/https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
        "https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u",
        "https://peterhchina.github.io/iptv/IPTV-V4.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "zhi35聚合源",
      author: "zhi35",
      projectUrl: "https://github.com/zhi35/iptv",
      description: "每日3更，央视/卫视/地方/港澳台/直播中国，IPv4+IPv6",
      urls: [
        "https://live.zhi35.com/iptv.m3u",
        "https://raw.githubusercontent.com/zhi35/iptv/master/iptv.m3u",
        "https://ghfast.top/https://raw.githubusercontent.com/zhi35/iptv/master/iptv.m3u",
        "https://gh-proxy.com/https://raw.githubusercontent.com/zhi35/iptv/master/iptv.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "fanmingming咪咕源",
      author: "fanmingming",
      projectUrl: "https://github.com/fanmingming/live",
      description: "最知名源，咪咕/央视频CDN，189频道央视体育齐全，每日多更",
      urls: [
        "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/itv.m3u",
        "https://gh-proxy.com/https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/itv.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "fanmingmingIPv6源",
      author: "fanmingming",
      projectUrl: "https://github.com/fanmingming/live",
      description: "经典IPv6列表，82频道央视卫视，需终端支持IPv6网络",
      urls: [
        "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u",
        "https://gh-proxy.com/https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "hujingguang实时源",
      author: "hujingguang",
      projectUrl: "https://github.com/hujingguang/ChinaIPTV",
      description: "每小时级更新，405频道央视+省市台，近实时抓取",
      urls: [
        "https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV1_ALL.m3u8",
        "https://ghfast.top/https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV1_ALL.m3u8",
      ],
    ),
    IptvSourceMeta(
      name: "hacks.tools日更源",
      author: "hacks.tools",
      projectUrl: "https://iptv.hacks.tools/",
      description: "每日多次更新，卫视/地方/电影/儿童丰富，央视频道较少",
      urls: [
        "https://live.hacks.tools/tv/iptv4.m3u",
        "https://live.hacks.tools/tv/iptv4.txt",
      ],
    ),
    IptvSourceMeta(
      name: "xisohi全量源",
      author: "xisohi",
      projectUrl: "https://github.com/xisohi/CHINA-IPTV",
      description: "TXT格式1200+条，央视/卫视/地方/教育/台港澳，按省单播库",
      urls: [
        "https://raw.githubusercontent.com/xisohi/CHINA-IPTV/main/TV/live.txt",
        "https://ghfast.top/https://raw.githubusercontent.com/xisohi/CHINA-IPTV/main/TV/live.txt",
      ],
    ),
    IptvSourceMeta(
      name: "iptv-org国际源",
      author: "iptv-org",
      projectUrl: "https://github.com/iptv-org/iptv",
      description: "全球11000+频道，国际频道为主，每日自动校验",
      urls: [
        "https://iptv-org.github.io/iptv/index.m3u",
        "https://live.hacks.tools/iptv/index.m3u",
      ],
    ),
    IptvSourceMeta(
      name: "DataShare海外源",
      author: "DataShare-duo",
      projectUrl: "https://github.com/DataShare-duo/IPTV-Source",
      description: "海外节点直连，CDN加速，央视频道完整，适配境外网络",
      urls: [
        "https://raw.githubusercontent.com/DataShare-duo/IPTV-Source/refs/heads/main/movie_live.txt",
        "https://ghfast.top/https://raw.githubusercontent.com/DataShare-duo/IPTV-Source/refs/heads/main/movie_live.txt",
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
    tagBox = await Hive.openBox<IptvTag>(tagBoxName);
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
    // 启动时从磁盘恢复上次聚合结果（可能已过期，用于秒开与拉取全败兜底）
    _loadPersistedAggregated();
    // 恢复源健康统计（镜像寻优与分级依据）
    _loadSourceHealth();
    // 恢复线路最近已知状态（排序与红绿灯暖启动）
    _loadKnownStatus();
  }

  // ==================== 源健康统计与分级 ====================

  /// 从磁盘恢复源健康统计
  void _loadSourceHealth() {
    try {
      final raw = LocalStorageService.instance.getValue<Map<dynamic, dynamic>>(
        LocalStorageService.kIptvSourceHealth,
        {},
      );
      _sourceHealth
        ..clear()
        ..addEntries(raw.entries.map((e) => MapEntry(
              e.key.toString(),
              IptvSourceHealth.fromJson(Map<dynamic, dynamic>.from(e.value as Map)),
            )));
    } catch (e) {
      Log.w("恢复源健康统计失败: $e");
    }
  }

  /// 持久化源健康统计
  Future<void> _persistSourceHealth() async {
    try {
      await LocalStorageService.instance.setValue(
        LocalStorageService.kIptvSourceHealth,
        _sourceHealth.map((k, v) => MapEntry(k, v.toJson())),
      );
    } catch (e) {
      Log.w("写入源健康统计失败: $e");
    }
  }

  IptvSourceHealth _healthOf(String name) =>
      _sourceHealth.putIfAbsent(name, () => IptvSourceHealth());

  /// 记录一次源拉取结果：镜像寻优与分级的原始数据
  Future<void> _recordSourceFetch(
    IptvSourceMeta source, {
    required bool success,
    String? url,
    int latencyMs = 0,
  }) async {
    final h = _healthOf(source.name);
    if (success) {
      h.successCount++;
      h.consecutiveFailures = 0;
      h.lastLatencyMs = latencyMs;
      h.lastSuccessTime = DateTime.now();
      h.lastSuccessUrl = url ?? "";
      if (url != null) h.mirrorFailures[url] = 0;
    } else {
      h.failCount++;
      h.consecutiveFailures++;
      if (url != null) {
        h.mirrorFailures[url] = (h.mirrorFailures[url] ?? 0) + 1;
      }
    }
    await _persistSourceHealth();
  }

  /// 源分级：国际源按性质标注，其余按健康统计分「优秀/可用」，不打差评
  String sourceCategory(IptvSourceMeta source) {
    if (source.name.contains("iptv-org")) return "国际";
    final h = _sourceHealth[source.name];
    if (h != null &&
        h.successCount >= 1 &&
        h.consecutiveFailures == 0 &&
        h.lastLatencyMs > 0 &&
        h.lastLatencyMs <= 3000) {
      return "优秀";
    }
    return "可用";
  }

  /// 源当前健康摘要，供管理页与选源弹窗展示（中性措辞）
  String sourceHealthLabel(IptvSourceMeta source) {
    final h = _sourceHealth[source.name];
    if (h == null || h.lastSuccessTime == null) return "尚未拉取";
    if (h.consecutiveFailures > 0) return "最近${h.consecutiveFailures}次未拉取到";
    return "连通${h.lastLatencyMs}ms";
  }

  // ==================== 进页自动刷新开关 ====================

  /// 进入 IPTV 页是否自动检查更新，默认开；关闭后进页只读缓存
  /// 存储服务未注册时（如单测环境）返回默认值
  bool get autoRefreshOnEnter => Get.isRegistered<LocalStorageService>()
      ? LocalStorageService.instance.getValue(
          LocalStorageService.kIptvAutoRefreshOnEnter,
          true,
        )
      : true;

  Future<void> setAutoRefreshOnEnter(bool value) async {
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvAutoRefreshOnEnter,
      value,
    );
  }

  /// 源配置变更后使聚合缓存失效，下次进入频道页按新源集合重拉
  void _invalidateAggregatedCache() {
    _aggregatedCacheTime = null;
  }

  /// 校验自定义源地址：拉取并解析，返回频道数；不可达或解析为空抛错
  Future<int> validateCustomSourceUrl(String url) async {
    final content = await HttpClient.instance
        .getText(url, header: {})
        .timeout(const Duration(seconds: 8));
    final result = M3uParser.parse(content, baseUrl: url);
    if (result.channels.isEmpty) {
      throw Exception("解析到 0 个频道，请确认是有效的 M3U/TXT 直播源地址");
    }
    return result.channels.length;
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
    _invalidateAggregatedCache();
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
    _sourceResultCache.remove(oldSource.name);
    _invalidateAggregatedCache();
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
    _sourceResultCache.remove(source.name);
    enabledSourceNames.remove(source.name);
    // 若删除后没有启用源，自动启用第一个剩余源
    if (enabledSourceNames.isEmpty && sourcePool.isNotEmpty) {
      enabledSourceNames.add(sourcePool.first.name);
    }
    _invalidateAggregatedCache();
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
    _sourceResultCache.clear();
    _invalidateAggregatedCache();
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
    _invalidateAggregatedCache();
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

  // ==================== 收藏标签 ====================

  /// 全部收藏标签，按名称排序
  List<IptvTag> getTags() {
    final tags = tagBox.values.toList()
      ..sort((a, b) => a.tag.compareTo(b.tag));
    return tags;
  }

  /// 新建收藏标签
  Future<IptvTag> createTag(String name) async {
    final tag = IptvTag(id: _uuid.v4(), tag: name, favoriteIds: []);
    await tagBox.put(tag.id, tag);
    return tag;
  }

  /// 重命名收藏标签
  Future<void> renameTag(IptvTag tag, String name) async {
    await tagBox.put(tag.id, tag.copyWith(tag: name));
  }

  /// 删除收藏标签（成员关系随标签消失，收藏本身不受影响）
  Future<void> deleteTag(IptvTag tag) async {
    await tagBox.delete(tag.id);
  }

  /// 收藏加入/移出标签
  Future<void> toggleFavoriteInTag(String favoriteId, IptvTag tag) async {
    final ids = [...tag.favoriteIds];
    if (ids.contains(favoriteId)) {
      ids.remove(favoriteId);
    } else {
      ids.add(favoriteId);
    }
    await tagBox.put(tag.id, tag.copyWith(favoriteIds: ids));
  }

  // ==================== 收藏功能 ====================
  List<IptvFavorite> getFavorites() => favoriteBox.values.toList();
  bool isFavorite(String id) => favoriteBox.containsKey(id);
  static String favoriteId(String playlistId, String url) => "${playlistId}_$url";

  /// 批量按 id 删除收藏（线路重排后收藏匹配用）
  Future<void> removeFavoritesByIds(List<String> ids) async {
    for (final id in ids) {
      await favoriteBox.delete(id);
    }
  }

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

  /// 拉取单个源：镜像按健康统计自动寻优（上次成功的排最前、失败多的靠后），
  /// 成功即返回；全部失败返回 null。每次结果都记入健康统计
  Future<M3uParseResult?> _fetchSourceWithMirrors(IptvSourceMeta source) async {
    final h = _healthOf(source.name);
    // 镜像寻优：上次成功的地址优先，其后按失败次数升序稳定排序
    final ordered = source.urls.toList()
      ..sort((a, b) {
        if (a == h.lastSuccessUrl && b != h.lastSuccessUrl) return -1;
        if (b == h.lastSuccessUrl && a != h.lastSuccessUrl) return 1;
        final fa = h.mirrorFailures[a] ?? 0;
        final fb = h.mirrorFailures[b] ?? 0;
        if (fa != fb) return fa.compareTo(fb);
        return source.urls.indexOf(a).compareTo(source.urls.indexOf(b));
      });
    for (final url in ordered) {
      final sw = Stopwatch()..start();
      try {
        final content = await HttpClient.instance
            .getText(url, header: {})
            .timeout(const Duration(seconds: 5));
        sw.stop();
        await _recordSourceFetch(source, success: true, url: url, latencyMs: sw.elapsedMilliseconds);
        return M3uParser.parse(content, baseUrl: url);
      } catch (e) {
        await _recordSourceFetch(source, success: false, url: url);
        Log.w("源 ${source.name} 地址 $url 拉取失败，尝试下一个镜像");
      }
    }
    return null;
  }

  /// 手动刷新范围：选中的源名称集合，空集合表示全部源
  Set<String> get refreshScope {
    final saved = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvRefreshScope,
      [],
    );
    return saved.cast<String>().toSet();
  }

  /// 保存手动刷新范围
  Future<void> setRefreshScope(Set<String> scope) async {
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvRefreshScope,
      scope.toList(),
    );
  }

  /// 拉取所有启用源并聚合频道，各源并发拉取（源内镜像串行容灾），单源失败自动跳过
  /// [onlySources] 限定本次实际拉取的源，范围外源沿用上次拉取结果，null 或空表示全部
  /// 各源并发拉取并聚合；[onSourceResult] 在每个源完成时回调（含沿用缓存的源），
  /// 页面借此做增量渲染，不让慢源拖住整个列表
  Future<AggregatedParseResult> refreshAggregated({
    Set<String>? onlySources,
    void Function(String sourceName, M3uParseResult? result)? onSourceResult,
  }) async {
    isLoading.value = true;
    final activeSources = enabledSources;
    final scope = (onlySources == null || onlySources.isEmpty) ? null : onlySources;
    totalSourceCount.value = activeSources.length;

    var completed = 0;
    final fetched = await Future.wait(
      activeSources.map((source) async {
        // 刷新范围外的源不发起请求，从未拉取过的源仍需拉取一次保证有数据
        if (scope != null && !scope.contains(source.name)) {
          final cached = _sourceResultCache[source.name];
          if (cached != null) {
            completed++;
            currentSourceIndex.value = completed;
            loadingMessage.value =
                "${source.name} 未选中，沿用上次结果（$completed/${activeSources.length}）";
            onSourceResult?.call(source.name, cached);
            return (sourceName: source.name, result: cached);
          }
        }
        final result = await _fetchSourceWithMirrors(source);
        completed++;
        currentSourceIndex.value = completed;
        loadingMessage.value =
            result == null
            ? "${source.name} 拉取失败，已跳过（$completed/${activeSources.length}）"
            : "已拉取 ${source.name}（$completed/${activeSources.length}）...";
        onSourceResult?.call(source.name, result);
        return (sourceName: source.name, result: result);
      }),
    );

    final allSourceResults = fetched
        .where((e) => e.result != null)
        .map((e) => (sourceName: e.sourceName, result: e.result!))
        .toList();

    if (allSourceResults.isEmpty) {
      isLoading.value = false;
      throw Exception("所有启用源均无法访问");
    }

    // 成功结果进入源级缓存，供下次部分刷新复用
    for (final entry in allSourceResults) {
      _sourceResultCache[entry.sourceName] = entry.result;
    }

    final result = _buildAggregated(allSourceResults);
    aggregatedCache = result;
    _aggregatedCacheTime = DateTime.now();
    await _persistAggregated(result);
    isLoading.value = false;
    return result;
  }

  /// 用已完成的部分源结果实时重建聚合，页面增量渲染用
  AggregatedParseResult buildPartialAggregation(Map<String, M3uParseResult> completed) {
    final entries = completed.entries
        .map((e) => (sourceName: e.key, result: e.value))
        .toList();
    return _buildAggregated(entries);
  }

  /// 聚合核心：按标准化名称合并跨源频道、URL 去重、置顶排序，并做探活绿灯线路前置
  AggregatedParseResult _buildAggregated(
    List<({String sourceName, M3uParseResult result})> allSourceResults,
  ) {
    final channelMap = <String, List<IptvLine>>{};
    final channelBaseInfo = <String, ({String name, String group, String logo})>{};

    // 源名随结果一起携带，避免中间源失败时后续源频道标签错位
    for (final entry in allSourceResults) {
      for (final ch in entry.result.channels) {
        final key = _normalizeName(ch.name);
        final line = IptvLine(
          sourceName: entry.sourceName,
          url: ch.url,
          logo: ch.logo,
          channelId: ch.id,
        );
        if (!channelMap.containsKey(key)) {
          channelMap[key] = <IptvLine>[];
          channelBaseInfo[key] = (name: ch.name, group: ch.group, logo: ch.logo);
        }
        // 镜像源（如 peterh 镜像 vbskycn）同频道会给出相同播放地址，按 URL 去重避免线路列表重复
        final isDuplicateUrl = channelMap[key]!.any((e) => e.url == line.url);
        if (isDuplicateUrl) continue;
        channelMap[key]!.add(line);
      }
    }

    var channels = channelMap.entries.map((entry) {
      final base = channelBaseInfo[entry.key]!;
      final lines = _sortLinesByProbe(entry.value);
      return AggregatedChannel(
        name: base.name,
        group: base.group,
        logo: base.logo,
        lines: lines,
      );
    }).toList();

    // 排序：央视、卫视置顶，央视按数字自然排序，其余按名称
    channels = _sortAggregatedChannels(channels);
    return AggregatedParseResult(channels: channels);
  }

  /// 线路排序：探活缓存里连通快的排前面，把最新可用线路放到起播优先位
  List<IptvLine> _sortLinesByProbe(List<IptvLine> lines) {
    int rank(IptvLine line) {
      final status = lastKnownLineInfo(line.url)?.status;
      return switch (status) { 1 => 0, 2 => 1, _ => 2 };
    }

    if (lines.length <= 1) return lines;
    final sorted = lines.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted;
  }

  /// 聚合频道排序：多级比较器——频道层级（央视/卫视/其他）→ 可用性
  /// （可用>未探测>全失败，可用数降序）→ CCTV编号 → 名称。
  /// 排序键先快照再比较，避免探测结果中途变化导致比较器不自洽
  List<AggregatedChannel> _sortAggregatedChannels(List<AggregatedChannel> list) {
    final keys = {
      for (final ch in list) ch: _availabilitySortKey(ch),
    };
    list.sort((a, b) {
      final ka = keys[a]!;
      final kb = keys[b]!;
      if (ka.groupRank != kb.groupRank) return ka.groupRank.compareTo(kb.groupRank);
      if (ka.availRank != kb.availRank) return ka.availRank.compareTo(kb.availRank);
      if (ka.okCount != kb.okCount) return kb.okCount.compareTo(ka.okCount);
      if (ka.cctvNumber != kb.cctvNumber) return ka.cctvNumber.compareTo(kb.cctvNumber);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  /// 频道可用性排序键：层级 + 可用档位（0=有可用,1=未探测,2=全失败）+ 可用数 + 编号
  ({int groupRank, int availRank, int okCount, int cctvNumber}) _availabilitySortKey(
    AggregatedChannel ch,
  ) {
    final groupRank = ch.group == "央视频道" ? 0 : (ch.group == "卫视频道" ? 1 : 2);
    var okCount = 0;
    var probed = 0;
    for (final line in ch.lines) {
      final status = lastKnownLineInfo(line.url)?.status;
      if (status == 1 || status == 2) okCount++;
      if (status != null) probed++;
    }
    final availRank = okCount > 0 ? 0 : (probed > 0 ? 2 : 1);
    final cctvNumber = _extractCctvNumber(ch.name) ?? 9999;
    return (groupRank: groupRank, availRank: availRank, okCount: okCount, cctvNumber: cctvNumber);
  }

  /// 按可用性对频道列表重排（探测动态重排用），与聚合排序同一套键
  List<AggregatedChannel> sortChannelsByAvailability(List<AggregatedChannel> list) {
    return _sortAggregatedChannels(list.toList());
  }

  /// 提取CCTV数字
  int? _extractCctvNumber(String name) {
    final match = RegExp(r'CCTV-?(\d+)').firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// 今日是否还可手动刷新：当日已成功刷新过则置灰按钮，次日自动恢复
  bool get canManualRefreshToday {
    final t = _aggregatedCacheTime;
    return t == null || !isSameLocalDay(t, DateTime.now());
  }

  /// 今日已刷新的时间文案，供刷新按钮提示，未刷新过返回空串
  String get lastRefreshLabel {
    final t = _aggregatedCacheTime;
    if (t == null) return "";
    final hh = t.hour.toString().padLeft(2, "0");
    final mm = t.minute.toString().padLeft(2, "0");
    return "${t.month}/${t.day} $hh:$mm";
  }

  /// 获取聚合结果，优先当日缓存，支持手动强制刷新；自动刷新失败时回退陈旧缓存
  /// 自动刷新同样遵循用户设置的刷新范围（refreshScope）
  Future<AggregatedParseResult> getAggregated({
    bool forceRefresh = false,
    void Function(String sourceName, M3uParseResult? result)? onSourceResult,
  }) async {
    final cacheValid = aggregatedCache != null &&
        _aggregatedCacheTime != null &&
        isSameLocalDay(_aggregatedCacheTime!, DateTime.now());
    if (!forceRefresh && cacheValid) return aggregatedCache!;
    try {
      return await refreshAggregated(
        onlySources: refreshScope,
        onSourceResult: onSourceResult,
      );
    } catch (e) {
      // 自动刷新全败时回退磁盘陈旧缓存（哪怕已过期），保证有台可看；手动刷新仍如实报错
      if (!forceRefresh && aggregatedCache != null) {
        Log.w("聚合拉取失败，回退陈旧缓存: $e");
        return aggregatedCache!;
      }
      rethrow;
    }
  }

  /// 进入频道页取数：「进页自动刷新」关闭且已有缓存时只读缓存，否则按需刷新
  Future<AggregatedParseResult> loadForEntry({
    void Function(String sourceName, M3uParseResult? result)? onSourceResult,
  }) async {
    if (!autoRefreshOnEnter && aggregatedCache != null) return aggregatedCache!;
    return getAggregated(onSourceResult: onSourceResult);
  }

  // ==================== 线路连通状态缓存 ====================

  /// 探测新鲜缓存：决定是否需要重新探测；红色失效最快，10 分钟即重验，绿/黄 30 分钟
  final Map<String, ({int status, int latencyMs, DateTime time})> _lineStatusCache =
      <String, ({int status, int latencyMs, DateTime time})>{};
  /// 最近已知状态：跨会话持久化，重启后排序与红绿灯直接暖启动
  final Map<String, ({int status, int latencyMs, DateTime time})> _lastKnownStatus =
      <String, ({int status, int latencyMs, DateTime time})>{};
  /// 最近已知状态落盘防抖定时器
  Timer? _knownSaveTimer;
  /// 最近已知状态容量上限，超出按探测时间淘汰最旧
  static const int _knownStatusCap = 4000;

  /// 新鲜度 TTL：按状态差异化，失效线路更快重验
  Duration _freshTtl(int status) =>
      status == 3 ? const Duration(minutes: 10) : const Duration(minutes: 30);

  /// 查询未过期的探测结果，未命中返回 null（1绿/2黄/3红）
  int? freshLineStatus(String url) => freshLineInfo(url)?.status;

  /// 查询未过期的探测结果详情（含探测延迟），未命中返回 null
  ({int status, int latencyMs, DateTime time})? freshLineInfo(String url) {
    final cached = _lineStatusCache[url];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.time) >= _freshTtl(cached.status)) {
      _lineStatusCache.remove(url);
      return null;
    }
    return cached;
  }

  /// 查询最近已知状态（不限时效，持久化恢复），供展示与排序暖启动
  ({int status, int latencyMs, DateTime time})? lastKnownLineInfo(String url) =>
      _lastKnownStatus[url];

  /// 写入探测结果：新鲜缓存立即更新，最近已知状态防抖落盘
  void cacheLineStatus(String url, int status, {int latencyMs = 0}) {
    final now = DateTime.now();
    _lineStatusCache[url] = (status: status, latencyMs: latencyMs, time: now);
    _lastKnownStatus[url] = (status: status, latencyMs: latencyMs, time: now);
    _knownSaveTimer ??= Timer(const Duration(seconds: 2), _persistKnownStatus);
  }

  /// 最近已知状态落盘：容量超限按最旧探测时间淘汰
  Future<void> _persistKnownStatus() async {
    _knownSaveTimer = null;
    try {
      if (_lastKnownStatus.length > _knownStatusCap) {
        final entries = _lastKnownStatus.entries.toList()
          ..sort((a, b) => a.value.time.compareTo(b.value.time));
        for (final e in entries.take(_lastKnownStatus.length - _knownStatusCap)) {
          _lastKnownStatus.remove(e.key);
        }
      }
      await LocalStorageService.instance.setValue(
        LocalStorageService.kIptvLineKnownStatus,
        _lastKnownStatus.map((k, v) => MapEntry(k, {
              "status": v.status,
              "latencyMs": v.latencyMs,
              "time": v.time.millisecondsSinceEpoch,
            })),
      );
    } catch (e) {
      Log.w("写入线路已知状态失败: $e");
    }
  }

  /// 启动时恢复最近已知状态
  void _loadKnownStatus() {
    try {
      final raw = LocalStorageService.instance.getValue<Map<dynamic, dynamic>>(
        LocalStorageService.kIptvLineKnownStatus,
        {},
      );
      _lastKnownStatus
        ..clear()
        ..addEntries(raw.entries.map((e) {
          final v = Map<dynamic, dynamic>.from(e.value as Map);
          final time = (v["time"] as num?)?.toInt() ?? 0;
          return MapEntry(e.key.toString(), (
            status: (v["status"] as num?)?.toInt() ?? 0,
            latencyMs: (v["latencyMs"] as num?)?.toInt() ?? 0,
            time: DateTime.fromMillisecondsSinceEpoch(time),
          ));
        }));
      Log.i("已恢复线路已知状态 ${_lastKnownStatus.length} 条");
    } catch (e) {
      Log.w("恢复线路已知状态失败: $e");
    }
  }

  // ==================== 线路偏好记忆 ====================

  /// 上次手动选择的线路源名称，起播时优先命中同名源的线路
  String get preferredLineSource => LocalStorageService.instance
      .getValue<String>(LocalStorageService.kIptvPreferredLineSource, "");

  /// 记录手动选择的线路源名称
  Future<void> setPreferredLineSource(String sourceName) async {
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvPreferredLineSource,
      sourceName,
    );
  }

  // ==================== 聚合缓存持久化 ====================

  /// 启动时从磁盘恢复上次聚合结果
  void _loadPersistedAggregated() {
    try {
      final raw = LocalStorageService.instance.getValue<String>(
        LocalStorageService.kIptvAggregatedCache,
        "",
      );
      final decoded = decodeAggregatedCache(raw);
      if (decoded == null) return;
      aggregatedCache = decoded.result;
      _aggregatedCacheTime = decoded.time;
      Log.i("已从磁盘恢复 IPTV 聚合缓存：${decoded.result.channels.length} 个频道");
    } catch (e) {
      Log.w("恢复 IPTV 聚合缓存失败: $e");
    }
  }

  /// 聚合成功后写入磁盘
  Future<void> _persistAggregated(AggregatedParseResult result) async {
    try {
      await LocalStorageService.instance.setValue(
        LocalStorageService.kIptvAggregatedCache,
        _encodeAggregated(result),
      );
    } catch (e) {
      Log.w("写入 IPTV 聚合缓存失败: $e");
    }
  }

  String _encodeAggregated(AggregatedParseResult result) =>
      encodeAggregatedChannels(result.channels);

  /// 聚合频道列表的 JSON 编码核心，落盘与单测共用
  static String encodeAggregatedChannels(List<AggregatedChannel> channels) {
    return jsonEncode({
      "time": DateTime.now().millisecondsSinceEpoch,
      "channels": channels
          .map((ch) => {
                "name": ch.name,
                "group": ch.group,
                "logo": ch.logo,
                "lines": ch.lines
                    .map((line) => {
                          "sourceName": line.sourceName,
                          "url": line.url,
                          "logo": line.logo,
                          "channelId": line.channelId,
                        })
                    .toList(),
              })
          .toList(),
    });
  }

  /// 解析落盘的聚合缓存，损坏或为空返回 null
  static ({AggregatedParseResult result, DateTime time})? decodeAggregatedCache(
    String raw,
  ) {
    if (raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final rawChannels = map["channels"];
      if (rawChannels is! List) return null;
      final channels = <AggregatedChannel>[];
      for (final entry in rawChannels) {
        if (entry is! Map) continue;
        final name = entry["name"]?.toString() ?? "";
        if (name.isEmpty) continue;
        final rawLines = entry["lines"];
        if (rawLines is! List) continue;
        final lines = <IptvLine>[];
        for (final rawLine in rawLines) {
          if (rawLine is! Map) continue;
          final url = rawLine["url"]?.toString() ?? "";
          if (url.isEmpty) continue;
          lines.add(IptvLine(
            sourceName: rawLine["sourceName"]?.toString() ?? "未知源",
            url: url,
            logo: rawLine["logo"]?.toString() ?? "",
            channelId: rawLine["channelId"]?.toString() ?? "",
          ));
        }
        if (lines.isEmpty) continue;
        channels.add(AggregatedChannel(
          name: name,
          group: entry["group"]?.toString() ?? "",
          logo: entry["logo"]?.toString() ?? "",
          lines: lines,
        ));
      }
      if (channels.isEmpty) return null;
      final time = int.tryParse(map["time"]?.toString() ?? "") ?? 0;
      return (
        result: AggregatedParseResult(channels: channels),
        time: DateTime.fromMillisecondsSinceEpoch(time),
      );
    } catch (e) {
      Log.w("解析 IPTV 聚合缓存失败: $e");
      return null;
    }
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
