import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
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
              return Column(
                children: [
                  StickyHeader(
                    header: Container(
                      padding: AppStyle.edgeInsetsV8.copyWith(left: 4),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
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
                                  (e) => buildSubCategory(context, e),
                                )
                                .toList())
                            : (item.take15
                                .map(
                                  (e) => buildSubCategory(context, e),
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

  Widget buildSubCategory(BuildContext context, LiveSubCategory item) {
    final pic = (item.pic ?? "").trim();
    final isLocalGameArtwork = DouyinGameArtwork.isLocalGameArtwork(pic);
    final cacheWidth = (40 * MediaQuery.of(context).devicePixelRatio).ceil();
    return Tooltip(
      message: item.name,
      waitDuration: const Duration(milliseconds: 300),
      child: ShadowCard(
        onTap: () {
          AppNavigator.toCategoryDetail(site: controller.site, category: item);
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
        border: Border.all(
          color: color.withAlpha(40),
        ),
        color: color.withAlpha(18),
      ),
      child: Icon(
        icon,
        size: 22,
        color: color,
      ),
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
