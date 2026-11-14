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
  /// 缓存自动过期时间：4小时，匹配公开源更新频率
  static const Duration _cacheMaxAge = Duration(hours: 4);

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
    if (enabledSourceNames.isEmpty && sourcePool.isNotEmpty) {
      enabledSourceNames.add(sourcePool.first.name);
    }
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

  /// 各源并发拉取（源内镜像串行容灾），单源失败自动跳过
  Future<AggregatedParseResult> refreshAggregated() async {
    isLoading.value = true;
    final activeSources = enabledSources;
    totalSourceCount.value = activeSources.length;

    var completed = 0;
    final fetched = await Future.wait(
      activeSources.map((source) async {
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

  Future<AggregatedParseResult> getAggregated({bool forceRefresh = false}) async {
    final cacheValid = aggregatedCache != null &&
        _aggregatedCacheTime != null &&
        DateTime.now().difference(_aggregatedCacheTime!) < _cacheMaxAge;
    if (!forceRefresh && cacheValid) return aggregatedCache!;
    try {
      return await refreshAggregated();
    } catch (e) {
      // 自动刷新全败时回退磁盘陈旧缓存（哪怕已过期），保证有台可看；手动刷新仍如实报错
      if (!forceRefresh && aggregatedCache != null) {
        Log.w("聚合拉取失败，回退陈旧缓存: $e");
        return aggregatedCache!;
      }
      rethrow;
    }
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
