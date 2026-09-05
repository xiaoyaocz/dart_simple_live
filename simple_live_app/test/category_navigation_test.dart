import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_controller.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_page.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  testWidgets('parent category renders its children before any room grid', (
    tester,
  ) async {
    Get.testMode = true;
    final category = LiveSubCategory(
      id: 'games',
      name: '游戏',
      parentId: 'root',
      children: [
        LiveSubCategory(
          id: 'shooting',
          name: '射击游戏',
          parentId: 'games',
          children: [
            LiveSubCategory(id: 'valorant', name: '无畏契约', parentId: 'shooting'),
          ],
        ),
      ],
    );
    final site = Site(
      id: 'douyin',
      name: '抖音直播',
      logo: '',
      liveSite: LiveSite(),
    );
    Get.put(CategoryDetailController(site: site, subCategory: category));

    await tester.pumpWidget(const GetMaterialApp(home: CategoryDetailPage()));

    expect(find.text('射击游戏'), findsOneWidget);
    expect(find.byType(PageGridView), findsNothing);

    Get.reset();
  });

  testWidgets('nested category routes keep each level controller', (
    tester,
  ) async {
    Get.testMode = true;
    final category = LiveSubCategory(
      id: 'games',
      name: '游戏',
      parentId: 'root',
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
      liveSite: LiveSite(),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: SizedBox.shrink()),
        getPages: AppPages.routes,
      ),
    );

    AppNavigator.toCategoryDetail(site: site, category: category);
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
    expect(find.byType(PageGridView), findsOneWidget);

    Get.reset();
  });
}
