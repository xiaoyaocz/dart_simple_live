import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/desktop_startup_args.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/category/category_controller.dart';
import 'package:simple_live_app/modules/category/category_page.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/modules/home/home_controller.dart';
import 'package:simple_live_app/modules/home/home_page.dart';
import 'package:simple_live_app/modules/iptv/channels/iptv_channels_controller.dart';
import 'package:simple_live_app/modules/iptv/channels/iptv_channels_page.dart';
import 'package:simple_live_app/modules/mine/mine_page.dart';
import 'package:simple_live_app/routes/app_navigation.dart';

class IndexedController extends GetxController {
  RxList<HomePageItem> items = RxList<HomePageItem>([]);

  var index = 0.obs;

  /// 页面按入口 key 缓存，隐藏/恢复入口时不会打乱已有页面
  final Map<int, Widget> _pageCache = {};

  StreamSubscription<dynamic>? _homeTabsSubscription;

  /// IndexedStack 子页：按当前可见入口顺序取，未访问过的仍占位
  List<Widget> get pageWidgets =>
      items.map((item) => _pageCache[item.index] ?? const SizedBox()).toList();

  Widget _createPage(int key) {
    switch (key) {
      case 0:
        Get.put(HomeController());
        return const HomePage();
      case 1:
        Get.put(FollowUserController());
        return const FollowUserPage();
      case 2:
        Get.put(CategoryController());
        return const CategoryPage();
      case 3:
        return const MinePage();
      case 4:
        Get.put(IptvChannelsController());
        return const IptvChannelsPage();
      default:
        return const SizedBox();
    }
  }

  void setIndex(int i) {
    if (i < 0 || i >= items.length) {
      return;
    }
    final key = items[i].index;
    if (!_pageCache.containsKey(key)) {
      _pageCache[key] = _createPage(key);
    } else if (index.value == i) {
      // 重复点击当前入口，交给页面自己处理（如回到顶部/刷新）
      EventBus.instance.emit<int>(
        EventBus.kBottomNavigationBarClicked,
        key,
      );
    }
    index.value = i;
  }

  void _loadItems() {
    final settings = AppSettingsController.instance;
    final list = settings.homeSort
        .where(settings.isHomeVisible)
        .map((key) => Constant.allHomePages[key])
        .whereType<HomePageItem>()
        .toList();
    // “我的”不可隐藏，这里仍兜底避免底栏为空
    items.value = list.isEmpty ? Constant.allHomePages.values.toList() : list;
  }

  /// 主页设置的显隐开关变化后重建底栏，无需重启
  void refreshTabs() {
    final previousKeys = items.map((item) => item.index).toSet();
    // 记住当前入口，隐藏别的入口后仍停留在原页面
    final currentKey =
        index.value < items.length ? items[index.value].index : null;
    _loadItems();
    if (items.isEmpty) {
      return;
    }
    var next = currentKey == null
        ? 0
        : items.indexWhere((item) => item.index == currentKey);
    if (next < 0) {
      next = 0;
    }
    index.value = next.clamp(0, items.length - 1);
    final key = items[index.value].index;
    _pageCache.putIfAbsent(key, () => _createPage(key));
    // 被隐藏入口的页面在本次重建帧结束后释放，避免 controller 常驻内存
    final removedKeys =
        previousKeys.difference(items.map((item) => item.index).toSet());
    if (removedKeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final removed in removedKeys) {
          _disposePage(removed);
        }
      });
    }
  }

  /// 释放被隐藏入口的页面及其 controller，重新显示时按需重建
  void _disposePage(int key) {
    _pageCache.remove(key);
    switch (key) {
      case 0:
        if (Get.isRegistered<HomeController>()) {
          Get.delete<HomeController>();
        }
        break;
      case 1:
        if (Get.isRegistered<FollowUserController>()) {
          Get.delete<FollowUserController>();
        }
        break;
      case 2:
        if (Get.isRegistered<CategoryController>()) {
          Get.delete<CategoryController>();
        }
        break;
      case 4:
        if (Get.isRegistered<IptvChannelsController>()) {
          Get.delete<IptvChannelsController>();
        }
        break;
    }
  }

  @override
  void onInit() {
    _homeTabsSubscription = EventBus.instance.listen(
      EventBus.kUpdateHomeTabs,
      (_) => refreshTabs(),
    );
    Future.delayed(Duration.zero, showFirstRun);
    Future.delayed(Duration.zero, restorePendingLiveRoom);
    _loadItems();
    setIndex(0);
    super.onInit();
  }

  @override
  void onClose() {
    _homeTabsSubscription?.cancel();
    super.onClose();
  }

  void showFirstRun() async {
    var settingsController = Get.find<AppSettingsController>();
    if (settingsController.firstRun) {
      settingsController.setNoFirstRun();
      await Utils.showStatement();
    }
  }

  void restorePendingLiveRoom() async {
    final settingsController = Get.find<AppSettingsController>();
    final startupRoom = DesktopStartupArgs.startupRoom;
    final lastRoom =
        startupRoom ?? await settingsController.consumePendingLastLiveRoom();
    if (lastRoom == null) {
      return;
    }
    final site = Sites.allSites[lastRoom["siteId"]];
    final roomId = lastRoom["roomId"];
    if (site == null || roomId == null || roomId.isEmpty) {
      return;
    }
    AppNavigator.toLiveRoomDetail(
      site: site,
      roomId: roomId,
      initialDesktopSidePanelCollapsed: DesktopStartupArgs.startupCollapseChat,
    );
  }
}
