import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/models/custom_category_item.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/custom_category_service.dart';
import 'package:simple_live_app/widgets/default_category_icon.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/live_room_grid_layout.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_app/widgets/shadow_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryDetailPage extends GetView<CategoryDetailController> {
  final String? _controllerTag;

  @override
  String? get tag => _controllerTag;

  const CategoryDetailPage({Key? key, String? tag})
      : _controllerTag = tag,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.subCategory.name),
        actions: [
          if (!controller.subCategory.hasChildren &&
              Get.isRegistered<CustomCategoryService>())
            Obx(() {
              final service = CustomCategoryService.instance;
              service.revision.value;
              final pinned = service.contains(
                controller.site.id,
                controller.subCategory.id,
              );
              return IconButton(
                tooltip: pinned ? '取消固定自定义分区' : '添加到自定义分区',
                onPressed: () async {
                  final nowPinned = await service.togglePin(
                    CustomCategoryItem.normalized(
                      siteId: controller.site.id,
                      id: controller.subCategory.id,
                      parentId: controller.subCategory.parentId,
                      name: controller.subCategory.name,
                      pic: controller.subCategory.pic,
                    ),
                  );
                  SmartDialog.showToast(
                    nowPinned
                        ? '已添加到自定义分区：${controller.subCategory.name}'
                        : '已取消固定：${controller.subCategory.name}',
                  );
                },
                icon: Icon(
                  pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
              );
            }),
        ],
      ),
      body: controller.subCategory.hasChildren
          ? _buildSubCategoryGrid(context)
          : KeepAliveWrapper(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = LiveRoomGridLayout.resolve(
                    constraints.maxWidth,
                    detailsExtent: LiveRoomCard.detailsExtent,
                  );
                  return PageGridView(
                    pageController: controller,
                    padding: AppStyle.edgeInsetsA12,
                    firstRefresh: true,
                    mainAxisSpacing: LiveRoomGridLayout.defaultSpacing,
                    crossAxisSpacing: LiveRoomGridLayout.defaultSpacing,
                    mainAxisExtent: layout.mainAxisExtent,
                    useFixedGrid: true,
                    crossAxisCount: layout.crossAxisCount,
                    itemBuilder: (_, i) {
                      var item = controller.list[i];
                      return LiveRoomCard(
                        controller.site,
                        item,
                        onTap: controller.onRoomSelected == null
                            ? null
                            : () {
                                final onRoomSelected =
                                    controller.onRoomSelected!;
                                Get.until(
                                  (route) =>
                                      route.settings.name !=
                                      RoutePath.kCategoryDetail,
                                );
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  onRoomSelected(controller.site, item.roomId);
                                });
                              },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSubCategoryGrid(BuildContext context) {
    return GridView.count(
      padding: AppStyle.edgeInsetsA12,
      crossAxisCount:
          (MediaQuery.of(context).size.width ~/ 80).clamp(1, 12).toInt(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: controller.subCategory.children
          .map((item) => _buildSubCategory(context, item))
          .toList(),
    );
  }

  Widget _buildSubCategory(BuildContext context, LiveSubCategory item) {
    final pic = (item.pic ?? "").trim();
    final isLocalAsset = pic.startsWith('asset://');
    final cacheWidth = (40 * MediaQuery.of(context).devicePixelRatio).ceil();
    final fallbackIcon = DefaultCategoryIcon(categoryName: item.name);
    return Tooltip(
      message: item.name,
      waitDuration: const Duration(milliseconds: 300),
      child: ShadowCard(
        onTap: () {
          AppNavigator.toCategoryDetail(
            site: controller.site,
            category: item,
            onRoomSelected: controller.onRoomSelected,
            excludedRoomId: controller.excludedRoomId,
          );
        },
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
    );
  }
}
