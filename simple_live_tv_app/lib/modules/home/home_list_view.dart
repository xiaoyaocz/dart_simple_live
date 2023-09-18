import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';
import 'package:marquee/marquee.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/home/home_list_controller.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
import 'package:simple_live_tv_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';
import 'package:simple_live_tv_app/widgets/page_grid_view.dart';

class HomeListView extends StatelessWidget {
  final String tag;
  const HomeListView(this.tag, {Key? key}) : super(key: key);
  HomeListController get controller => Get.find<HomeListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: PageGridView(
        pageController: controller,
        padding: AppStyle.edgeInsetsA32,
        firstRefresh: true,
        mainAxisSpacing: 36.w,
        crossAxisSpacing: 36.w,
        crossAxisCount: 5,
        itemBuilder: (_, i) {
          var item = controller.list[i];
          return HighlightWidget(
            focusNode: item.focusNode,
            color: Colors.white10,
            onTap: () {},
            borderRadius: AppStyle.radius16,
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.w),
                      topRight: Radius.circular(16.w),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: NetImage(
                        item.cover,
                      ),
                    ),
                    // child: Container(
                    //   height: 200.w,
                    // ),
                  ),
                  AppStyle.vGap8,
                  Padding(
                    padding: AppStyle.edgeInsetsH20,
                    child: SizedBox(
                      height: 56.w,
                      child: item.focusNode.isFoucsed.value
                          ? Marquee(
                              text: item.title,
                              style: AppStyle.textStyleBlack,
                              startAfter: const Duration(seconds: 2),
                              velocity: 20,
                              blankSpace: 50.w,
                              //decelerationDuration: const Duration(seconds: 2),
                              scrollAxis: Axis.horizontal,
                            )
                          : Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.title,
                                style: AppStyle.textStyleWhite,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppStyle.hGap20,
                      Icon(
                        Icons.account_circle,
                        color: item.focusNode.isFoucsed.value
                            ? Colors.black54
                            : Colors.white54,
                        size: 32.w,
                      ),
                      AppStyle.hGap12,
                      Text(
                        item.userName,
                        style: item.focusNode.isFoucsed.value
                            ? AppStyle.subTextStyleBlack
                            : AppStyle.subTextStyleWhite,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  AppStyle.vGap12,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
