import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';

class IptvChannelsController extends BaseController {
  final parseResult = Rxn<AggregatedParseResult>();
  final groups = <String>[].obs;
  final currentGroup = "".obs;
  final channels = <AggregatedChannel>[].obs;
  final favorites = <IptvFavorite>[].obs;
  final showFavorites = false.obs;
  final keyword = "".obs;

  /// 浏览维度：false=按分组筛选，true=按来源筛选；两个维度互斥
  final browseBySource = false.obs;
  /// 来源列表（去重，按聚合时的源池顺序）
  final sources = <String>[].obs;
  final currentSource = "".obs;

  /// 今日是否还可手动刷新：当日已成功刷新过则置灰按钮，次日自动恢复
  final canRefreshToday = true.obs;

  final ScrollController groupScrollController = ScrollController();
  final ScrollController sourceScrollController = ScrollController();
  final Map<String, GlobalKey> groupItemKeys = {};
  final Map<String, GlobalKey> sourceItemKeys = {};

  /// 线路连通状态：0=检测中，1=绿色（连通快），2=黄色（连通慢），3=红色（失败），4=未检测（超出上限，灰色静态）
  final lineStatus = <String, int>{}.obs;

  /// 单轮探测上限：国际源线路可达上万条，超过上限的线路标记为未检测，不做网络探测
  static const int maxProbeCount = 500;

  /// 线路探测取消标记与独立客户端，离开页面即中止
  bool _probeCancelled = false;
  Dio? _probeDio;

  @override
  void onInit() {
    refreshFavorites();
    loadData();
    super.onInit();
  }

  @override
  void onClose() {
    groupScrollController.dispose();
    sourceScrollController.dispose();
    _cancelLineStatusCheck();
    super.onClose();
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    pageLoadding.value = true;
    try {
      final result = await IptvService.instance.getAggregated(forceRefresh: forceRefresh);
      parseResult.value = result;
      groups.value = IptvService.instance.getAggregatedGroups(result);
      sources.value = result.channels
          .expand((e) => e.lines)
          .map((l) => l.sourceName)
          .toSet()
          .toList();
      currentGroup.value = "";
      currentSource.value = "";
      keyword.value = "";
      applyFilter();
      _startLineStatusCheck(result.channels);
    } catch (e) {
      handleError(e, showPageError: true);
    } finally {
      pageLoadding.value = false;
      canRefreshToday.value = IptvService.instance.canManualRefreshToday;
    }
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
      final cached = service.freshLineStatus(line.url);
      if (cached != null) {
        lineStatus[line.url] = cached;
      } else {
        lineStatus[line.url] = 0;
        pending.add(line.url);
      }
    }
    if (pending.isEmpty) return;
    // 超出单轮探测上限的线路不发起请求，标记为未检测（灰色静态），避免国际源上万线路拖垮页面
    for (var i = maxProbeCount; i < pending.length; i++) {
      lineStatus[pending[i]] = 4;
    }
    if (pending.length > maxProbeCount) {
      pending.removeRange(maxProbeCount, pending.length);
    }
    _probeCancelled = false;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {"Range": "bytes=0-1023"},
    ));
    _probeDio = dio;
    const concurrency = 5;
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

  /// 记录探测结果：写 UI 状态并进入服务层 TTL 缓存
  void _recordLineStatus(String url, int status, int latencyMs) {
    if (_probeCancelled) return;
    lineStatus[url] = status;
    IptvService.instance.cacheLineStatus(url, status, latencyMs: latencyMs);
  }

  /// 中止进行中的线路探测
  void _cancelLineStatusCheck() {
    _probeCancelled = true;
    _probeDio?.close();
    _probeDio = null;
  }

  /// 手动刷新：先选择本次要刷新的源（记忆上次选择），确认后仅拉取选中源，其余沿用上次结果
  Future<void> onRefresh() async {
    if (!canRefreshToday.value) return;
    final scope = await _pickRefreshScope();
    if (scope == null) return;
    await IptvService.instance.setRefreshScope(scope);
    await loadData(forceRefresh: true);
  }

  /// 刷新范围选择弹窗：返回选中的源名称集合，null 表示取消
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
    Set<String>? result;
    await Utils.showSystemRightDialog(
      width: 620.w,
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: AppStyle.edgeInsetsA32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "选择要刷新的源",
                style: AppStyle.titleStyleWhite.copyWith(fontSize: 32.w, fontWeight: FontWeight.bold),
              ),
              AppStyle.vGap8,
              Text(
                "未选中的源沿用上次拉取结果",
                style: AppStyle.textStyleWhite.copyWith(fontSize: 20.w, color: Colors.white54),
              ),
              AppStyle.vGap16,
              SizedBox(
                height: 560.w,
                child: ListView.builder(
                  itemCount: enabled.length,
                  itemBuilder: (_, i) {
                    final s = enabled[i];
                    final checked = selected.contains(s.name);
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.w),
                      child: HighlightButton(
                        focusNode: AppFocusNode(),
                        iconData: checked ? Icons.check_box : Icons.check_box_outline_blank,
                        text: s.name,
                        selected: checked,
                        onTap: () => setState(() =>
                            checked ? selected.remove(s.name) : selected.add(s.name)),
                      ),
                    );
                  },
                ),
              ),
              AppStyle.vGap16,
              Row(
                children: [
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    text: "全选",
                    onTap: () => setState(() {
                      selected
                        ..clear()
                        ..addAll(enabledNames);
                    }),
                  ),
                  AppStyle.hGap16,
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    text: "取消",
                    onTap: Get.back,
                  ),
                  AppStyle.hGap16,
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    text: "刷新",
                    selected: true,
                    onTap: selected.isEmpty
                        ? null
                        : () {
                            result = Set.of(selected);
                            Get.back();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }

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
  }

  /// 按当前维度（分组/来源）与关键词过滤
  void applyFilter() {
    final result = parseResult.value;
    if (result == null) {
      channels.clear();
      return;
    }
    Iterable<AggregatedChannel> list = result.channels;
    if (browseBySource.value) {
      // 来源维度：仅保留含该源线路的频道
      list = list.where((e) =>
          currentSource.value.isEmpty ||
          e.lines.any((l) => l.sourceName == currentSource.value));
    } else {
      list = list.where((e) =>
          currentGroup.value.isEmpty || e.group == currentGroup.value);
    }
    if (keyword.value.isNotEmpty) {
      final kw = keyword.value.toLowerCase();
      list = list.where((e) => e.name.toLowerCase().contains(kw));
    }
    channels.value = list.toList();
  }

  void refreshFavorites() {
    favorites.value = IptvService.instance.getFavorites();
  }

  bool isFavoriteChannel(AggregatedChannel channel) {
    return favorites.any((e) => e.name == channel.name && e.url == channel.defaultLine.url);
  }

  void toggleFavorite(AggregatedChannel channel) {
    final line = channel.defaultLine;
    IptvService.instance.toggleFavorite(
      playlistId: "aggregated",
      channel: channel,
      line: line,
    );
    refreshFavorites();
  }

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
