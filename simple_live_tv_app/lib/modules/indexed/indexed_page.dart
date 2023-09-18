import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/indexed/indexed_controller.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap24,
          FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              children: [
                AppStyle.hGap48,
                Text(
                  "Simple Live TV",
                  style: AppStyle.titleStyleWhite.copyWith(
                    fontSize: 36.w,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppStyle.hGap24,
                const Expanded(child: Center()),
                Text(
                  "11:11",
                  style: AppStyle.titleStyleWhite.copyWith(fontSize: 32.w),
                ),
                AppStyle.hGap24,
                Obx(
                  () => HighlightWidget(
                    order: 1,
                    focusNode: controller.searchFocusNode,
                    borderRadius: AppStyle.radius32,
                    color: Colors.white10,
                    child: Container(
                      height: 64.w,
                      width: 64.w,
                      decoration: BoxDecoration(
                        borderRadius: AppStyle.radius32,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.search,
                          size: 40.w,
                          color: controller.searchFocusNode.isFoucsed.value
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                AppStyle.hGap24,
                Obx(
                  () => HighlightWidget(
                    order: 2,
                    focusNode: controller.settingsFocusNode,
                    borderRadius: AppStyle.radius32,
                    color: Colors.white10,
                    child: Container(
                      height: 64.w,
                      width: 64.w,
                      decoration: BoxDecoration(
                        borderRadius: AppStyle.radius32,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.settings,
                          size: 40.w,
                          color: controller.settingsFocusNode.isFoucsed.value
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                AppStyle.hGap48,
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsH48,
            child: Wrap(
              spacing: 48.w,
              children: controller.items
                  .map(
                    (e) => Obx(
                      () => HighlightWidget(
                        order: e.index.toDouble(),
                        focusNode: e.appFocusNode,
                        borderRadius: BorderRadius.circular(32.w),
                        onTap: () {
                          controller.currentIndex.value = e.index;
                        },

                        // onFocusChange: (state) {
                        //   if (state) {
                        //     controller.currentIndex.value = e.index;
                        //   }
                        // },
                        child: Container(
                          decoration: BoxDecoration(
                            color: e.appFocusNode.isFoucsed.value ||
                                    controller.currentIndex.value == e.index
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                e.iconData,
                                color: e.appFocusNode.isFoucsed.value ||
                                        e.index == controller.currentIndex.value
                                    ? Colors.black
                                    : Colors.white,
                                size: 32.w,
                              ),
                              AppStyle.hGap12,
                              Text(
                                e.name,
                                style: AppStyle.titleStyleWhite.copyWith(
                                  fontSize: 32.w,
                                  color: e.appFocusNode.isFoucsed.value ||
                                          e.index ==
                                              controller.currentIndex.value
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
            child: IndexedStack(
              index: controller.currentIndex.value,
              children: controller.pages,
            ),
          ),
        ],
      ),
    );
  }
}
