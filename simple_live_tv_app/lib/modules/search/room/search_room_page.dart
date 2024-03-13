import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/search/room/search_room_controller.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/live_room_card.dart';
import 'package:simple_live_tv_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_tv_app/widgets/status/app_error_widget.dart';

class SearchRoomPage extends GetView<SearchRoomController> {
  const SearchRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                //autofocus: true,
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "搜索：${controller.keyword}",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
              Obx(
                () => Visibility(
                  visible: controller.loadding.value,
                  child: SizedBox(
                    width: 48.w,
                    height: 48.w,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4.w,
                    ),
                  ),
                ),
              ),
              AppStyle.hGap24,
              // HighlightButton(
              //   focusNode: AppFocusNode(),
              //   iconData: Icons.refresh,
              //   text: "刷新",
              //   onTap: () {
              //     controller.refreshData();
              //   },
              // ),
              AppStyle.hGap48,
            ],
          ),
          AppStyle.vGap24,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 36.w,
            children: Sites.supportSites
                .map(
                  (e) => Obx(
                    () => HighlightButton(
                      icon: Image.asset(
                        e.logo,
                        width: 48.w,
                        height: 48.w,
                      ),
                      text: e.name,
                      selected: controller.siteId.value == e.id,
                      focusNode: AppFocusNode(),
                      onTap: () {
                        controller.setSite(e.id);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
          AppStyle.vGap24,
          Expanded(
            child: Obx(
              () => Stack(
                children: [
                  MasonryGridView.count(
                    padding: AppStyle.edgeInsetsA48,
                    itemCount: controller.list.length,
                    crossAxisCount: 5,
                    crossAxisSpacing: 48.w,
                    mainAxisSpacing: 40.w,
                    controller: controller.scrollController,
                    itemBuilder: (_, i) {
                      var item = controller.list[i];

                      if (i == 0) {
                        Future.delayed(Duration.zero, () {
                          if (controller.currentPage == 2) {
                            item.focusNode.requestFocus();
                          }
                        });
                      }
                      return LiveRoomCard(
                        cover: item.cover,
                        anchor: item.userName,
                        title: item.title,
                        focusNode: item.focusNode,
                        roomId: item.roomId,
                        online: item.online,
                        onTap: () {
                          AppNavigator.toLiveRoomDetail(
                            site: controller.site,
                            roomId: item.roomId,
                          );
                        },
                      );
                    },
                  ),
                  Obx(
                    () => Visibility(
                      visible: controller.list.isEmpty &&
                          !controller.loadding.value &&
                          !controller.pageError.value,
                      child: AppEmptyWidget(
                        onRefresh: () {
                          controller.refreshData();
                        },
                      ),
                    ),
                  ),
                  Obx(
                    () => Visibility(
                      visible: controller.pageError.value &&
                          !controller.loadding.value,
                      child: AppErrorWidget(
                        errorMsg: controller.errorMsg.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
