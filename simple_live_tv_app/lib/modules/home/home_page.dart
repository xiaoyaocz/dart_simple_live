import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';
import 'package:simple_live_tv_app/widgets/button/home_big_button.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';
import 'package:simple_live_tv_app/widgets/status/app_empty_widget.dart';

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
                onTap: () {
                  controller.toSettings();
                },
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
                          onTap: controller.toHotLive,
                        ),
                      ),
                      AppStyle.hGap48,
                      Expanded(
                        child: HomeBigButton(
                          autofocus: true,
                          focusNode: AppFocusNode(),
                          text: "直播类目",
                          iconData: Remix.apps_line,
                          onTap: controller.toCategory,
                        ),
                      ),
                      AppStyle.hGap48,
                      Expanded(
                        child: HomeBigButton(
                          autofocus: true,
                          focusNode: AppFocusNode(),
                          text: "搜索直播",
                          iconData: Remix.search_2_line,
                          onTap: showSearchDialog,
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
                          onTap: controller.toHistory,
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
                            Icons.favorite_border,
                            color: Colors.white,
                            size: 56.w,
                          ),
                        ),
                      ),
                      AppStyle.hGap24,
                      Expanded(
                        child: Text(
                          "我的关注",
                          style: AppStyle.titleStyleWhite,
                        ),
                      ),
                      Obx(
                        () => Visibility(
                          visible: FollowUserService.instance.updating.value,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 48.w,
                                height: 48.w,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 4.w,
                                ),
                              ),
                              AppStyle.hGap16,
                              Text(
                                "更新状态中...",
                                style: AppStyle.textStyleWhite,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppStyle.hGap16,
                      HighlightButton(
                        focusNode: AppFocusNode(),
                        iconData: Icons.settings,
                        text: "管理",
                        onTap: showManageDialog,
                      ),
                      AppStyle.hGap32,
                      HighlightButton(
                        focusNode: AppFocusNode(),
                        iconData: Icons.refresh,
                        text: "刷新",
                        onTap: () {
                          FollowUserService.instance.refreshData();
                        },
                      ),
                    ],
                  ),
                ),
                AppStyle.vGap32,
                Obx(
                  () => MasonryGridView.count(
                    padding: AppStyle.edgeInsetsH48,
                    itemCount: FollowUserService.instance.list.length,
                    crossAxisCount: 3,
                    crossAxisSpacing: 48.w,
                    mainAxisSpacing: 48.w,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, i) {
                      var item = FollowUserService.instance.list[i];
                      return Obx(
                        () => AnchorCard(
                          face: item.face,
                          name: item.userName,
                          siteId: item.siteId,
                          liveStatus: item.liveStatus.value,
                          roomId: item.roomId,
                        ),
                      );
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: FollowUserService.instance.list.isEmpty,
                    child: Column(
                      children: [
                        AppStyle.vGap24,
                        LottieBuilder.asset(
                          'assets/lotties/empty.json',
                          width: 160.w,
                          height: 160.w,
                          repeat: false,
                        ),
                        AppStyle.vGap24,
                        Text(
                          "暂无任何关注\n您可以从其他端同步数据到此处",
                          textAlign: TextAlign.center,
                          style: AppStyle.textStyleWhite,
                        ),
                        AppStyle.vGap16,
                        HighlightButton(
                          focusNode: AppFocusNode(),
                          iconData: Icons.devices,
                          text: "同步数据",
                          onTap: () {
                            controller.toSync();
                          },
                        ),
                      ],
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

  void showManageDialog() {
    Utils.showSystemRightDialog(
      //useSystem: true,
      width: 700.w,
      child: Column(
        children: [
          AppStyle.vGap24,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                onTap: () {
                  //Utils.hideRightDialog();
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "关注管理",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                Obx(
                  () => ListView.separated(
                    itemCount: FollowUserService.instance.list.length,
                    separatorBuilder: (_, __) => AppStyle.vGap24,
                    padding: AppStyle.edgeInsetsA40,
                    itemBuilder: (_, i) {
                      var item = FollowUserService.instance.list[i];
                      var foucsNode = AppFocusNode();
                      return HighlightListTile(
                        autofocus: i == 0,
                        leading: NetImage(
                          item.face,
                          width: 64.w,
                          height: 64.w,
                          borderRadius: 64.w,
                        ),
                        title: item.userName,
                        focusNode: foucsNode,
                        trailing: Obx(
                          () => Icon(
                            Icons.delete_outline_outlined,
                            size: 40.w,
                            color: foucsNode.isFoucsed.value
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                        onTap: () {
                          FollowUserService.instance
                              .removeItem(item, refresh: false);
                        },
                      );
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: FollowUserService.instance.list.isEmpty,
                    child: const AppEmptyWidget(
                      text: "关注列表为空，快去关注一些主播吧",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showSearchDialog() {
    var textController = TextEditingController();
    var mode = 0.obs;
    var roomFocusNode = AppFocusNode()..isFoucsed.value = true;
    var anchorFocusNode = AppFocusNode();
    showDialog(
      context: Get.context!,
      builder: (_) => AlertDialog(
        backgroundColor: Get.theme.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppStyle.radius16,
        ),
        contentPadding: AppStyle.edgeInsetsA48,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Obx(
                  () => HighlightButton(
                    text: "直播间",
                    iconData: Icons.live_tv,
                    selected: mode.value == 0,
                    focusNode: roomFocusNode,
                    autofocus: roomFocusNode.isFoucsed.value,
                    onTap: () {
                      mode.value = 0;
                    },
                  ),
                ),
                AppStyle.hGap40,
                Obx(
                  () => HighlightButton(
                    text: "主播",
                    selected: mode.value == 1,
                    iconData: Icons.person,
                    focusNode: anchorFocusNode,
                    autofocus: anchorFocusNode.isFoucsed.value,
                    onTap: () {
                      mode.value = 1;
                    },
                  ),
                ),
              ],
            ),
            AppStyle.vGap48,
            SizedBox(
              width: 700.w,
              child: TextField(
                controller: textController,
                style: AppStyle.textStyleWhite,
                textInputAction: TextInputAction.search,
                onSubmitted: (e) {
                  Get.back();
                  if (e.isEmpty) {
                    return;
                  }
                  if (mode.value == 0) {
                    controller.toSearchRoom(textController.text);
                  } else {
                    controller.toSearchAnchor(textController.text);
                  }
                },
                decoration: InputDecoration(
                  hintText: mode.value == 0 ? "点击输入关键字搜索" : "点击主播昵称搜索",
                  hintStyle: AppStyle.textStyleWhite,
                  border: OutlineInputBorder(
                    borderRadius: AppStyle.radius16,
                    borderSide: BorderSide(width: 4.w),
                  ),
                  filled: true,
                  isDense: true,
                  fillColor: Get.theme.primaryColor,
                  contentPadding: AppStyle.edgeInsetsA32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
