import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
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
      appBar: AppBar(title: Text(controller.subCategory.name)),
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
    final isLocalGameArtwork = DouyinGameArtwork.isLocalGameArtwork(pic);
    final cacheWidth = (40 * MediaQuery.of(context).devicePixelRatio).ceil();
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
                    fit: isLocalGameArtwork ? BoxFit.contain : BoxFit.cover,
                    cacheWidth: cacheWidth,
                  )
                : _buildFallbackCategoryIcon(context, item),
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

  Widget _buildFallbackCategoryIcon(
    BuildContext context,
    LiveSubCategory item,
  ) {
    final icon = controller.site.id == Constant.kDouyin
        ? _douyinCategoryIcon(item.name)
        : Icons.dashboard_customize_rounded;
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
        color: color.withAlpha(18),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  IconData _douyinCategoryIcon(String name) {
    if (name.contains("游戏") || name.contains("电竞") || name.contains("手游")) {
      return Icons.sports_esports_rounded;
    }
    if (name.contains("唱") || name.contains("音乐") || name.contains("电台")) {
      return Icons.music_note_rounded;
    }
    if (name.contains("舞") || name.contains("颜值") || name.contains("才艺")) {
      return Icons.auto_awesome_rounded;
    }
    if (name.contains("聊天") || name.contains("交友") || name.contains("情感")) {
      return Icons.forum_rounded;
    }
    if (name.contains("美食") || name.contains("吃")) {
      return Icons.restaurant_rounded;
    }
    if (name.contains("户外") || name.contains("旅行") || name.contains("生活")) {
      return Icons.park_rounded;
    }
    if (name.contains("体育") || name.contains("健身")) {
      return Icons.sports_basketball_rounded;
    }
    if (name.contains("汽车") || name.contains("车")) {
      return Icons.directions_car_rounded;
    }
    if (name.contains("知识") || name.contains("教育") || name.contains("课堂")) {
      return Icons.school_rounded;
    }
    if (name.contains("二次元") || name.contains("动漫")) {
      return Icons.face_retouching_natural_rounded;
    }
    if (name.contains("财经") || name.contains("股票")) {
      return Icons.trending_up_rounded;
    }
    if (name.contains("科技") || name.contains("数码")) {
      return Icons.memory_rounded;
    }
    if (name.contains("影视") || name.contains("电影") || name.contains("综艺")) {
      return Icons.movie_rounded;
    }
    if (name.contains("购物") || name.contains("电商")) {
      return Icons.shopping_bag_rounded;
    }
    if (name.contains("宠物")) {
      return Icons.pets_rounded;
    }
    return Icons.grid_view_rounded;
  }
}
