import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';
import 'package:simple_live_tv_app/widgets/button/home_big_button.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

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
              Text(
                "Simple Live TV",
                style: AppStyle.titleStyleWhite,
              ),
              AppStyle.hGap24,
              const Spacer(),
              Obx(
                () => Text(
                  controller.datetime.value,
                  style: AppStyle.titleStyleWhite.copyWith(fontSize: 36.w),
                ),
              ),
              AppStyle.hGap32,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.settings,
                text: "设置",
                onTap: () {},
              ),
              AppStyle.hGap48,
            ],
          ),
          Expanded(
            child: ListView(
              padding: AppStyle.edgeInsetsV32,
              children: [
                Padding(
                  padding: AppStyle.edgeInsetsH48,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: HomeBigButton(
                          autofocus: true,
                          focusNode: AppFocusNode(),
                          text: "热门直播",
                          iconData: Remix.fire_line,
                        ),
                      ),
                      AppStyle.hGap48,
                      Expanded(
                        child: HomeBigButton(
                          autofocus: true,
                          focusNode: AppFocusNode(),
                          text: "直播类目",
                          iconData: Remix.apps_line,
                        ),
                      ),
                      AppStyle.hGap48,
                      Expanded(
                        child: HomeBigButton(
                          autofocus: true,
                          focusNode: AppFocusNode(),
                          text: "搜索直播",
                          iconData: Remix.search_2_line,
                        ),
                      ),
                      // AppStyle.hGap40,
                      // Expanded(
                      //   child: HomeBigButton(
                      //     focusNode: AppFocusNode(),
                      //     text: "我的关注",
                      //     iconData: Icons.favorite_border,
                      //     onTap: controller.toFollow,
                      //   ),
                      // ),
                      AppStyle.hGap48,
                      Expanded(
                        child: HomeBigButton(
                          focusNode: AppFocusNode(),
                          text: "观看记录",
                          iconData: Icons.history,
                        ),
                      ),
                      AppStyle.hGap48,
                      Expanded(
                        child: HomeBigButton(
                          focusNode: AppFocusNode(),
                          text: "数据同步",
                          iconData: Icons.devices,
                          onTap: controller.toSync,
                        ),
                      ),
                    ],
                  ),
                ),
                AppStyle.vGap32,
                Padding(
                  padding: AppStyle.edgeInsetsH48,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 64.w,
                        height: 64.w,
                        child: Center(
                          child: Icon(
                            Icons.live_tv,
                            color: Colors.white,
                            size: 40.w,
                          ),
                        ),
                      ),
                      AppStyle.hGap16,
                      Expanded(
                        child: Text(
                          "我的关注",
                          style: AppStyle.titleStyleWhite,
                        ),
                      ),
                      HighlightButton(
                        focusNode: AppFocusNode(),
                        iconData: Icons.refresh,
                        text: "刷新",
                        onTap: () {
                          FollowUserService.instance.refreshData();

                          SmartDialog.showToast("正在刷新...");
                        },
                      ),
                    ],
                  ),
                ),
                AppStyle.vGap32,
                Obx(
                  () => MasonryGridView.count(
                    padding: AppStyle.edgeInsetsH48,
                    itemCount: FollowUserService.instance.allList.length,
                    crossAxisCount: 3,
                    crossAxisSpacing: 48.w,
                    mainAxisSpacing: 48.w,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, i) {
                      var item = FollowUserService.instance.allList[i];
                      return AnchorCard(
                        face: item.face,
                        name: item.userName,
                        siteId: item.siteId,
                        liveStatus: item.liveStatus.value,
                        roomId: item.roomId,
                      );
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: FollowUserService.instance.allList.isEmpty,
                    child: Text(
                      "暂无任何关注",
                      textAlign: TextAlign.center,
                      style: AppStyle.textStyleWhite,
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
