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
}
