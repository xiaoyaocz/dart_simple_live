import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/custom_category_item.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/modules/category/custom_category_dialogs.dart';
import 'package:simple_live_app/services/custom_category_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/widgets/default_category_icon.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _FakeCategorySite extends LiveSite {
  _FakeCategorySite({
    this.roomDetail,
  });

  final LiveRoomDetail? roomDetail;
  final List<LiveSubCategory> requestedCategories = [];

  @override
  Future<List<LiveCategory>> getCategores() async => [
        LiveCategory(
          id: '103,4',
          name: '游戏',
          children: [
            LiveSubCategory(
              id: '1010001,1',
              name: '三角洲行动',
              parentId: '103,4',
            ),
            LiveSubCategory(
              id: '1010235,1',
              name: '王者万象棋',
              parentId: '2,1',
            ),
          ],
        ),
      ];

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    return roomDetail ?? await super.getRoomDetail(roomId: roomId);
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    requestedCategories.add(category);
    return LiveCategoryResult(
      hasMore: false,
      items: [
        LiveRoomItem(
          roomId: '357624720521',
          title: '万象棋测试直播间',
          cover: '',
          userName: '测试主播',
          online: 100,
        ),
      ],
    );
  }
}

void main() {
  tearDown(Get.reset);

  test(
      'CustomCategoryItem normalizes Douyin id and keeps pic null unless provided',
      () {
    final mappedDouyin = CustomCategoryItem.normalized(
      siteId: Constant.kDouyin,
      id: '1_1010002',
      name: '黑神话',
    );
    expect(mappedDouyin.id, '1010002,1');
    final mappedSub = mappedDouyin.toLiveSubCategory();
    expect(mappedSub.id, '1010002,1');
    expect(mappedSub.pic, isNull);

    expect(
      CustomCategoryItem.normalized(
        siteId: Constant.kDouyin,
        id: '1010235,1',
        name: '王者万象棋',
      ).toLiveSubCategory().pic,
      isNull,
    );
    expect(
      CustomCategoryItem.normalized(
        siteId: Constant.kBiliBili,
        id: '1034',
        parentId: '3',
        name: '王者万象棋',
      ).toLiveSubCategory().pic,
      isNull,
    );
    // 填写过自定义/在线图片链接时优先保留原链接
    expect(
      CustomCategoryItem.normalized(
        siteId: Constant.kHuya,
        id: '8127',
        name: '王者万象棋',
        pic: 'https://example.com/icon.png',
      ).toLiveSubCategory().pic,
      'https://example.com/icon.png',
    );
  });

  testWidgets(
      'DefaultCategoryIcon renders generic Material icon fallback cleanly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DefaultCategoryIcon(
                categoryName: '王者万象棋',
                siteId: Constant.kBiliBili,
              ),
              NetImage(
                '',
                width: 40,
                height: 40,
                fallbackWidget: DefaultCategoryIcon(
                  categoryName: '自定义测试',
                  siteId: Constant.kDouyin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DefaultCategoryIcon), findsNWidgets(2));
    expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
    expect(find.byIcon(Icons.category_rounded), findsOneWidget);
  });

  test('CustomCategoryService deduplicates, reorders and roundtrips JSON',
      () async {
    final service = CustomCategoryService();

    expect(
      await service.upsert(
        CustomCategoryItem.normalized(
          siteId: Constant.kDouyin,
          id: '1010016',
          name: '永劫无间',
        ),
      ),
      isTrue,
    );
    expect(
      await service.upsert(
        CustomCategoryItem.normalized(
          siteId: Constant.kBiliBili,
          id: '235',
          parentId: '2',
          name: 'DOTA2',
        ),
      ),
      isTrue,
    );
    // 同一抖音 ID 不同写法应去重覆盖而不是新增第二条
    expect(
      await service.upsert(
        CustomCategoryItem.normalized(
          siteId: Constant.kDouyin,
          id: '1_1010016',
          name: '永劫无间端游',
        ),
      ),
      isTrue,
    );

    expect(service.itemsForSite(Constant.kDouyin).length, 1);
    expect(
      service.findItem(Constant.kDouyin, '1010016,1')?.name,
      '永劫无间端游',
    );

    final exported = service.exportJson();
    final imported = CustomCategoryService.decodeList(exported);
    expect(imported.length, 2);

    await service.moveToTop(Constant.kDouyin, '1010016,1');
    expect(service.items.first.id, '1010016,1');

    await service.remove(Constant.kDouyin, '1010016,1');
    expect(service.contains(Constant.kDouyin, '1010016,1'), isFalse);
  });

  test('CategoryListController merges and syncs custom categories first',
      () async {
    Get.testMode = true;
    final service = Get.put(CustomCategoryService());
    final controller = CategoryListController(
      Site(
        id: Constant.kDouyin,
        name: '抖音直播',
        logo: '',
        liveSite: _FakeCategorySite(),
      ),
    );
    Get.put(controller, tag: Constant.kDouyin);

    await controller.loadData();
    expect(controller.list.length, 1);
    expect(controller.list.first.name, '游戏');

    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kDouyin,
        id: '1010016,1',
        name: '永劫无间',
      ),
    );

    expect(controller.list.length, 2);
    expect(controller.list.first.id, CategoryListController.kCustomGroupId);
    expect(controller.list.first.name, '自定义分区');
    expect(controller.list.first.children.single.name, '永劫无间');
  });

  testWidgets(
      'Add custom category dialog separates link quick-add and manual mode',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CustomCategoryDialogs.showAddOrEditDialog(
                initialSiteId: Constant.kDouyin,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 默认处于「链接一键添加」模式，只展示链接输入与「解析并添加」
    expect(find.text('链接一键添加'), findsOneWidget);
    expect(find.text('手动填写'), findsOneWidget);
    expect(find.text('解析并添加'), findsOneWidget);
    expect(find.text('分区名称 *'), findsNothing);
    expect(find.text('分区 ID *'), findsNothing);

    // 切换到「手动填写」模式后展示名称和 ID 输入框
    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();
    expect(find.text('分区名称 *'), findsOneWidget);
    expect(find.text('分区 ID *'), findsOneWidget);
    expect(find.text('验证并保存'), findsOneWidget);
    expect(find.text('直接保存'), findsOneWidget);
  });

  test(
      'CustomCategoryService persists manual categories across Hive restart for all platforms',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('custom_category_hive_');
    Hive.init(tempDir.path);
    await Get.put(LocalStorageService()).init();
    final service = Get.put(CustomCategoryService());

    try {
      final samples = [
        CustomCategoryItem.normalized(
          siteId: Constant.kBiliBili,
          id: '1034',
          parentId: '3',
          name: '王者万象棋',
        ),
        CustomCategoryItem.normalized(
          siteId: Constant.kDouyu,
          id: '181',
          name: '王者荣耀',
        ),
        CustomCategoryItem.normalized(
          siteId: Constant.kHuya,
          id: '8127',
          name: '王者万象棋',
        ),
        CustomCategoryItem.normalized(
          siteId: Constant.kKuaishou,
          id: '22814',
          name: '王者万象棋',
        ),
        CustomCategoryItem.normalized(
          siteId: Constant.kDouyin,
          id: '1_1010235',
          name: '王者万象棋',
        ),
      ];
      for (final item in samples) {
        expect(await service.upsert(item), isTrue);
      }

      final reloaded = CustomCategoryService()..onInit();
      expect(reloaded.items.length, 5);
      expect(reloaded.findItem(Constant.kBiliBili, '1034')?.parentId, '3');
      expect(reloaded.findItem(Constant.kDouyu, '181')?.name, '王者荣耀');
      expect(reloaded.findItem(Constant.kHuya, '8127')?.name, '王者万象棋');
      expect(reloaded.findItem(Constant.kKuaishou, '22814')?.name, '王者万象棋');
      expect(reloaded.findItem(Constant.kDouyin, '1010235,1')?.name, '王者万象棋');
    } finally {
      Get.reset();
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  testWidgets(
      'Manual mode validates Bilibili parentId, saves directly, and verifies online',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = Get.put(CustomCategoryService());

    final fakeDouyinSite = _FakeCategorySite();
    final origDouyin = Sites.allSites[Constant.kDouyin]!;
    Sites.allSites[Constant.kDouyin] = Site(
      id: origDouyin.id,
      name: origDouyin.name,
      logo: origDouyin.logo,
      liveSite: fakeDouyinSite,
    );
    addTearDown(() => Sites.allSites[Constant.kDouyin] = origDouyin);

    final biliController =
        CategoryListController(Sites.allSites[Constant.kBiliBili]!);
    Get.put(biliController, tag: Constant.kBiliBili);

    await tester.pumpWidget(
      GetMaterialApp(
        builder: FlutterSmartDialog.init(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CustomCategoryDialogs.showAddOrEditDialog(
                initialSiteId: Constant.kDouyin,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    // 1. 测试「手动填写 -> 切换哔哩哔哩 -> 父分区必填校验 -> 直接保存 + CategoryListController 更新」
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('哔哩哔哩').last);
    await tester.pumpAndSettle();
    expect(find.text('父分区 ID *'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '分区名称 *'),
      '王者万象棋',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '分区 ID *'),
      '1034',
    );
    await tester.tap(find.text('直接保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('B站分区需同时填写父分区 ID'), findsOneWidget);
    expect(service.items, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, '父分区 ID *'),
      '3',
    );
    await tester.tap(find.text('直接保存'));
    await tester.pumpAndSettle();

    expect(service.items.length, 1);
    final savedBili = service.findItem(Constant.kBiliBili, '1034');
    expect(savedBili, isNotNull);
    expect(savedBili!.parentId, '3');
    expect(savedBili.name, '王者万象棋');
    expect(biliController.list.first.id, CategoryListController.kCustomGroupId);

    // 2. 测试「手动填写 -> 抖音 1_1010235 -> 验证并保存」走在线接口并规范化为 1010235,1
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '分区名称 *'),
      '王者万象棋',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '分区 ID *'),
      '1_1010235',
    );
    await tester.tap(find.text('验证并保存'));
    await tester.pumpAndSettle();

    expect(fakeDouyinSite.requestedCategories.length, 1);
    expect(fakeDouyinSite.requestedCategories.single.id, '1010235,1');
    expect(service.findItem(Constant.kDouyin, '1010235,1')?.name, '王者万象棋');

    // 冲掉 SmartDialog Toast 定时器及其退出延迟定时器
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Link quick-add mode resolves both live room URLs and category URLs',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = Get.put(CustomCategoryService());
    final fakeDouyinSite = _FakeCategorySite(
      roomDetail: LiveRoomDetail(
        roomId: '357624720521',
        title: '王者万象棋冲分',
        cover: '',
        userName: '万象棋主播',
        userAvatar: '',
        online: 500,
        status: true,
        url: 'https://live.douyin.com/357624720521',
        categoryId: '1010235,1',
        categoryName: '王者万象棋',
        categoryParentId: '2,1',
        categoryParentName: '竞技游戏',
      ),
    );
    final origDouyin = Sites.allSites[Constant.kDouyin]!;
    Sites.allSites[Constant.kDouyin] = Site(
      id: origDouyin.id,
      name: origDouyin.name,
      logo: origDouyin.logo,
      liveSite: fakeDouyinSite,
    );
    addTearDown(() => Sites.allSites[Constant.kDouyin] = origDouyin);

    await tester.pumpWidget(
      GetMaterialApp(
        builder: FlutterSmartDialog.init(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CustomCategoryDialogs.showAddOrEditDialog(
                initialSiteId: Constant.kBiliBili,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    // 1. 粘贴抖音直播间分享文本，点击「解析并添加」自动识别分区并保存
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '直播间链接 / 分享口令 / 分区链接'),
      '直播间看一看 https://live.douyin.com/357624720521 复制口令',
    );
    await tester.tap(find.text('解析并添加'));
    await tester.pumpAndSettle();

    expect(service.findItem(Constant.kDouyin, '1010235,1')?.name, '王者万象棋');

    // 2. 粘贴抖音分区网页链接，点击「解析并添加」自动通过站点目录补全名称并保存
    await service.remove(Constant.kDouyin, '1010235,1');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '直播间链接 / 分享口令 / 分区链接'),
      'https://live.douyin.com/category/1_1010235',
    );
    await tester.tap(find.text('解析并添加'));
    await tester.pumpAndSettle();

    final addedFromCatUrl = service.findItem(Constant.kDouyin, '1010235,1');
    expect(addedFromCatUrl, isNotNull);
    expect(addedFromCatUrl!.name, '王者万象棋');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
