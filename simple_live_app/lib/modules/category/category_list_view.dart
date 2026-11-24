import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/modules/category/custom_category_dialogs.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/default_category_icon.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/shadow_card.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:sticky_headers/sticky_headers.dart';

class CategoryListView extends StatelessWidget {
  final String tag;
  const CategoryListView(this.tag, {Key? key}) : super(key: key);
  CategoryListController get controller =>
      Get.find<CategoryListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Obx(
        () => EasyRefresh(
          firstRefresh: true,
          controller: controller.easyRefreshController,
          onRefresh: controller.refreshData,
          header: MaterialHeader(
            completeDuration: const Duration(milliseconds: 400),
          ),
          child: ListView.builder(
            padding: AppStyle.edgeInsetsA12,
            itemCount: controller.list.length,
            controller: controller.scrollController,
            itemBuilder: (_, i) {
              var item = controller.list[i];
              final isCustomGroup =
                  item.id == CategoryListController.kCustomGroupId;
              return Column(
                children: [
                  StickyHeader(
                    header: Container(
                      padding: AppStyle.edgeInsetsV8.copyWith(left: 4),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (isCustomGroup) ...[
                            AppStyle.hGap8,
                            Text(
                              '长按或右键可编辑',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () =>
                                  CustomCategoryDialogs.showAddOrEditDialog(
                                initialSiteId: controller.site.id,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('新增'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () =>
                                  CustomCategoryDialogs.showManageSheet(
                                initialSiteId: controller.site.id,
                              ),
                              child: const Text('管理'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    content: Obx(
                      () => GridView.count(
                        shrinkWrap: true,
                        padding: AppStyle.edgeInsetsV8,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount:
                            (MediaQuery.of(context).size.width ~/ 80)
                                .clamp(1, 12)
                                .toInt(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: item.showAll.value
                            ? (item.children
                                .map(
                                  (e) => buildSubCategory(
                                    context,
                                    e,
                                    isCustom: isCustomGroup,
                                  ),
                                )
                                .toList())
                            : (item.take15
                                .map(
                                  (e) => buildSubCategory(
                                    context,
                                    e,
                                    isCustom: isCustomGroup,
                                  ),
                                )
                                .toList()
                              ..add(buildShowMore(item))),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildSubCategory(
    BuildContext context,
    LiveSubCategory item, {
    bool isCustom = false,
  }) {
    final pic = (item.pic ?? "").trim();
    final isLocalAsset = pic.startsWith('asset://');
    final cacheWidth = (40 * MediaQuery.of(context).devicePixelRatio).ceil();
    void openCategory() {
      AppNavigator.toCategoryDetail(site: controller.site, category: item);
    }

    void openCustomMenu() {
      CustomCategoryDialogs.showCardActionMenu(
        siteId: controller.site.id,
        category: item,
        onOpen: openCategory,
      );
    }

    final fallbackIcon = DefaultCategoryIcon(
      categoryName: item.name,
      siteId: isCustom ? controller.site.id : null,
    );

    final card = ShadowCard(
      onTap: openCategory,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pic.isNotEmpty
                      ? NetImage(
                          pic,
                          width: 40,
                          height: 40,
                          borderRadius: 8,
                          fit: isLocalAsset ? BoxFit.contain : BoxFit.cover,
                          cacheWidth: cacheWidth,
                          fallbackWidget: fallbackIcon,
                        )
                      : fallbackIcon,
                  AppStyle.vGap4,
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (isCustom)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.push_pin_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.primary.withAlpha(180),
              ),
            ),
        ],
      ),
    );

    return Tooltip(
      message: isCustom ? '${item.name}（长按/右键管理）' : item.name,
      waitDuration: const Duration(milliseconds: 300),
      child: isCustom
          ? GestureDetector(
              onLongPress: openCustomMenu,
              onSecondaryTap: openCustomMenu,
              child: card,
            )
          : card,
    );
  }

  Widget buildShowMore(AppLiveCategory item) {
    return ShadowCard(
      onTap: () {
        item.showAll.value = true;
      },
      child: const Center(
        child: Text(
          "显示全部",
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
