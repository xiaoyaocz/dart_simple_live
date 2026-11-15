import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';

void main() {
  test("旧键只投影旧版本认识的底栏入口", () {
    final value = ["recommend", "follow", "iptv", "category", "user"];
    expect(
      AppSettingsController.projectLegacyKeys(
        value,
        Constant.legacyHomeSortKeys,
      ),
      ["recommend", "follow", "category", "user"],
    );
  });

  test("归一化会过滤未知 key 并补全当前版本缺失项", () {
    final keys = Constant.allHomePages.keys.toList();
    final result = AppSettingsController.normalizeSortKeys(
      ["iptv", "future_tab", "recommend"],
      keys,
    );
    expect(result.contains("future_tab"), isFalse);
    expect(result.first, "iptv");
    expect(result.length, keys.length);
    expect(result.toSet().length, keys.length);
  });

  test("平台旧键不会写入旧版本不认识的平台", () {
    final value = [...Sites.allSites.keys, "future_site"];
    final legacy = AppSettingsController.projectLegacyKeys(
      value,
      Sites.legacySiteIds,
    );
    expect(legacy.length, Sites.legacySiteIds.length);
    expect(legacy.every(Sites.legacySiteIds.contains), isTrue);
  });

  test("V2 缺失时回退旧键并补全", () {
    final keys = Constant.allHomePages.keys.toList();
    final result = AppSettingsController.resolveSortKeys(
      v2Raw: "",
      legacyRaw: "user,recommend",
      keys: keys,
      legacyKeys: Constant.legacyHomeSortKeys,
    );
    expect(result.take(2), ["user", "recommend"]);
    expect(result.length, keys.length);
  });

  test("旧键与 V2 投影一致时 V2 优先", () {
    final keys = Constant.allHomePages.keys.toList();
    final result = AppSettingsController.resolveSortKeys(
      v2Raw: "iptv,recommend,follow,category,user",
      legacyRaw: "recommend,follow,category,user",
      keys: keys,
      legacyKeys: Constant.legacyHomeSortKeys,
    );
    expect(result.first, "iptv");
    expect(result.length, keys.length);
  });

  test("旧键被旧版本改写时旧键优先（最后写入者生效）", () {
    final keys = Constant.allHomePages.keys.toList();
    final result = AppSettingsController.resolveSortKeys(
      // V2 仍是新版本降级前的顺序
      v2Raw: "iptv,recommend,follow,category,user",
      // 用户降级后在 1.13.x 里把“我的”拖到了首位
      legacyRaw: "user,recommend,follow,category",
      keys: keys,
      legacyKeys: Constant.legacyHomeSortKeys,
    );
    expect(result.take(2), ["user", "recommend"]);
    expect(result.length, keys.length);
    expect(result.contains("iptv"), isTrue);
  });

  test("旧键为空时以 V2 为准", () {
    final keys = Constant.allHomePages.keys.toList();
    final result = AppSettingsController.resolveSortKeys(
      v2Raw: "iptv,recommend,follow,category,user",
      legacyRaw: "",
      keys: keys,
      legacyKeys: Constant.legacyHomeSortKeys,
    );
    expect(result.first, "iptv");
    expect(result.length, keys.length);
  });

  test("平台全部被隐藏时仅恢复排序首位平台", () {
    final sorted = Sites.allSites.keys.toList();
    final repaired = AppSettingsController.clampAllHiddenSites(
      sorted.toSet(),
      sorted,
    );
    expect(repaired.contains(sorted.first), isFalse);
    expect(repaired.length, sorted.length - 1);
  });

  test("保留至少一个平台的正常隐藏配置不被改动", () {
    final sorted = Sites.allSites.keys.toList();
    final hidden = sorted.toSet()..remove(sorted.first);
    final repaired = AppSettingsController.clampAllHiddenSites(
      hidden,
      sorted,
    );
    expect(repaired, hidden);
  });
}
