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

  @override
  void onInit() {
    refreshFavorites();
    loadData();
    super.onInit();
  }

  @override
  void onClose() {
    groupScrollController.dispose();
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

  /// 异步检测所有线路连通性，控制并发避免压力过大
  Future<void> _startLineStatusCheck(List<AggregatedChannel> channels) async {
    final allLines = channels.expand((e) => e.lines).toList();
    // 初始化全部为检测中状态
    for (final line in allLines) {
      lineStatus[line.url] = 0;
    }
    const concurrency = 5;
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
    for (var i = 0; i < allLines.length; i += concurrency) {
      final batch = allLines.skip(i).take(concurrency).toList();
      await Future.wait(batch.map((line) async {
        final sw = Stopwatch()..start();
        try {
          await dio.head(line.url);
          sw.stop();
          lineStatus[line.url] = sw.elapsedMilliseconds < 2000 ? 1 : 2;
        } catch (_) {
          lineStatus[line.url] = 3;
        }
      }));
    }
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
