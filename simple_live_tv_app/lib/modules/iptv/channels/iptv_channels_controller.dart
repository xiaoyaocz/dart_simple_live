import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';
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

  final ScrollController groupScrollController = ScrollController();
  final Map<String, GlobalKey> groupItemKeys = {};

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

  Future<void> loadData({bool forceRefresh = false}) async {
    pageLoadding.value = true;
    try {
      final result = await IptvService.instance.getAggregated(forceRefresh: forceRefresh);
      parseResult.value = result;
      groups.value = IptvService.instance.getAggregatedGroups(result);
      currentGroup.value = "";
      keyword.value = "";
      applyFilter();
    } catch (e) {
      handleError(e, showPageError: true);
    } finally {
      pageLoadding.value = false;
    }
  }

  Future<void> onRefresh() => loadData(forceRefresh: true);

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
        "epgUrls": parseResult.value?.epgUrls ?? const <String>[],
      },
    );
  }
}
