import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';

/// 首页/分类/搜索共用的平台标签逻辑：
/// 持有 TabController，平台显隐或排序变化后重建标签，并保持当前停留的平台。
/// 宿主需同时 with [GetSingleTickerProviderStateMixin] 以提供 vsync。
mixin SiteTabsMixin on GetxController implements TickerProvider {
  late TabController tabController;

  /// 平台显隐变化时自增，触发页面用新 TabController 重建
  final RxInt sitesVersion = 0.obs;

  List<Site> _knownSites = Sites.visibleSites;
  StreamSubscription<dynamic>? _siteTabsSubscription;

  /// 宿主构造函数中初始化标签，可带初始下标
  void initSiteTabs({int initialIndex = 0}) {
    _knownSites = Sites.visibleSites;
    tabController = TabController(
      length: _knownSites.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  /// 监听平台显隐/排序变化（宿主 onInit 中调用）
  void listenSiteTabsChanged() {
    _siteTabsSubscription = EventBus.instance.listen(
      EventBus.kUpdateSiteTabs,
      (_) => rebuildSiteTabs(),
    );
  }

  /// 注册单个平台的列表 controller（宿主实现，需自行判重）
  void registerSiteListController(Site site);

  /// 释放单个平台的列表 controller（宿主实现，需自行判空）
  void unregisterSiteListController(Site site);

  /// 平台显隐/排序变化后重建标签，无需重启
  void rebuildSiteTabs() {
    final sites = Sites.visibleSites;
    if (sites.isEmpty) {
      return;
    }
    // 记住当前平台，排序/显隐变化后仍停在同一个平台
    String? currentId;
    if (_knownSites.isNotEmpty) {
      final currentIndex = tabController.index.clamp(
        0,
        _knownSites.length - 1,
      );
      currentId = _knownSites[currentIndex].id;
    }
    var initialIndex = currentId == null
        ? 0
        : sites.indexWhere((site) => site.id == currentId);
    if (initialIndex < 0) {
      initialIndex = 0;
    }
    final removedSites = _knownSites
        .where((site) => sites.every((newSite) => newSite.id != site.id))
        .toList();
    _knownSites = sites;
    final old = tabController;
    tabController = TabController(
      length: sites.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      // 页面树已按新标签重建完毕，此时释放被隐藏平台的列表 controller
      for (final site in removedSites) {
        unregisterSiteListController(site);
      }
    });
    for (final site in sites) {
      registerSiteListController(site);
    }
    onSiteTabsRebuilt(initialIndex);
    sitesVersion.value++;
  }

  /// 标签重建后的宿主钩子（同步自身状态，如搜索页的 index 与最近平台）
  void onSiteTabsRebuilt(int initialIndex) {}

  @override
  void onClose() {
    _siteTabsSubscription?.cancel();
    super.onClose();
  }
}
