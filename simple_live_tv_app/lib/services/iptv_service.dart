import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../app/log.dart';
import '../models/db/iptv_favorite.dart';
import '../models/db/iptv_playlist.dart';
import '../modules/iptv/parser/aggregated_channel.dart';
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

  AggregatedParseResult? aggregatedCache;
  /// 聚合缓存生成时间，控制自动过期，同步源更新
  DateTime? _aggregatedCacheTime;
  /// 各源最近一次成功拉取的解析结果，「仅刷新部分源」时范围外源沿用此缓存
  final Map<String, M3uParseResult> _sourceResultCache = <String, M3uParseResult>{};
  /// 缓存按自然日失效：公开源均为日更，当天有效、次日进入频道页自动重拉
  static bool isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final RxBool isLoading = false.obs;
  final RxInt currentSourceIndex = 0.obs;
  final RxInt totalSourceCount = 0.obs;
  final RxString loadingMessage = "正在加载直播源...".obs;

  final RxList<String> enabledSourceNames = <String>[].obs;
  final RxList<IptvSourceMeta> customSources = <IptvSourceMeta>[].obs;
  final RxList<String> deletedPresetNames = <String>[].obs;

  List<IptvSourceMeta> get currentPresetSourcePool => defaultPresetSourcePool
      .where((e) => !deletedPresetNames.contains(e.name)).toList();

  List<IptvSourceMeta> get sourcePool => [...currentPresetSourcePool, ...customSources];

  /// 默认预置公开源池，用户删除后可通过恢复默认还原
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
      urls: ["https://peterhchina.github.io/iptv/IPTV-V4.m3u"],
    ),
  ];

  Future<void> init() async {
    playlistBox = await Hive.openBox<IptvPlaylist>(playlistBoxName);
    favoriteBox = await Hive.openBox<IptvFavorite>(favoriteBoxName);
    // 加载删除的预置源
    final savedDeleted = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvDeletedSources, [],
    );
    deletedPresetNames.assignAll(savedDeleted.cast<String>());
    // 加载启用状态，过滤无效源
    final defaultEnabled = currentPresetSourcePool.map((e) => e.name).toList();
    final savedEnabled = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvSourceEnabled, defaultEnabled,
    );
    enabledSourceNames.assignAll(savedEnabled.cast<String>().where((name) =>
      currentPresetSourcePool.any((e) => e.name == name) || customSources.any((e) => e.name == name)
    ).toList());
    // 加载自定义源
    final savedCustom = LocalStorageService.instance.getValue<List<dynamic>>(
      LocalStorageService.kIptvCustomSources, [],
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
    if (enabledSourceNames.isEmpty && sourcePool.isNotEmpty) {
      enabledSourceNames.add(sourcePool.first.name);
    }
    _invalidateAggregatedCache();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  /// 恢复默认源，清空自定义与删除状态
  Future<void> restoreDefaultSources() async {
    deletedPresetNames.clear();
    customSources.clear();
    enabledSourceNames.assignAll(defaultPresetSourcePool.map((e) => e.name));
    _sourceResultCache.clear();
    _invalidateAggregatedCache();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvDeletedSources, [],
    );
    await _saveCustomSources();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvSourceEnabled,
      enabledSourceNames.toList(),
    );
  }

  Future<void> _saveCustomSources() async {
    final data = customSources.map((e) => {"name": e.name, "urls": e.urls}).toList();
    await LocalStorageService.instance.setValue(
      LocalStorageService.kIptvCustomSources,
      data,
    );
  }

  Future<void> toggleSourceEnabled(IptvSourceMeta source) async {
    if (enabledSourceNames.contains(source.name)) {
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

  List<IptvSourceMeta> get enabledSources => sourcePool
      .where((e) => enabledSourceNames.contains(e.name))
      .toList();

  // ==================== 收藏功能 ====================
  List<IptvFavorite> getFavorites() => favoriteBox.values.toList();
  bool isFavorite(String id) => favoriteBox.containsKey(id);
  static String favoriteId(String playlistId, String url) => "${playlistId}_$url";

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
  String _normalizeName(String name) =>
      name.replaceAll(RegExp(r'[\s\-_]+'), "").toLowerCase();

  /// 拉取单个源，依次尝试所有镜像，成功即返回；全部失败返回 null
  Future<M3uParseResult?> _fetchSourceWithMirrors(IptvSourceMeta source) async {
    for (final url in source.urls) {
      try {
        final content = await HttpClient.instance.getText(url, header: {})
            .timeout(const Duration(seconds: 5));
        return M3uParser.parse(content, baseUrl: url);
      } catch (e) {
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

  /// 各源并发拉取（源内镜像串行容灾），单源失败自动跳过
  /// [onlySources] 限定本次实际拉取的源，范围外源沿用上次拉取结果，null 或空表示全部
  Future<AggregatedParseResult> refreshAggregated({Set<String>? onlySources}) async {
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
      return AggregatedChannel(
        name: base.name,
        group: base.group,
        logo: base.logo,
        lines: entry.value,
      );
    }).toList();

    channels = _sortAggregatedChannels(channels);
    final result = AggregatedParseResult(channels: channels);
    aggregatedCache = result;
    _aggregatedCacheTime = DateTime.now();
    await _persistAggregated(result);
    isLoading.value = false;
    return result;
  }

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
  Future<AggregatedParseResult> getAggregated({bool forceRefresh = false}) async {
    final cacheValid = aggregatedCache != null &&
        _aggregatedCacheTime != null &&
        isSameLocalDay(_aggregatedCacheTime!, DateTime.now());
    if (!forceRefresh && cacheValid) return aggregatedCache!;
    try {
      return await refreshAggregated(onlySources: refreshScope);
    } catch (e) {
      // 自动刷新全败时回退磁盘陈旧缓存（哪怕已过期），保证有台可看；手动刷新仍如实报错
      if (!forceRefresh && aggregatedCache != null) {
        Log.w("聚合拉取失败，回退陈旧缓存: $e");
        return aggregatedCache!;
      }
      rethrow;
    }
  }

  // ==================== 线路连通状态缓存 ====================

  /// 线路连通状态探测结果缓存：key 为线路 URL，TTL 内重复进入频道页不再重新探测
  final Map<String, ({int status, int latencyMs, DateTime time})> _lineStatusCache =
      <String, ({int status, int latencyMs, DateTime time})>{};
  /// 状态缓存有效期：红绿灯只是参考信息，10 分钟足够
  static const Duration _lineStatusTtl = Duration(minutes: 10);

  /// 查询未过期的线路状态缓存，未命中返回 null（1绿/2黄/3红）
  int? freshLineStatus(String url) => freshLineInfo(url)?.status;

  /// 查询未过期的线路状态缓存详情（含探测延迟），未命中返回 null
  ({int status, int latencyMs, DateTime time})? freshLineInfo(String url) {
    final cached = _lineStatusCache[url];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.time) >= _lineStatusTtl) {
      _lineStatusCache.remove(url);
      return null;
    }
    return cached;
  }

  /// 写入线路状态缓存，latencyMs 为探测请求耗时
  void cacheLineStatus(String url, int status, {int latencyMs = 0}) {
    _lineStatusCache[url] = (status: status, latencyMs: latencyMs, time: DateTime.now());
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

  String _encodeAggregated(AggregatedParseResult result) {
    return jsonEncode({
      "time": DateTime.now().millisecondsSinceEpoch,
      "channels": result.channels
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
