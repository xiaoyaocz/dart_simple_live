import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/modules/home/home_list_view.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppStyle.vGap24,
        Padding(
          padding: AppStyle.edgeInsetsH48,
          child: Wrap(
            spacing: 48.w,
            children: Sites.supportSites
                .map(
                  (e) => Obx(
                    () => HighlightWidget(
                      focusNode: e.appFocusNode,
                      borderRadius: BorderRadius.circular(32.w),
                      onTap: () {
                        controller.tabController.animateTo(e.index);
                      },
                      // onFocusChange: (state) {
                      //   if (state) {
                      //     controller.currentIndex.value = e.index;
                      //   }
                      // },
                      child: Container(
                        decoration: BoxDecoration(
                          color: e.appFocusNode.isFoucsed.value ||
                                  e.index == controller.tabIndex.value
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(32.w),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 12.w,
                          horizontal: 24.w,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              e.logo,
                              width: 40.w,
                              height: 40.w,
                            ),
                            AppStyle.hGap12,
                            Text(
                              e.name,
                              style: AppStyle.titleStyleWhite.copyWith(
                                fontSize: 32.w,
                                color: e.appFocusNode.isFoucsed.value ||
                                        e.index == controller.tabIndex.value
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller.tabController,
            children: Sites.supportSites
                .map(
                  (e) => HomeListView(
                    e.id,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
