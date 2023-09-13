import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/user/indexed_settings/indexed_settings_controller.dart';

class IndexedSettingsPage extends GetView<IndexedSettingsController> {
  const IndexedSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("主页设置"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(
              "主页排序",
              style: Get.textTheme.titleSmall,
            ),
            visualDensity: VisualDensity.compact,
            subtitle: const Text("拖动进行排序，重启APP后生效"),
          ),
          Obx(
            () => ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: controller.updateHomeSort,
              children: controller.homeSort.map(
                (key) {
                  var e = Constant.allHomePages[key]!;
                  return ListTile(
                    key: ValueKey(e.title),
                    title: Text(e.title),
                    visualDensity: VisualDensity.compact,
                    leading: Icon(e.iconData),
                    trailing: const Icon(Icons.drag_handle),
                  );
                },
              ).toList(),
            ),
          ),
          ListTile(
            title: Text(
              "平台排序",
              style: Get.textTheme.titleSmall,
            ),
            visualDensity: VisualDensity.compact,
            subtitle: const Text("拖动进行排序，重启APP后生效"),
          ),
          Obx(
            () => ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: controller.updateSiteSort,
              children: controller.siteSort.map(
                (key) {
                  var e = Sites.allSites[key]!;
                  return ListTile(
                    key: ValueKey(e.id),
                    visualDensity: VisualDensity.compact,
                    title: Text(e.name),
                    leading: Image.asset(
                      e.logo,
                      width: 24,
                      height: 24,
                    ),
                    trailing: const Icon(Icons.drag_handle),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
