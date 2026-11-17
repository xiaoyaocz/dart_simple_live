import 'package:simple_live_app/widgets/live_message_content.dart';
import 'dart:io';
import 'package:simple_live_app/modules/live_room/api_danmaku_panel.dart';

import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/modules/live_room/quick_live_room_sort.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_app/widgets/similar_game_rooms_sheet.dart';
import 'package:simple_live_core/simple_live_core.dart';

class LiveRoomPage extends StatelessWidget {
  final String? roomTag;
  const LiveRoomPage({super.key, this.roomTag});

  LiveRoomController get controller => Get.find<LiveRoomController>(tag: roomTag);

  @override
  Widget build(BuildContext context) {
    final page = Obx(
      () {
        if (controller.loadError.value) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("直播间加载失败"),
            ),
            body: Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LottieBuilder.asset(
                    'assets/lotties/error.json',
                    height: 140,
                    repeat: false,
                  ),
                  const Text(
                    "直播间加载失败",
                    textAlign: TextAlign.center,
                  ),
                  AppStyle.vGap4,
                  Text(
                    controller.error?.toString() ?? "未知错误",
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  AppStyle.vGap4,
                  Text(
                    "${controller.rxSite.value.id} - ${controller.rxRoomId.value}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: controller.copyErrorDetail,
                        icon: const Icon(Remix.file_copy_line),
                        label: const Text("复制信息"),
                      ),
                      TextButton.icon(
                        onPressed: controller.refreshRoom,
                        icon: const Icon(Remix.refresh_line),
                        label: const Text("刷新"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
        final fullScreen = controller.fullScreenState.value;
        if (Platform.isWindows) {
          return PopScope(
            canPop: !fullScreen,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && fullScreen) controller.exitFull();
            },
            child: buildPageUI(fullScreen: fullScreen),
          );
        }
        if (fullScreen) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (e, r) {
              controller.exitFull();
            },
            child: Scaffold(
              body: buildMediaPlayer(),
            ),
          );
        } else {
          return buildPageUI();
        }
      },
    );
    if (!Platform.isAndroid) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final focusedPage = Focus(
          autofocus: true,
          // Page focus remains active after using the header/chat. The video
          // controls are not always the primary focus owner after a rebuild.
          onKeyEvent: (_, event) => controller.officialEditorFocused.value
              ? KeyEventResult.ignored : handlePlayerShortcut(
            event,
            onRefresh: controller.refreshRoom,
            onComposeDanmaku: controller.openDanmakuComposer,
            onFollowKey: controller.followByDoubleQ,
            onResetFollowKey: controller.resetFollowShortcut,
            onToggleDanmaku: () => controller.showDanmakuState.toggle(),
            onToggleFullscreen: () {
              if (controller.fullScreenState.value) {
                controller.exitFull();
              } else {
                controller.enterFullScreen();
              }
            },
          ),
          child: page,
        );
        return Platform.isWindows
            ? DesktopDanmakuShortcut(
                onCompose: controller.openDanmakuComposer,
                isEditing: () => controller.officialEditorFocused.value, child: focusedPage)
            : focusedPage;
      }
      return page;
    }
    return PiPSwitcher(
      floating: controller.pip,
      childWhenDisabled: page,
      childWhenEnabled: buildMediaPlayer(),
    );
  }

  Widget buildPageUI({bool fullScreen = false}) {
    return Builder(
      builder: (context) {
        // 同方向缩放只重新布局，不重新构造整个播放页。
        final orientation = MediaQuery.orientationOf(context);
        return Scaffold(
          appBar: fullScreen
              ? null
              : AppBar(
                  flexibleSpace: Platform.isWindows ||
                          Platform.isLinux ||
                          Platform.isMacOS
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: controller.restoreDefaultWindowSize,
                          child: const SizedBox.expand(),
                        )
                      : null,
                  title: Obx(
                    () => Text(controller.detail.value?.title ?? "直播间"),
                  ),
                  actions: buildAppbarActions(context),
                ),
          body: Platform.isWindows
              ? buildTabletUI(context,
                  fullScreen: fullScreen,
                  portrait: orientation == Orientation.portrait)
              : orientation == Orientation.portrait
                  ? buildPhoneUI(context)
                  : buildTabletUI(context),
        );
      },
    );
  }

  Widget buildPhoneUI(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: buildMediaPlayer(),
          ),
          buildUserProfile(context),
          buildMessageArea(),
        ],
      ),
    );
  }

  Widget buildTabletUI(BuildContext context,
      {bool fullScreen = false, bool portrait = false}) {
    final phoneLayout = portrait && !fullScreen;
    final video = Expanded(child: buildMediaPlayer());
    final sidebar = phoneLayout ? null : RepaintBoundary(child: Column(children: [
      buildUserProfile(context), buildMessageArea(),
    ]));
    Widget row(bool show, double width) => Row(children: [
      video,
      if (show) SizedBox(width: width, child: sidebar),
    ]);
    final playerRow = Platform.isWindows ? Obx(() {
      final requested = controller.officialEditorVisible.value;
      return LayoutBuilder(builder: (context, constraints) {
        final available = constraints.maxWidth;
        const preferredWidth = 300.0;
        final width = preferredWidth.clamp(0.0, available * 0.85);
        return row(!phoneLayout && ((!fullScreen && !portrait) || requested), width);
      });
    }) : row(!fullScreen && !portrait, 300);
    return Column(
      children: [
        // 保持视频的父子路径不变，切换时仅改变容器约束。
        Flexible(
          flex: phoneLayout ? 0 : 1,
          fit: FlexFit.tight,
          child: LayoutBuilder(
            // 尺寸变化只更新约束，复用视频和聊天子树。
            builder: (context, constraints) => SizedBox(
              height: phoneLayout ? constraints.maxWidth * 9 / 16 : null,
              child: playerRow,
            ),
          ),
        ),
        if (phoneLayout) ...[
          buildUserProfile(context),
          buildMessageArea(),
        ],
      ],
    );
  }

  Widget buildMediaPlayer() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    final video = Stack(
      children: [
        Video(
          key: controller.globalPlayerKey,
          controller: controller.videoController,
          pauseUponEnteringBackgroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          resumeUponEnteringForegroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          controls: (state) {
            return playerControls(state, controller);
          },
          aspectRatio: aspectRatio,
          fit: boxFit,
          // 自己实现
          wakelock: false,
        ),
        Obx(
          () => Visibility(
            visible: controller.roomOffline.value,
            child: const Center(
              child: Text(
                "主播已下播",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
    return playerVolumeScrollArea(controller: controller, child: video);
  }

  Widget buildUserProfile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
          bottom: BorderSide(
            color: Colors.grey.withAlpha(25),
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
                border: Border.all(color: Colors.grey.withAlpha(50)),
                borderRadius: AppStyle.radius24,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapUp: (details) =>
                    showAvatarFollowMenu(context, details.globalPosition),
                child: NetImage(
                  controller.detail.value?.userAvatar ?? "",
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                ),
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

  Future<void> showAvatarFollowMenu(BuildContext context, Offset position) async {
    final room = controller;
    final roomId = room.roomId;
    final site = room.site;
    final detail = room.detail.value;
    if (detail == null || room.isClosed) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final wasFollowed = room.followed.value;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(position) & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'follow',
          enabled: !wasFollowed,
          child: wasFollowed
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => Navigator.of(context).pop('unfollow'),
                  child: const SizedBox(
                    width: double.infinity,
                    height: kMinInteractiveDimension,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('已关注'),
                    ),
                  ),
                )
              : const Text('关注'),
        ),
      ],
    );
    // 菜单等待期间切房/刷新后，不把旧头像的操作应用到新房间。
    if (selected == null || room.isClosed || room.roomId != roomId ||
        room.site != site || !identical(room.detail.value, detail)) {
      return;
    }
    if (selected == 'unfollow' && room.followed.value) {
      room.removeFollowUser();
      return;
    }
    if (selected != 'follow' || room.followed.value) return;
    room.followUser();
    if (room.followed.value) {
      SmartDialog.showToast('关注成功', displayTime: const Duration(seconds: 2));
    }
  }
  Widget buildBottomActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
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
    void scrollToLatest() {
      controller.disableAutoScroll.value = false;
      controller.chatScrollToBottom();
      // The composer changes the viewport. A lazy list may refine its extent
      // only after the first jump lays out its final messages.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.isClosed) controller.chatScrollToBottom();
      });
    }

    return Expanded(
      child: DefaultTabController(
        length: controller.site.id == Constant.kBiliBili ? 4 : 3,
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
                if (controller.site.id == Constant.kBiliBili)
                  Tab(
                    child: Obx(
                      () => Text(
                        controller.superChats.isNotEmpty
                            ? "SC(${controller.superChats.length})"
                            : "SC",
                      ),
                    ),
                  ),
                const Tab(
                  text: "关注",
                ),
                const Tab(
                  text: "设置",
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  buildOfficialChatArea(Obx(
                    () => Stack(
                      children: [
                        GestureDetector(
                          // 覆盖文字和空白处，双击与“最新”按钮保持相同行为。
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: scrollToLatest,
                          child: ListView.separated(
                            controller: controller.scrollController,
                            separatorBuilder: (_, i) => Obx(
                              () => SizedBox(
                                // *2与原来的EdgeInsets.symmetric(vertical: )做兼容
                                height: AppSettingsController
                                        .instance.chatTextGap.value *
                                    2,
                              ),
                            ),
                            padding: AppStyle.edgeInsetsA12,
                            itemCount: controller.messages.length,
                            itemBuilder: (_, i) {
                              var item = controller.messages[i];
                              return buildMessageItem(item);
                            },
                          ),
                        ),
                        Visibility(
                          visible: controller.disableAutoScroll.value,
                          child: Positioned(
                            right: 12,
                            bottom: 12,
                            child: ElevatedButton.icon(
                              onPressed: scrollToLatest,
                              icon: const Icon(Icons.expand_more),
                              label: const Text("最新"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (controller.site.id == Constant.kBiliBili)
                    buildSuperChats(),
                  buildFollowList(),
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
    return Obx(() {
      final size = AppSettingsController.instance.chatTextSize.value;
      if (message.userName == 'LiveSysMessage') {
        return Text(message.message,style:TextStyle(color:Colors.grey,fontSize:size));
      }
      final isSelf = controller.isSelfMessage(message);
      final content = LiveMessageContent(userName:message.userName, isSelf:isSelf,
        parts:controller.messageParts(message),fontSize:size,
        color:Get.isDarkMode ? Colors.white : AppColors.black333);
      if (isSelf) return SelfChatHighlight(child: content);
      if (!AppSettingsController.instance.chatBubbleStyle.value) return content;
      return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Flexible(child:Container(
          decoration:BoxDecoration(color:Colors.blueGrey.withAlpha(25),
            borderRadius:const BorderRadius.only(topRight:Radius.circular(12),
              bottomLeft:Radius.circular(12),bottomRight:Radius.circular(12))),
          padding:AppStyle.edgeInsetsA4.copyWith(left:12,right:12),child:content)),
      ]);
    });
  }

  Widget buildOfficialChatArea(Widget messages) {
    if (!Platform.isWindows) return messages;
    return Obx(() {
      final siteId = controller.rxSite.value.id;
      final roomId = controller.rxRoomId.value;
      final detail = controller.detail.value;
      final focus = controller.officialEditorFocusRequest.value;
      bool current() => controller.site.id == siteId && controller.roomId == roomId && !controller.isClosed;
      return Column(children: [
        Expanded(child: messages),
        if (detail != null) ApiDanmakuPanel(
          key: ValueKey('api-editor:$siteId:$roomId:${detail.roomId}'),
          siteId: siteId, roomId: detail.roomId, focusRequest: focus,
          resolveLoginView: controller.resolveDanmakuLoginView,
          isCurrent: current,
          emoticons: () => controller.roomEmoticons,
          roomUri: controller.officialEditorRoomUri,
          confirmationRoomIds: [detail.roomId,
            if(detail.danmakuData is DouyinDanmakuArgs)
              (detail.danmakuData as DouyinDanmakuArgs).roomId],
          searchEnvironment: const {'huya','douyin'}.contains(siteId) ? controller.officialEditorEnvironment : null,
          onSelfNameDetected: (name) { if(current()) controller.updateOfficialSelfName(name); },
          onIdentityDetected: (id,name) { if(current()) controller.updateSelfIdentity(id,name); },
        ),
      ]);
    });
  }

  Widget buildSuperChats() {
    return KeepAliveWrapper(
      child: Obx(
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
    );
  }

  Widget buildSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA12,
      children: [
        Obx(
          () => Visibility(
            visible: controller.autoExitEnable.value,
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              visualDensity: VisualDensity.compact,
              title: Text("${parseDuration(controller.countdown.value)}后自动关闭"),
            ),
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "聊天区",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsNumber(
                  title: "文字大小",
                  value:
                      AppSettingsController.instance.chatTextSize.value.toInt(),
                  min: 8,
                  max: 36,
                  onChanged: (e) {
                    AppSettingsController.instance
                        .setChatTextSize(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "上下间隔",
                  value:
                      AppSettingsController.instance.chatTextGap.value.toInt(),
                  min: 0,
                  max: 12,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatTextGap(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "气泡样式",
                  value: AppSettingsController.instance.chatBubbleStyle.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatBubbleStyle(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "播放器中显示SC",
                  value:
                      AppSettingsController.instance.playershowSuperChat.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setPlayerShowSuperChat(e);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "更多设置",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsAction(
                title: "关键词屏蔽",
                onTap: controller.showDanmuShield,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "弹幕设置",
                onTap: controller.showDanmuSettingsSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "定时关闭",
                onTap: controller.showAutoExitSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "画面尺寸",
                onTap: controller.showPlayerSettingsSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildFollowList() {
    return Obx(
      () {
        final items = sortQuickLiveRooms(FollowService.instance.liveList.toList(),
            AppSettingsController.instance.siteSort.toList());
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: FollowService.instance.loadData,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  var item = items[i];
                  return Obx(
                    () => FollowUserItem(
                      item: item,
                      playing: controller.rxSite.value.id == item.siteId &&
                          controller.rxRoomId.value == item.roomId,
                      onTap: () {
                        controller.resetRoom(
                          Sites.allSites[item.siteId]!,
                          item.roomId,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Positioned(
                right: 12,
                bottom: 12,
                child: Obx(
                  () => DesktopRefreshButton(
                    refreshing: FollowService.instance.updating.value,
                    onPressed: FollowService.instance.loadData,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> buildAppbarActions(BuildContext context) {
    return [
      TextButton.icon(
        onPressed: showSimilarGameRooms,
        icon: const Icon(Icons.sports_esports_outlined),
        label: const Text('同类主播'),
      ),
      IconButton(
        onPressed: () {
          showMore();
        },
        icon: const Icon(Icons.more_horiz),
      ),
    ];
  }

  Future<void> showSimilarGameRooms() async {
    final roomController = controller;
    final detail = roomController.detail.value;
    final site = roomController.site;
    if (detail == null || roomController.isClosed || roomController.similarGameRoomsOpen) return;
    roomController.similarGameRoomsOpen = true;
    bool sameRoom() => !roomController.isClosed && roomController.site == site &&
        roomController.detail.value?.roomId == detail.roomId;
    try {
      final fullCategory = await showModalBottomSheet<LiveSubCategory>(
        context: Get.context!,
        constraints: const BoxConstraints(maxWidth: 640),
        isScrollControlled: true,
        builder: (_) => SimilarGameRoomsSheet(
          site: site.liveSite,
          detail: detail,
          onRoomSelected: (room) {
            if (sameRoom()) roomController.resetRoom(site, room.roomId);
          },
        ),
      );
      if (fullCategory != null && sameRoom()) {
        final wasPlaying = roomController.player.state.playing;
        if (wasPlaying) await roomController.player.pause();
        await Get.toNamed(RoutePath.kCategoryDetail, arguments: [site, fullCategory]);
        if (sameRoom() && wasPlaying) await roomController.player.play();
      }
    } finally {
      roomController.similarGameRoomsOpen = false;
    }
  }
  void showMore() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: AppStyle.bottomBarHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => ListTile(
              leading: Icon(controller.followed.value ? Remix.heart_fill : Remix.heart_line),
              title: Text(controller.followed.value ? '取消关注' : '关注主播'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                if (controller.followed.value) {
                  controller.removeFollowUser();
                } else {
                  controller.followUser();
                }
              },
            )),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("刷新"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.refreshRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              trailing: const Icon(Icons.chevron_right),
              title: const Text("切换清晰度"),
              onTap: () {
                Get.back();
                controller.showQualitySheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_video_outlined),
              title: const Text("切换线路"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayUrlsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_outlined),
              title: const Text("画面尺寸"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayerSettingsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("截图"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.saveScreenshot();
              },
            ),
            Visibility(
              visible: Platform.isAndroid,
              child: ListTile(
                leading: const Icon(Icons.picture_in_picture),
                title: const Text("小窗播放"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.back();
                  controller.enablePIP();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text("定时关闭"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showAutoExitSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_sharp),
              title: const Text("分享直播间"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.share();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("复制链接"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.copyUrl();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("APP中打开"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.openNaviteAPP();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text("播放信息"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showDebugInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  String parseDuration(int sec) {
    // 转为时分秒
    var h = sec ~/ 3600;
    var m = (sec % 3600) ~/ 60;
    var s = sec % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}小时${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    if (m > 0) {
      return "${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    return "${s.toString().padLeft(2, '0')}秒";
  }
}
