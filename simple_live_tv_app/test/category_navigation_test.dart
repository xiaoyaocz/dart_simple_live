import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/category/category_controller.dart';
import 'package:simple_live_tv_app/modules/category/detail/category_detail_controller.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/routes/app_pages.dart';

void main() {
  test('TV category wrapper preserves nested child categories', () {
    final category = LiveCategory(
      id: 'games',
      name: '游戏',
      children: [
        LiveSubCategory(
          id: 'shooting',
          name: '射击游戏',
          parentId: 'games',
          children: [
            LiveSubCategory(
              id: 'valorant',
              name: '无畏契约',
              parentId: 'shooting',
            ),
          ],
        ),
      ],
    );
    final site = Site(
      id: 'douyin',
      name: '抖音直播',
      logo: '',
      index: 0,
      liveSite: LiveSite(),
    );

    final wrapped = AppLiveCategory.fromLiveCategory(category, site);
    final shooting = wrapped.childrenExt.single;

    expect(shooting.hasChildren, isTrue);
    expect(shooting.childrenExt.single.name, '无畏契约');
    expect(shooting.children.single.name, '无畏契约');

    final controller = CategoryDetailController(
      site: site,
      subCategory: shooting,
    );
    controller.onInit();
    expect(controller.currentPage, 1);
    expect(controller.loadding.value, isFalse);
    controller.onClose();
  });

  testWidgets('TV nested category routes keep each level controller', (
    tester,
  ) async {
    Get.testMode = true;
    final category = LiveSubCategoryExt(
      id: 'games',
      name: '游戏',
      parentId: 'root',
      site: Site(
        id: 'douyin',
        name: '抖音直播',
        logo: '',
        index: 0,
        liveSite: LiveSite(),
      ),
      children: [],
    );
    final site = category.site;
    final shooting = LiveSubCategoryExt(
      id: 'shooting',
      name: '射击游戏',
      parentId: category.id,
      site: site,
      children: [
        LiveSubCategoryExt(
          id: 'valorant',
          name: '无畏契约',
          parentId: 'shooting',
          site: site,
        ),
      ],
    );
    final root = LiveSubCategoryExt(
      id: category.id,
      name: category.name,
      parentId: category.parentId,
      site: site,
      children: [shooting],
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, child) => GetMaterialApp(
          home: const Scaffold(body: SizedBox.shrink()),
          getPages: AppPages.routes,
        ),
      ),
    );

    AppNavigator.toCategoryDetail(site: site, category: root);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('游戏'), findsOneWidget);

    await tester.tap(find.text('射击游戏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('射击游戏'), findsOneWidget);
    expect(find.text('无畏契约'), findsOneWidget);

    await tester.tap(find.text('无畏契约'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('无畏契约'), findsOneWidget);

    Get.reset();
  });
}
