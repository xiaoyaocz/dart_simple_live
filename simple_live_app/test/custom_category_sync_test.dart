import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/custom_category_item.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/models/db/iptv_playlist.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_page.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/custom_category_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/douyu_account_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/iptv_service.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';

void _registerAdapterIfNeeded<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    Get.testMode = true;
    tempDir = await Directory.systemTemp.createTemp('custom_category_sync_');
    Hive.init(tempDir.path);
    _registerAdapterIfNeeded(FollowUserAdapter());
    _registerAdapterIfNeeded(HistoryAdapter());
    _registerAdapterIfNeeded(FollowUserTagAdapter());
    _registerAdapterIfNeeded(IptvPlaylistAdapter());
    _registerAdapterIfNeeded(IptvFavoriteAdapter());

    Utils.packageInfo = PackageInfo(
      appName: 'SimpleLiveTest',
      packageName: 'com.example.simple_live_app',
      version: '1.13.4',
      buildNumber: '11304',
    );

    await Get.put(LocalStorageService()).init();
    await Get.put(DBService()).init();
    await Get.put(IptvService()).init();
    Get.put(AppSettingsController());
    Get.put(BiliBiliAccountService());
    Get.put(DouyinAccountService());
    Get.put(DouyuAccountService());
    Get.put(KuaishouAccountService());
    Get.put(FollowService());
    Get.put(CustomCategoryService());
    Get.put(LiveSubtitleService());
    Get.put(ProfileBackupService());
  });

  tearDown(() async {
    if (Get.isRegistered<FollowService>()) {
      await Get.delete<FollowService>(force: true);
    }
    await Get.deleteAll(force: true);
    Get.reset();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ProfileBackupService exports, merges and overwrites customCategories',
      () async {
    final service = CustomCategoryService.instance;
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kDouyin,
        id: '1010235',
        name: '王者万象棋',
      ),
    );
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kBiliBili,
        id: '1034',
        parentId: '3',
        name: '王者万象棋',
      ),
    );

    final exported = ProfileBackupService.instance.exportProfileMap();
    final exportedCats = exported['customCategories'] as List;
    expect(exportedCats.length, 2);
    expect((exported['summary'] as Map)['customCategoryCount'], 2);
    expect(
      (exported['settings'] as Map)
          .containsKey(LocalStorageService.kCustomCategories),
      isFalse,
    );

    // 清空本地再追加另一条，测试 overwrite=false 合并恢复
    await service.applySyncData(const [], overwrite: true);
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kHuya,
        id: '8127',
        name: '虎牙万象棋',
      ),
    );

    final mergeSummary = await ProfileBackupService.instance.importProfileJson(
      jsonEncode(exported),
      overwrite: false,
    );
    expect(mergeSummary.customCategories, 2);
    expect(mergeSummary.message, contains('自定义分区 2 个'));
    expect(service.items.length, 3);
    expect(service.contains(Constant.kHuya, '8127'), isTrue);
    expect(service.contains(Constant.kDouyin, '1010235,1'), isTrue);
    expect(service.contains(Constant.kBiliBili, '1034'), isTrue);

    // 覆盖导入会移除本地多出的那一条，只保留配置包里的条目
    final overwriteSummary =
        await ProfileBackupService.instance.importProfileJson(
      jsonEncode(exported),
      overwrite: true,
    );
    expect(overwriteSummary.customCategories, 2);
    expect(service.items.length, 2);
    expect(service.contains(Constant.kHuya, '8127'), isFalse);

    // 验证重启（重新从 Hive 初始化）后依然存在
    final reloaded = CustomCategoryService()..onInit();
    expect(reloaded.items.length, 2);
    expect(reloaded.findItem(Constant.kBiliBili, '1034')?.parentId, '3');
  });

  test(
      'ProfileBackupService respects customCategories option and legacy payloads',
      () async {
    final service = CustomCategoryService.instance;
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kKuaishou,
        id: '22814',
        name: '王者万象棋',
      ),
    );

    final exported = ProfileBackupService.instance.exportProfileMap();
    final incomingProfile = Map<String, dynamic>.from(exported)
      ..['customCategories'] = [
        CustomCategoryItem.normalized(
          siteId: Constant.kDouyu,
          id: '3785',
          name: '斗鱼测试',
        ).toJson(),
      ];

    // 1. options.customCategories = false 时，即使 overwrite=true + settings=true 也不应覆盖本地分区
    await ProfileBackupService.instance.importProfileJson(
      jsonEncode(incomingProfile),
      overwrite: true,
      options: const ProfileImportOptions(
        settings: true,
        customCategories: false,
      ),
    );
    expect(service.items.length, 1);
    expect(service.contains(Constant.kKuaishou, '22814'), isTrue);

    // 2. 老配置包完全不含 customCategories 字段也不应误删本地自定义分区
    final preFeatureProfile = Map<String, dynamic>.from(exported)
      ..remove('customCategories');
    await ProfileBackupService.instance.importProfileJson(
      jsonEncode(preFeatureProfile),
      overwrite: true,
    );
    expect(service.items.length, 1);
    expect(service.contains(Constant.kKuaishou, '22814'), isTrue);

    // 3. 仅有 settings["CustomCategories"] 的历史过渡配置包也能迁移恢复
    final legacySettingsProfile = Map<String, dynamic>.from(preFeatureProfile);
    legacySettingsProfile['settings'] = {
      LocalStorageService.kCustomCategories: jsonEncode([
        CustomCategoryItem.normalized(
          siteId: Constant.kDouyu,
          id: '3785',
          name: '斗鱼测试',
        ).toJson(),
      ]),
    };
    await ProfileBackupService.instance.importProfileJson(
      jsonEncode(legacySettingsProfile),
      overwrite: true,
    );
    expect(service.items.length, 1);
    expect(service.contains(Constant.kDouyu, '3785'), isTrue);
  });

  test(
      'RemoteSyncWebDAVController backs up and restores custom categories automatically',
      () async {
    final service = CustomCategoryService.instance;
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kDouyin,
        id: '1010235',
        name: '王者万象棋',
      ),
    );
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kDouyu,
        id: '3785',
        name: '斗鱼万象棋',
      ),
    );

    final webdav = Get.put(RemoteSyncWebDAVController());
    expect(webdav.isSyncCustomCategories.value, isTrue);

    final zipBytes = await webdav.buildBackupArchiveBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final fileNames = archive.map((f) => f.name).toSet();
    expect(fileNames, contains('SimpleLive_Profile_v3.json'));
    expect(fileNames, contains('SimpleLive_custom_categories.json'));

    final settingsFile =
        archive.firstWhere((f) => f.name == 'SimpleLive_Settings.json');
    final settingsJson =
        jsonDecode(utf8.decode(settingsFile.content)) as Map<String, dynamic>;
    final settingsData = settingsJson['data'] as Map<String, dynamic>;
    expect(
      settingsData.containsKey(LocalStorageService.kCustomCategories),
      isFalse,
    );

    // 清空本地并加入不同数据后恢复 -> 默认启用同步自定义分区，全量恢复备份中的 2 条
    await service.applySyncData(const [], overwrite: true);
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kHuya,
        id: '8127',
        name: '本地虎牙',
      ),
    );
    await webdav.applyWebDAVBackupBytes(zipBytes);
    expect(service.items.length, 2);
    expect(service.contains(Constant.kDouyin, '1010235,1'), isTrue);
    expect(service.contains(Constant.kDouyu, '3785'), isTrue);
    expect(service.contains(Constant.kHuya, '8127'), isFalse);

    // 关闭「同步自定义分区」后，本地自定义分区应保留而不被恢复内容覆盖
    webdav.changeIsSyncCustomCategories();
    expect(webdav.isSyncCustomCategories.value, isFalse);
    await service.applySyncData(const [], overwrite: true);
    await service.upsert(
      CustomCategoryItem.normalized(
        siteId: Constant.kHuya,
        id: '8127',
        name: '本地虎牙',
      ),
    );
    await webdav.applyWebDAVBackupBytes(zipBytes);
    expect(service.items.length, 1);
    expect(service.contains(Constant.kHuya, '8127'), isTrue);
    expect(service.contains(Constant.kDouyin, '1010235,1'), isFalse);
  });

  test(
      'RemoteSyncWebDAVController legacy zip handles file ordering, settings fallback and pre-feature preservation',
      () async {
    final service = CustomCategoryService.instance;
    final webdav = Get.put(RemoteSyncWebDAVController());

    // 场景 A: 无 Profile_v3，且 SimpleLive_custom_categories.json 排在 SimpleLive_Settings.json 前面
    // settingsBox.clear() 不应清空刚刚恢复的自定义分区
    final orderedArchive = Archive()
      ..addFile(
        ArchiveFile.string(
          'SimpleLive_custom_categories.json',
          jsonEncode({
            'data': [
              CustomCategoryItem.normalized(
                siteId: Constant.kBiliBili,
                id: '1034',
                parentId: '3',
                name: 'B站万象棋',
              ).toJson(),
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'SimpleLive_Settings.json',
          jsonEncode({'data': <String, dynamic>{}}),
        ),
      );
    final orderedZip = ZipEncoder().encode(orderedArchive);

    await webdav.applyWebDAVBackupBytes(orderedZip);
    expect(service.items.length, 1);
    expect(service.contains(Constant.kBiliBili, '1034'), isTrue);

    // 场景 B: 旧版 zip 只有 SimpleLive_Settings.json 且完全不含 CustomCategories，不应误删本地自定义分区
    final preFeatureArchive = Archive()
      ..addFile(
        ArchiveFile.string(
          'SimpleLive_Settings.json',
          jsonEncode({'data': <String, dynamic>{}}),
        ),
      );
    await webdav.applyWebDAVBackupBytes(ZipEncoder().encode(preFeatureArchive));
    expect(service.items.length, 1);
    expect(service.contains(Constant.kBiliBili, '1034'), isTrue);

    // 场景 C: 旧版 zip 只有 SimpleLive_Settings.json 携带 CustomCategories，会自动迁移恢复
    await service.applySyncData(const [], overwrite: true);
    final settingsOnlyArchive = Archive()
      ..addFile(
        ArchiveFile.string(
          'SimpleLive_Settings.json',
          jsonEncode({
            'data': {
              LocalStorageService.kCustomCategories: jsonEncode([
                CustomCategoryItem.normalized(
                  siteId: Constant.kKuaishou,
                  id: '22814',
                  name: '快手万象棋',
                ).toJson(),
              ]),
            },
          }),
        ),
      );
    final settingsOnlyZip = ZipEncoder().encode(settingsOnlyArchive);

    await webdav.applyWebDAVBackupBytes(settingsOnlyZip);
    expect(service.items.length, 1);
    expect(service.contains(Constant.kKuaishou, '22814'), isTrue);
  });

  testWidgets(
      'WebDAV page exposes sync options and defaults custom category sync to true',
      (tester) async {
    final controller = Get.put(RemoteSyncWebDAVController());
    controller.notLogin.value = false;
    controller.user.value = 'tester@example.com';

    await tester.pumpWidget(
      const GetMaterialApp(
        home: RemoteSyncWebDAVPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, '同步选项'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '同步选项'));
    await tester.pumpAndSettle();

    final tileFinder = find.widgetWithText(CheckboxListTile, '同步自定义分区');
    expect(tileFinder, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(tileFinder).value, isTrue);

    await tester.tap(tileFinder);
    await tester.pumpAndSettle();
    expect(controller.isSyncCustomCategories.value, isFalse);
    expect(tester.widget<CheckboxListTile>(tileFinder).value, isFalse);
  });
}
