import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

class LiveRoomPage extends GetView<LiveRoomController> {
  const LiveRoomPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        if (controller.fullScreen.value) {
          return WillPopScope(
            onWillPop: () async {
              controller.exitFull();
              return false;
            },
            child: Scaffold(
              body: buildFullPlayer(context),
            ),
          );
        } else {
          return buildOrientationUI();
        }
      },
    );
  }

  Widget buildOrientationUI() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return Scaffold(
            appBar: AppBar(
              title: Obx(
                () => Text(controller.detail.value?.title ?? "直播间"),
              ),
              actions: buildAppbarActions(context),
            ),
            body: buildVerticalUI(context),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: Obx(
                () => Text(controller.detail.value?.title ?? "直播间"),
              ),
              actions: buildAppbarActions(context),
            ),
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => buildPlayer(isPortrait: false),
                        ),
                      ),
                      SizedBox(
                        width: 300,
                        child: Column(
                          children: [
                            buildUserProfile(context),
                            buildMessageArea(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(.1),
                      ),
                    ),
                  ),
                  padding: AppStyle.edgeInsetsV4.copyWith(
                    bottom: AppStyle.bottomBarHeight + 4,
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: controller.refreshRoom,
                        icon: const Icon(Remix.refresh_line),
                        label: const Text("刷新"),
                      ),
                      Obx(
                        () => controller.followed.value
                            ? TextButton.icon(
                                style: TextButton.styleFrom(
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                                onPressed: controller.removeFollowUser,
                                icon: const Icon(Remix.heart_fill),
                                label: const Text("取消关注"),
                              )
                            : TextButton.icon(
                                style: TextButton.styleFrom(
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                                onPressed: controller.followUser,
                                icon: const Icon(Remix.heart_line),
                                label: const Text("关注"),
                              ),
                      ),
                      const Expanded(child: Center()),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: controller.share,
                        icon: const Icon(Remix.share_line),
                        label: const Text("分享"),
                      ),
                    ],
                  ),
                ),
                //buildBottomActions(context),
              ],
            ),
          );
        }
      },
    );
  }

  Widget buildVerticalUI(BuildContext context) {
    return Column(
      children: [
        Obx(() => buildPlayer()),
        buildUserProfile(context),
        buildMessageArea(),
        buildBottomActions(context),
      ],
    );
  }

  Widget buildPlayer({bool isPortrait = true}) {
    if (!controller.liveStatus.value) {
      return Container(
        alignment: Alignment.center,
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Text(
              controller.errorMsg.value.isEmpty
                  ? "未开播"
                  : controller.errorMsg.value,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Container(
          alignment: Alignment.center,
          color: Colors.black,
          child: buildMediaPlayer(),
        ),
        Positioned.fill(
          child: Obx(
            () => Offstage(
              offstage: !controller.playerLoadding.value,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        buildDanmuView(),
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              controller.showControls.value = !controller.showControls.value;
            },
            onVerticalDragStart: controller.onVerticalDragStart,
            onVerticalDragUpdate: controller.onVerticalDragUpdate,
            onVerticalDragEnd: controller.onVerticalDragEnd,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),
        Obx(
          () => AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: controller.showControls.value ? 0 : -48,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black87,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      controller.refreshRoom();
                    },
                    icon: const Icon(
                      Remix.refresh_line,
                      color: Colors.white,
                    ),
                  ),
                  Offstage(
                    offstage: controller.enableDanmaku.value,
                    child: IconButton(
                      onPressed: () => controller.enableDanmaku.value =
                          !controller.enableDanmaku.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_open.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !controller.enableDanmaku.value,
                    child: IconButton(
                      onPressed: () => controller.enableDanmaku.value =
                          !controller.enableDanmaku.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_close.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.showBottomDanmuSettings();
                    },
                    icon: const ImageIcon(
                      AssetImage('assets/icons/icon_danmaku_setting.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(child: Center()),
                  Offstage(
                    offstage: isPortrait,
                    child: TextButton(
                      onPressed: () {
                        if (controller.fullScreen.value) {
                          controller.showQualites.value = true;
                        } else {
                          controller.showQualitySheet();
                        }
                      },
                      child: Obx(
                        () => Text(
                          controller.currentQualityInfo.value,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: isPortrait,
                    child: TextButton(
                      onPressed: () {
                        if (controller.fullScreen.value) {
                          controller.showLines.value = true;
                        } else {
                          controller.showPlayUrlsSheet();
                        }
                      },
                      child: Text(
                        controller.currentUrlInfo.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.setFull();
                    },
                    icon: const Icon(
                      Remix.fullscreen_line,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: !controller.showTip.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.seekTip.value,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFullPlayer(BuildContext context) {
    var padding = MediaQuery.of(context).padding;
    return Stack(
      children: [
        Container(
          alignment: Alignment.center,
          color: Colors.black,
          child: buildMediaPlayer(),
        ),

        buildDanmuView(),
        Positioned.fill(
          child: Obx(
            () => Offstage(
              offstage: !controller.playerLoadding.value,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              controller.showControls.value = !controller.showControls.value;
              controller.showLines.value = false;
              controller.showQualites.value = false;
              controller.showDanmuSettings.value = false;
            },
            onVerticalDragStart: controller.onVerticalDragStart,
            onVerticalDragUpdate: controller.onVerticalDragUpdate,
            onVerticalDragEnd: controller.onVerticalDragEnd,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),

        // 顶部
        Obx(
          () => AnimatedPositioned(
            left: 0,
            right: 0,
            top: controller.showControls.value ? 0 : -48,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 48,
              padding: EdgeInsets.only(
                left: padding.left + 12,
                right: padding.right + 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black87,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      "${controller.detail.value?.title} - ${controller.detail.value?.userName}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  IconButton(
                    onPressed: () {
                      controller.showDanmuSettings.value = true;
                    },
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 底部
        Obx(
          () => AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: controller.showControls.value ? 0 : -80,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black87,
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                left: padding.left + 12,
                right: padding.right + 12,
                bottom: padding.bottom,
              ),
              child: Row(
                children: [
                  Offstage(
                    offstage: controller.enableDanmaku.value,
                    child: IconButton(
                      onPressed: () => controller.enableDanmaku.value =
                          !controller.enableDanmaku.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_open.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !controller.enableDanmaku.value,
                    child: IconButton(
                      onPressed: () => controller.enableDanmaku.value =
                          !controller.enableDanmaku.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_close.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.showDanmuSettings.value = true;
                    },
                    icon: const ImageIcon(
                      AssetImage('assets/icons/icon_danmaku_setting.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(child: Center()),
                  TextButton(
                    onPressed: () {
                      controller.showQualites.value = true;
                    },
                    child: Obx(
                      () => Text(
                        controller.currentQualityInfo.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      controller.showLines.value = true;
                    },
                    child: Text(
                      controller.currentUrlInfo.value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.exitFull();
                    },
                    icon: const Icon(
                      Remix.fullscreen_exit_fill,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        //清晰度
        Obx(
          () => AnimatedPositioned(
            right: controller.showQualites.value ? 0 : -200,
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 200,
              color: Colors.grey.shade900,
              padding: EdgeInsets.only(right: padding.right),
              child: MediaQuery(
                data: const MediaQueryData(padding: EdgeInsets.zero),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: controller.qualites.length,
                  itemBuilder: (_, i) {
                    var item = controller.qualites[i];
                    return ListTile(
                      selected: controller.currentQuality == i,
                      textColor: Colors.white,
                      title: Text(
                        item.quality,
                        style: const TextStyle(fontSize: 14),
                      ),
                      minLeadingWidth: 16,
                      onTap: () {
                        controller.showQualites.value = false;
                        controller.currentQuality = i;
                        controller.getPlayUrl();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        //线路
        Obx(
          () => AnimatedPositioned(
            right: controller.showLines.value ? 0 : -200,
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 200,
              color: Colors.grey.shade900,
              padding: EdgeInsets.only(right: padding.right),
              child: MediaQuery(
                data: const MediaQueryData(padding: EdgeInsets.zero),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: controller.playUrls.length,
                  itemBuilder: (_, i) {
                    return ListTile(
                      selected: controller.currentUrl == i,
                      textColor: Colors.white,
                      title: Text(
                        "线路${i + 1}",
                        style: const TextStyle(fontSize: 14),
                      ),
                      minLeadingWidth: 16,
                      onTap: () {
                        controller.showLines.value = false;
                        controller.currentUrl = i;
                        controller.setPlayer();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        //设置
        Obx(
          () => AnimatedPositioned(
            right: controller.showDanmuSettings.value ? 0 : -400,
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 400,
              color: Colors.grey.shade900,
              padding: EdgeInsets.only(right: padding.right),
              child: MediaQuery(
                data: const MediaQueryData(padding: EdgeInsets.zero),
                child: Obx(
                  () => ListView(
                    padding: AppStyle.edgeInsetsV12,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "弹幕区域: ${(controller.settingsController.danmuArea.value * 100).toInt()}%",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Slider(
                        value: controller.settingsController.danmuArea.value,
                        max: 1.0,
                        min: 0.1,
                        onChanged: (e) {
                          controller.settingsController.setDanmuArea(e);
                          controller.updateDanmuOption(
                            controller.danmakuController?.option
                                .copyWith(area: e),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "不透明度: ${(controller.settingsController.danmuOpacity.value * 100).toInt()}%",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Slider(
                        value: controller.settingsController.danmuOpacity.value,
                        max: 1.0,
                        min: 0.1,
                        onChanged: (e) {
                          controller.settingsController.setDanmuOpacity(e);
                          controller.updateDanmuOption(
                            controller.danmakuController?.option
                                .copyWith(opacity: e),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "弹幕大小: ${(controller.settingsController.danmuSize.value).toInt()}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Slider(
                        value: controller.settingsController.danmuSize.value,
                        min: 8,
                        max: 36,
                        onChanged: (e) {
                          controller.settingsController.setDanmuSize(e);
                          controller.updateDanmuOption(
                            controller.danmakuController?.option
                                .copyWith(fontSize: e),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "弹幕速度: ${(controller.settingsController.danmuSpeed.value).toInt()} (越小越快)",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Slider(
                        value: controller.settingsController.danmuSpeed.value,
                        min: 4,
                        max: 20,
                        onChanged: (e) {
                          controller.settingsController.setDanmuSpeed(e);
                          controller.updateDanmuOption(
                            controller.danmakuController?.option
                                .copyWith(duration: e),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: !controller.showTip.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.seekTip.value,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMediaPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(
        key: controller.globalPlayerKey,
        controller: controller.videoController,
        // child: Obx(
        //   () {
        //     if (controller.vlcPlayerController.value == null) {
        //       return const Center(
        //         child: Text(
        //           "正在加载信息",
        //           style: TextStyle(fontSize: 16, color: Colors.white),
        //         ),
        //       );
        //     } else {
        //       controller.vlcPlayer ??= Video(
        //         key: controller.globalPlayerKey,
        //         controller: controller.vlcPlayerController.value!,
        //         aspectRatio: 16 / 9,
        //       );
        //       return controller.vlcPlayer!;
        //     }
        //   },
        // ),
      ),
    );
  }

  Widget buildDanmuView() {
    controller.danmakuView ??= DanmakuView(
      key: controller.globalDanmuKey,
      createdController: controller.setDanmakuController,
      option: DanmakuOption(
        fontSize: 16,
      ),
    );
    return Positioned.fill(
      child: Obx(
        () => Offstage(
          offstage: !controller.enableDanmaku.value,
          child: controller.danmakuView!,
        ),
      ),
    );
  }

  Widget buildUserProfile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(.1),
          ),
          bottom: BorderSide(
            color: Colors.grey.withOpacity(.1),
          ),
        ),
      ),
      padding: AppStyle.edgeInsetsA8.copyWith(
        left: 12,
        right: 12,
      ),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(.2)),
                borderRadius: AppStyle.radius24,
              ),
              child: NetImage(
                controller.detail.value?.userAvatar ?? "",
                width: 48,
                height: 48,
                borderRadius: 24,
              ),
            ),
            AppStyle.hGap12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.detail.value?.userName ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppStyle.vGap4,
                  Row(
                    children: [
                      Image.asset(
                        controller.site.logo,
                        width: 20,
                      ),
                      AppStyle.hGap4,
                      Text(
                        controller.site.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppStyle.hGap12,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Remix.fire_fill,
                  size: 20,
                  color: Colors.orange,
                ),
                AppStyle.hGap4,
                Text(
                  Utils.onlineToString(
                    controller.detail.value?.online ?? 0,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(.1),
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: AppStyle.bottomBarHeight),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => controller.followed.value
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      onPressed: controller.removeFollowUser,
                      icon: const Icon(Remix.heart_fill),
                      label: const Text("取消关注"),
                    )
                  : TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      onPressed: controller.followUser,
                      icon: const Icon(Remix.heart_line),
                      label: const Text("关注"),
                    ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 14),
              ),
              onPressed: controller.refreshRoom,
              icon: const Icon(Remix.refresh_line),
              label: const Text("刷新"),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 14),
              ),
              onPressed: controller.share,
              icon: const Icon(Remix.share_line),
              label: const Text("分享"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessageArea() {
    return Expanded(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero,
              indicatorWeight: 1.0,
              tabs: [
                const Tab(
                  text: "聊天",
                ),
                Tab(
                  child: Obx(
                    () => Text(
                      controller.superChats.isNotEmpty
                          ? "醒目留言(${controller.superChats.length})"
                          : "醒目留言",
                    ),
                  ),
                ),
                const Tab(
                  text: "设置",
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Obx(
                    () => ListView.builder(
                      controller: controller.scrollController,
                      padding: AppStyle.edgeInsetsA12,
                      itemCount: controller.messages.length,
                      itemBuilder: (_, i) {
                        var item = controller.messages[i];
                        return buildMessageItem(item);
                      },
                    ),
                  ),
                  Obx(
                    () => ListView.separated(
                      padding: AppStyle.edgeInsetsA12,
                      itemCount: controller.superChats.length,
                      separatorBuilder: (_, i) => AppStyle.vGap12,
                      itemBuilder: (_, i) {
                        var item = controller.superChats[i];
                        return SuperChatCard(
                          item,
                          onExpire: () {
                            controller.removeSuperChats();
                          },
                        );
                      },
                    ),
                  ),
                  buildSettings(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessageItem(LiveMessage message) {
    if (message.userName == "LiveSysMessage") {
      return Obx(
        () => Container(
          padding: EdgeInsets.symmetric(
            vertical: controller.settingsController.chatTextGap.value,
          ),
          child: Text(
            message.message,
            style: TextStyle(
              color: Colors.grey,
              fontSize: controller.settingsController.chatTextSize.value,
            ),
          ),
        ),
      );
    }
    return Obx(
      () => Container(
        padding: EdgeInsets.symmetric(
          vertical: controller.settingsController.chatTextGap.value,
        ),
        child: Text.rich(
          TextSpan(
            text: "${message.userName}：",
            style: TextStyle(
              color: Colors.grey,
              fontSize: controller.settingsController.chatTextSize.value,
            ),
            children: [
              TextSpan(
                text: message.message,
                style: TextStyle(
                  color: Get.isDarkMode ? Colors.white : AppColors.black333,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSettings() {
    return Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
            child: Text(
              "聊天区文字大小: ${(controller.settingsController.chatTextSize.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: controller.settingsController.chatTextSize.value,
            min: 8,
            max: 36,
            onChanged: (e) {
              controller.settingsController.setChatTextSize(e);
            },
          ),
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(top: 12),
            child: Text(
              "聊天区上下间隔: ${(controller.settingsController.chatTextGap.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: controller.settingsController.chatTextGap.value,
            min: 0,
            max: 12,
            onChanged: (e) {
              controller.settingsController.setChatTextGap(e);
            },
          ),
        ],
      ),
    );
  }

  List<Widget> buildAppbarActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          controller.showMore();
        },
        icon: const Icon(Icons.more_horiz),
      ),
    ];
  }
}
