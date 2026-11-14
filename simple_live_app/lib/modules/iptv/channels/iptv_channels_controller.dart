import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_app/services/iptv_service.dart';

class IptvChannelsController extends BaseController {
  final parseResult = Rxn<AggregatedParseResult>();
  final groups = <String>[].obs;
  final currentGroup = "".obs;
  final channels = <AggregatedChannel>[].obs;
  final favorites = <IptvFavorite>[].obs;
  final showFavorites = false.obs;
  final keyword = "".obs;

  // 横向分组条滚动控制器，选中项自动居中
  final ScrollController groupScrollController = ScrollController();
  final Map<String, GlobalKey> groupItemKeys = {};

  /// 线路连通状态：0=检测中，1=绿色（连通快），2=黄色（连通慢），3=红色（失败）
  final lineStatus = <String, int>{}.obs;

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
    _cancelLineStatusCheck();
    super.onClose();
  }

  /// 加载聚合数据，支持手动刷新
  Future<void> loadData({bool forceRefresh = false}) async {
    pageLoadding.value = true;
    try {
      final result = await IptvService.instance.getAggregated(forceRefresh: forceRefresh);
      parseResult.value = result;
      groups.value = IptvService.instance.getAggregatedGroups(result);
      currentGroup.value = "";
      keyword.value = "";
      applyFilter();
      _startLineStatusCheck(result.channels);
    } catch (e) {
      handleError(e, showPageError: true);
    } finally {
      pageLoadding.value = false;
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
          sw.stop();
          _recordLineStatus(url, sw.elapsedMilliseconds < 2000 ? 1 : 2);
        } catch (e) {
          // 403/401但能连通也算可用，仅网络超时/连接失败标红
          if (e is DioException && (e.response?.statusCode ?? 0) > 0) {
            _recordLineStatus(url, sw.elapsedMilliseconds < 2000 ? 1 : 2);
          } else {
            _recordLineStatus(url, 3);
          }
        }
      }));
    }
  }

  /// 记录探测结果：写 UI 状态并进入服务层 TTL 缓存
  void _recordLineStatus(String url, int status) {
    if (_probeCancelled) return;
    lineStatus[url] = status;
    IptvService.instance.cacheLineStatus(url, status);
  }

  /// 中止进行中的线路探测
  void _cancelLineStatusCheck() {
    _probeCancelled = true;
    _probeDio?.close();
    _probeDio = null;
  }

  /// 手动刷新所有源
  Future<void> onRefresh() async {
    await loadData(forceRefresh: true);
  }

  /// 选中项平滑滚动到视口中间
  void _scrollItemToCenter(GlobalKey? key) {
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

  void selectGroup(String group) {
    currentGroup.value = group;
    applyFilter();
    final key = groupItemKeys[group.isEmpty ? "全部" : group];
    _scrollItemToCenter(key);
  }

  void setKeyword(String value) {
    keyword.value = value;
    applyFilter();
  }

  void toggleFavoritesMode() {
    showFavorites.value = !showFavorites.value;
    refreshFavorites();
  }

  /// 按分组与关键词过滤
  void applyFilter() {
    final result = parseResult.value;
    if (result == null) {
      channels.clear();
      return;
    }
    var list = result.channels
        .where((e) => currentGroup.value.isEmpty || e.group == currentGroup.value)
        .toList();
    if (keyword.value.isNotEmpty) {
      final kw = keyword.value.toLowerCase();
      list = list.where((e) => e.name.toLowerCase().contains(kw)).toList();
    }
    channels.value = list;
  }

  void refreshFavorites() {
    favorites.value = IptvService.instance.getFavorites();
  }

  bool isFavoriteChannel(AggregatedChannel channel) {
    return favorites.any((e) =>
        e.name == channel.name && e.url == channel.defaultLine.url);
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

  /// 进入播放器，携带聚合频道与起始位置
  void openPlayer(AggregatedChannel channel, int index) {
    Get.toNamed(
      "/iptv/player",
      arguments: {
        "channels": channels,
        "index": index,
        "epgUrls": parseResult.value?.epgUrls ?? const <String>[],
      },
    );
  }
}
