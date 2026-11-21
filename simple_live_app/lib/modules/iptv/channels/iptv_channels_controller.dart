import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_app/modules/iptv/parser/m3u_parser.dart';
import 'package:simple_live_app/models/db/iptv_tag.dart';
import 'package:simple_live_app/services/iptv_service.dart';

class IptvChannelsController extends BaseController {
  final parseResult = Rxn<AggregatedParseResult>();
  final groups = <String>[].obs;
  final currentGroup = "".obs;
  final channels = <AggregatedChannel>[].obs;
  final favorites = <IptvFavorite>[].obs;
  final showFavorites = false.obs;
  final keyword = "".obs;
  /// 搜索框显隐
  final searchVisible = false.obs;

  /// 标签管理弹窗的新标签输入框
  final tagNewController = TextEditingController();

  /// 搜索框文本控制器（TV端输入框需要）
  final searchController = TextEditingController();

  /// 浏览维度：false=按分组筛选，true=按来源筛选；两个维度互斥
  final browseBySource = false.obs;
  /// 来源列表（去重，按聚合时的源池顺序）
  final sources = <String>[].obs;
  final currentSource = "".obs;

  /// 今日是否还可手动刷新：当日已成功刷新过则置灰按钮，次日自动恢复
  final canRefreshToday = true.obs;

  /// 刷新进行中：已有数据时保留列表，仅顶部显示进度
  final refreshing = false.obs;

  // 横向分组条/来源条滚动控制器，选中项自动居中
  final ScrollController groupScrollController = ScrollController();
  final ScrollController sourceScrollController = ScrollController();
  final ScrollController favoriteTagScrollController = ScrollController();
  final Map<String, GlobalKey> groupItemKeys = {};
  final Map<String, GlobalKey> sourceItemKeys = {};

  /// 线路连通状态：0=检测中，1=绿色（连通快），2=黄色（连通慢），3=红色（失败），4=未检测（超出上限，灰色静态）
  final lineStatus = <String, int>{}.obs;

  /// 单轮探测上限：国际源线路可达上万条，超过上限的线路标记为未检测，不做网络探测
  static const int maxProbeCount = 500;

  /// 线路探测取消标记与独立客户端，离开页面即中止
  bool _probeCancelled = false;
  Dio? _probeDio;

  /// 探测后动态重排：收集状态变化的 URL，节流重建各频道线路顺序，
  /// 保证播放拿到的列表永远是「最新可用优先」
  final Set<String> _dirtyProbeUrls = {};
  Timer? _resortTimer;

  /// 增量渲染：本轮刷新已完成拉取的源结果
  final Map<String, M3uParseResult> _completedSourceResults = {};

  @override
  void onInit() {
    refreshFavorites();
    refreshTags();
    loadData();
    super.onInit();
  }

  @override
  void onClose() {
    groupScrollController.dispose();
    sourceScrollController.dispose();
    favoriteTagScrollController.dispose();
    tagNewController.dispose();
    searchController.dispose();
    _resortTimer?.cancel();
    _cancelLineStatusCheck();
    super.onClose();
  }

  /// 加载聚合数据：首次进入整页 loading；已有数据时保留列表增量上屏
  Future<void> loadData({bool forceRefresh = false}) async {
    final hasData = parseResult.value != null;
    refreshing.value = hasData;
    pageLoadding.value = !hasData;
    _completedSourceResults.clear();
    try {
      final result = await IptvService.instance.loadForEntry(
        onSourceResult: _onSourceResult,
      );
      _applyParseResult(result);
      _startLineStatusCheck(result.channels);
    } catch (e) {
      handleError(e, showPageError: true);
    } finally {
      refreshing.value = false;
      pageLoadding.value = false;
      _updateRefreshState();
    }
  }

  /// 每个源拉取完成时的增量回调：刷新模式下立即重建聚合上屏，慢源不拖住整体
  void _onSourceResult(String sourceName, M3uParseResult? result) {
    if (result == null) return;
    _completedSourceResults[sourceName] = result;
    if (pageLoadding.value) return; // 首次加载保持整页 loading，最终结果统一上屏
    final partial = IptvService.instance.buildPartialAggregation(_completedSourceResults);
    _applyParseResult(partial, keepSelection: true);
  }

  /// 应用聚合结果：更新分组/来源列表与筛选视图
  void _applyParseResult(AggregatedParseResult result, {bool keepSelection = false}) {
    parseResult.value = result;
    groups.value = IptvService.instance.getAggregatedGroups(result);
    sources.value = result.channels
        .expand((e) => e.lines)
        .map((l) => l.sourceName)
        .toSet()
        .toList();
    if (!keepSelection) {
      currentGroup.value = "";
      currentSource.value = "";
      keyword.value = "";
    } else {
      // 选中的来源被移除时重置，避免空列表
      if (currentSource.value.isNotEmpty && !sources.contains(currentSource.value)) {
        currentSource.value = "";
      }
      if (currentGroup.value.isNotEmpty && !groups.contains(currentGroup.value)) {
        currentGroup.value = "";
      }
    }
    applyFilter();
  }

  /// 异步检测线路连通性：URL 去重 + TTL 缓存复用 + 控制并发，离开页面立即中止
  Future<void> _startLineStatusCheck(List<AggregatedChannel> channels) async {
    // 上一次探测若还在跑，先作废
    _cancelLineStatusCheck();
    final service = IptvService.instance;
    final pending = <String>[];
    final seen = <String>{};
    for (final line in channels.expand((e) => e.lines)) {
      // 镜像源重复 URL 只探测一次
      if (!seen.add(line.url)) continue;
      final fresh = service.freshLineStatus(line.url);
      if (fresh != null) {
        lineStatus[line.url] = fresh;
      } else {
        // 新鲜缓存未命中：先展示最近已知状态（暖启动），仍排入重探队列
        final known = service.lastKnownLineInfo(line.url);
        lineStatus[line.url] = known?.status ?? 0;
        pending.add(line.url);
      }
    }
    if (pending.isEmpty) return;
    _probeCancelled = false;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {"Range": "bytes=0-1023"},
    ));
    _probeDio = dio;
    const concurrency = 10;
    // 超出单轮探测上限的线路不发起请求；已有最近已知状态的保持展示，仅未知线路标灰色
    if (pending.length > maxProbeCount) {
      for (var i = maxProbeCount; i < pending.length; i++) {
        if ((lineStatus[pending[i]] ?? 0) == 0) {
          lineStatus[pending[i]] = 4;
        }
      }
      pending.removeRange(maxProbeCount, pending.length);
    }
    for (var i = 0; i < pending.length; i += concurrency) {
      if (_probeCancelled) return;
      final batch = pending.skip(i).take(concurrency).toList();
      await Future.wait(batch.map((url) async {
        final sw = Stopwatch()..start();
        try {
          // 用GET Range替代HEAD，兼容不支持HEAD的流媒体服务器
          await dio.get(url);
          final ms = sw.elapsedMilliseconds;
          _recordLineStatus(url, ms < 2000 ? 1 : 2, ms);
        } catch (e) {
          final ms = sw.elapsedMilliseconds;
          // 403/401但能连通也算可用，仅网络超时/连接失败标红
          if (e is DioException && (e.response?.statusCode ?? 0) > 0) {
            _recordLineStatus(url, ms < 2000 ? 1 : 2, ms);
          } else {
            _recordLineStatus(url, 3, ms);
          }
        }
      }));
    }
  }

  /// 记录探测结果：写 UI 状态、进入服务层 TTL 缓存，并触发节流重排
  void _recordLineStatus(String url, int status, int latencyMs) {
    if (_probeCancelled) return;
    lineStatus[url] = status;
    IptvService.instance.cacheLineStatus(url, status, latencyMs: latencyMs);
    _dirtyProbeUrls.add(url);
    _resortTimer ??= Timer(const Duration(milliseconds: 1200), _applyProbeResort);
  }

  /// 节流重排：把探测状态变化的频道线路按最新可用重排，播放即拿到最新可用优先的顺序
  void _applyProbeResort() {
    _resortTimer = null;
    if (_dirtyProbeUrls.isEmpty) return;
    final dirty = _dirtyProbeUrls..clear();
    final result = parseResult.value;
    if (result == null) return;
    var lineChanged = false;
    final resorted = result.channels.map((ch) {
      if (!ch.lines.any((l) => dirty.contains(l.url))) return ch;
      final sorted = ch.lines.toList()
        ..sort((a, b) => _probeRank(a.url).compareTo(_probeRank(b.url)));
      var same = true;
      for (var i = 0; i < sorted.length; i++) {
        if (!identical(sorted[i], ch.lines[i])) {
          same = false;
          break;
        }
      }
      if (same) return ch;
      lineChanged = true;
      return AggregatedChannel(
        name: ch.name,
        group: ch.group,
        logo: ch.logo,
        lines: sorted,
      );
    }).toList();
    // 频道级可用性重排：层级 → 可用性 → 编号，可用多的靠前、全失败的沉底
    final availSorted = IptvService.instance.sortChannelsByAvailability(resorted);
    var orderSame = !lineChanged && availSorted.length == result.channels.length;
    if (orderSame) {
      for (var i = 0; i < availSorted.length; i++) {
        if (!identical(availSorted[i], result.channels[i])) {
          orderSame = false;
          break;
        }
      }
    }
    if (orderSame) return;
    parseResult.value = AggregatedParseResult(channels: availSorted);
    applyFilter();
  }

  int _probeRank(String url) => lineRank(url);

  /// 线路排序权重：绿0 黄1 红或其他2，供页面渲染时实时排序
  int lineRank(String url) => switch (lineStatus[url] ?? 0) {
        1 => 0,
        2 => 1,
        _ => 2,
      };

  /// 中止进行中的线路探测
  void _cancelLineStatusCheck() {
    _probeCancelled = true;
    _probeDio?.close();
    _probeDio = null;
  }

  /// 手动刷新：先选择本次要刷新的源（记忆上次选择），确认后仅拉取选中源，其余沿用上次结果。
  /// 当日已刷新过时弹确认提示（建议制而非强制拦截），坚持则照常刷新
  Future<void> onRefresh() async {
    final scope = await _pickRefreshScope();
    if (scope == null) return;
    if (!IptvService.instance.canManualRefreshToday) {
      final confirmed = await _confirmRepeatRefresh();
      if (!confirmed) return;
    }
    await IptvService.instance.setRefreshScope(scope);
    await loadData(forceRefresh: true);
  }

  /// 当日重复刷新确认框
  Future<bool> _confirmRepeatRefresh() async {
    final label = IptvService.instance.lastRefreshLabel;
    final result = await showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text("今日已刷新过"),
        content: Text(
          "公开源为日更，今日 $label 已更新过。\n频繁刷新会增加源站压力，确定要再次刷新吗？",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text("仍要刷新"),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// 刷新范围选择弹窗：按源分级展示健康摘要，返回选中的源名称集合，null 表示取消
  Future<Set<String>?> _pickRefreshScope() async {
    final service = IptvService.instance;
    final enabled = service.enabledSources;
    if (enabled.isEmpty) return null;
    final enabledNames = enabled.map((e) => e.name).toSet();
    final saved = service.refreshScope;
    final selected = saved.isEmpty
        ? <String>{...enabledNames}
        : saved.intersection(enabledNames);
    if (selected.isEmpty) selected.addAll(enabledNames);
    return showDialog<Set<String>>(
      context: Get.context!,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("选择要刷新的源"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("未选中的源沿用上次拉取结果", style: TextStyle(fontSize: 12, color: Colors.grey)),
              AppStyle.vGap8,
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: enabled
                      .map((s) => CheckboxListTile(
                            dense: true,
                            title: Text(s.name),
                            subtitle: Text(
                              "${service.sourceCategory(s)} · ${service.sourceHealthLabel(s)}",
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            value: selected.contains(s.name),
                            onChanged: (v) => setState(() => v == true
                                ? selected.add(s.name)
                                : selected.remove(s.name)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () => setState(() {
                selected
                  ..clear()
                  ..addAll(enabledNames);
              }),
              child: const Text("全选"),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Get.back(result: Set.of(selected)),
              child: const Text("刷新"),
            ),
          ],
        ),
      ),
    );
  }

  /// 同步刷新按钮置灰状态
  void _updateRefreshState() {
    canRefreshToday.value = IptvService.instance.canManualRefreshToday;
  }

  /// 选中项平滑滚动到视口中间
  void _scrollItemToCenter(ScrollController controller, GlobalKey? key) {
    if (key?.currentContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// 切换浏览维度，两个维度互斥、切换时重置选中项
  void switchBrowseMode(bool bySource) {
    if (browseBySource.value == bySource) return;
    browseBySource.value = bySource;
    currentGroup.value = "";
    currentSource.value = "";
    applyFilter();
  }

  void selectGroup(String group) {
    currentGroup.value = group;
    applyFilter();
    final key = groupItemKeys[group.isEmpty ? "全部" : group];
    _scrollItemToCenter(groupScrollController, key);
  }

  void selectSource(String source) {
    currentSource.value = source;
    applyFilter();
    final key = sourceItemKeys[source.isEmpty ? "全部" : source];
    _scrollItemToCenter(sourceScrollController, key);
  }

  void setKeyword(String value) {
    keyword.value = value;
    applyFilter();
  }

  void toggleFavoritesMode() {
    showFavorites.value = !showFavorites.value;
    refreshFavorites();
    refreshTags();
  }

  void toggleSearch() {
    searchVisible.value = !searchVisible.value;
    if (!searchVisible.value) {
      // 关闭搜索时清空关键字与输入框残留
      searchController.clear();
      if (keyword.value.isNotEmpty) {
        setKeyword("");
      }
    }
  }

  /// 按当前维度（分组/来源）、关键词与收藏模式过滤
  void applyFilter() {
    final result = parseResult.value;
    if (result == null) {
      channels.clear();
      return;
    }
    Iterable<AggregatedChannel> list = result.channels;
    if (showFavorites.value) {
      // 收藏模式：当前标签下的收藏频道，按任意线路 URL 匹配
      final urls = favoritesOfTag(selectedTagId.value)
          .expand((e) => e.lines.map((l) => l.url))
          .toSet();
      list = list.where((e) => e.lines.any((l) => urls.contains(l.url)));
    } else if (browseBySource.value) {
      // 来源维度：仅保留含该源线路的频道
      list = list.where((e) =>
          currentSource.value.isEmpty ||
          e.lines.any((l) => l.sourceName == currentSource.value));
    } else {
      list = list.where((e) =>
          currentGroup.value.isEmpty || e.group == currentGroup.value);
    }
    final kw = keyword.value.trim().toLowerCase();
    if (kw.isNotEmpty) {
      // 本地搜索：频道名或来源名任一命中
      list = list.where((e) =>
          e.name.toLowerCase().contains(kw) ||
          e.lines.any((l) => l.sourceName.toLowerCase().contains(kw)));
    }
    channels.value = list.toList();
  }

  // ==================== 收藏与标签 ====================

  void refreshFavorites() {
    favorites.value = IptvService.instance.getFavorites();
    applyFilter();
  }

  /// 收藏匹配按任意线路 URL：探测重排后 defaultLine 会变，不能只比对首条
  bool isFavoriteChannel(AggregatedChannel channel) {
    return favorites.any((e) =>
        e.name == channel.name && channel.lines.any((l) => l.url == e.url));
  }

  void toggleFavorite(AggregatedChannel channel) {
    // 已收藏（任意线路）则全部取消，避免重排后同频道重复收藏多条线路
    final existing = favorites
        .where((e) =>
            e.name == channel.name && channel.lines.any((l) => l.url == e.url))
        .toList();
    if (existing.isNotEmpty) {
      IptvService.instance.removeFavoritesByIds(existing.map((e) => e.id).toList());
    } else {
      IptvService.instance.toggleFavorite(
        playlistId: "aggregated",
        channel: channel,
        line: channel.defaultLine,
      );
    }
    refreshFavorites();
  }

  /// 标签列表（响应式，供标签条与标签管理弹窗使用）
  final tags = <IptvTag>[].obs;
  /// 当前收藏筛选的标签 id，空串=全部
  final selectedTagId = "".obs;

  void refreshTags() {
    tags.value = IptvService.instance.getTags();
  }

  /// 当前标签下的收藏频道：全部 / 未分组（不在任何标签内）/ 指定标签
  List<AggregatedChannel> favoritesOfTag(String tagId) {
    final service = IptvService.instance;
    Iterable<IptvFavorite> scope = favorites;
    if (tagId == ungroupedTagId) {
      final taggedIds = service.getTags().expand((t) => t.favoriteIds).toSet();
      scope = favorites.where((f) => !taggedIds.contains(f.id));
    } else if (tagId.isNotEmpty) {
      final tag = service.getTags().firstWhere(
            (t) => t.id == tagId,
            orElse: () => IptvTag(id: "", tag: "", favoriteIds: []),
          );
      scope = favorites.where((f) => tag.favoriteIds.contains(f.id));
    }
    final urls = scope.map((e) => e.url).toSet();
    return parseResult.value?.channels
            .where((e) => e.lines.any((l) => urls.contains(l.url)))
            .toList() ??
        <AggregatedChannel>[];
  }

  static const String allTagId = "";
  static const String ungroupedTagId = "__ungrouped__";

  void selectTag(String tagId) {
    selectedTagId.value = tagId;
    applyFilter();
  }

  /// 进入播放器，携带聚合频道与起始位置
  void openPlayer(AggregatedChannel channel, int index) {
    Get.toNamed(
      "/iptv/player",
      arguments: {
        "channels": channels,
        "index": index,
      },
    );
  }
}
