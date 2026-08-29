import 'dart:io';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/modules/live_room/widgets/live_contribution_rank_panel.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LiveRoomPage extends GetView<LiveRoomController> {
  static const double _desktopSidePanelWidth = 300.0;
  static const double _desktopSidePanelCollapsedWidth = 48.0;

  const LiveRoomPage({Key? key}) : super(key: key);

  double _bottomSafeInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding.bottom;
    final padding = mediaQuery.padding.bottom;
    return viewPadding > padding ? viewPadding : padding;
  }

  double _bottomActionInset(BuildContext context) {
    if (Platform.isIOS &&
        MediaQuery.of(context).orientation == Orientation.landscape) {
      return 0;
    }
    final safeInset = _bottomSafeInset(context);
    if (!Platform.isIOS) {
      return safeInset;
    }
    return safeInset.clamp(0.0, 16.0).toDouble();
  }

  bool get _isDesktop {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  double _landscapeSideWidth(double maxWidth) {
    if (maxWidth <= _desktopSidePanelWidth) {
      return 0.0;
    }
    if (_isDesktop && controller.desktopSidePanelCollapsed.value) {
      return _desktopSidePanelCollapsedWidth;
    }
    return _desktopSidePanelWidth;
  }

  Widget _buildRoomTitleText() {
    return Obx(
      () => Text(
        controller.detail.value?.title ?? "直播间",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMobileAppBarTitle(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kToolbarHeight),
              child: Center(
                child: _buildRoomTitleText(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => _handleBack(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: showMore,
              icon: const Icon(Icons.more_horiz),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeAppBarTitle(BuildContext context) {
    if (_isDesktop) {
      return Obx(() => _buildLandscapeAppBarTitleContent(context));
    }
    return _buildLandscapeAppBarTitleContent(context);
  }

  Widget _buildLandscapeAppBarTitleContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePanelWidth = _landscapeSideWidth(constraints.maxWidth);
        final playerWidth = constraints.maxWidth - sidePanelWidth;
        return SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              SizedBox(
                width: playerWidth,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: kToolbarHeight,
                          right: 16,
                        ),
                        child: Center(
                          child: _buildRoomTitleText(),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => _handleBack(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: sidePanelWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: showMore,
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopOverlayIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withAlpha(120),
        borderRadius: AppStyle.radius24,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: Colors.white,
        ),
      ),
    );
  }

  List<Widget> _buildDesktopOverlayButtons(BuildContext context) {
    return [
      // Desktop uses an overlay instead of a Flutter AppBar so the player
      // keeps its full video area. Keep the room title visible on all three
      // desktop targets while retaining the existing edge controls.
      // 只在全屏或小窗时显示标题
      Obx(() {
        final shouldShowTitle = controller.fullScreenState.value ||
                                controller.smallWindowState.value;
        if (!shouldShowTitle) {
          return const SizedBox.shrink();
        }

        // 使用 LayoutBuilder 获取实际播放器区域宽度
        return LayoutBuilder(
          builder: (context, constraints) {
            // 计算侧边栏宽度
            // 全屏时没有侧边栏，非全屏时根据设置计算
            final sidePanelWidth = controller.fullScreenState.value
                ? 0.0
                : _landscapeSideWidth(constraints.maxWidth);

            // 标题应该从左到右减去侧边栏宽度
            // 这样标题就只在播放器区域内居中
            return Positioned(
              top: 8,
              left: 56,
              right: sidePanelWidth + 56,  // 右边留出侧边栏宽度 + 按钮空间
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(110),
                      borderRadius: AppStyle.radius8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          child: _buildRoomTitleText(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
      Obx(() {
        if (!controller.showControlsState.value) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: _buildDesktopOverlayIconButton(
                tooltip: "返回",
                icon: Icons.arrow_back,
                onPressed: () => _handleBack(context),
              ),
            ),
            Positioned(
              right: 8,
              top: controller.desktopSidePanelCollapsed.value ? 56 : 8,
              child: _buildDesktopOverlayIconButton(
                tooltip: "更多",
                icon: Icons.more_horiz,
                onPressed: showMore,
              ),
            ),
            if (Platform.isWindows &&
                controller.desktopSidePanelCollapsed.value)
              Positioned(
                right: 8,
                top: 8,
                child: _buildDesktopOverlayIconButton(
                  tooltip: "关闭",
                  icon: Icons.close,
                  onPressed: () => _handleBack(context),
                ),
              ),
            if (_isDesktop && controller.desktopSidePanelCollapsed.value)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildDesktopOverlayIconButton(
                    tooltip: "展开聊天区",
                    icon: Icons.chevron_left,
                    onPressed: controller.toggleDesktopSidePanel,
                  ),
                ),
              ),
          ],
        );
      }),
    ];
  }

  bool _allowsNativePopGesture() {
    return Platform.isIOS &&
        !controller.fullScreenState.value &&
        !controller.smallWindowState.value;
  }

  @override
  Widget build(BuildContext context) {
    final page = Obx(() {
      if (Platform.isAndroid && controller.androidInPipState.value) {
        return _buildPipOnlyPage();
      }
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
                ),
              ],
            ),
          ),
        );
      }
      if (controller.fullScreenState.value) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            controller.exitPlayerWindowMode();
          },
          child: Scaffold(
            body: buildMediaPlayer(),
          ),
        );
      }
      return buildPageUI();
    });
    return page;
  }

  /// Android PiP captures the whole activity. Keep the activity tree limited
  /// to a black video surface so the AppBar, chat and player controls cannot
  /// leak into the system floating window.
  Widget _buildPipOnlyPage() {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          _buildMediaPlayerContent(pipMode: true),
          // 添加 PIP 弹幕支持
          if (AppSettingsController.instance.enablePipDanmu.value)
            _buildPipDanmuLayer(),
        ],
      ),
    );
  }

  /// PIP 模式下的安全弹幕层
  Widget _buildPipDanmuLayer() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(8),  // 边距确保不触边
        child: Obx(() {
          return Offstage(
            offstage: !controller.showDanmakuState.value,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final settings = AppSettingsController.instance;

                // PIP 模式使用固定的小字号和限制区域
                final fontSize = settings.danmuSize.value * settings.pipDanmuScale.value;
                const area = 0.4;  // 限制40%区域
                const opacity = 0.75;  // 稍微透明

                return DanmakuScreen(
                  key: controller.globalDanmuKey,
                  createdController: controller.initDanmakuController,
                  option: DanmakuOption(
                    fontSize: fontSize,
                    fontFamily: Platform.isWindows ? "Microsoft YaHei" : (Platform.isAndroid ? "Roboto" : null),
                    area: area,
                    lineHeight: 1.2,
                    duration: settings.danmuSpeed.value.toInt(),
                    opacity: opacity,
                    fontWeight: settings.danmuFontWeight.value,
                    hideTop: true,      // PIP模式只显示滚动弹幕
                    hideBottom: true,
                    hideScroll: false,
                    hideSpecial: true,
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget buildPageUI() {
    return OrientationBuilder(
      builder: (context, orientation) {
        final shortestSide = MediaQuery.sizeOf(context).shortestSide;
        final isCompactMobile = shortestSide < 600;
        final usePortraitLayout = (Platform.isAndroid || Platform.isIOS) &&
            isCompactMobile &&
            !controller.fullScreenState.value &&
            !controller.smallWindowState.value;
        final effectiveOrientation =
            usePortraitLayout ? Orientation.portrait : orientation;
        final hasLandscapeActionPanel =
            effectiveOrientation == Orientation.landscape;
        if (_isDesktop) {
          final body = effectiveOrientation == Orientation.portrait
              ? buildPhoneUI(context)
              : buildTabletUI(context);
          return PopScope(
            canPop: _allowsNativePopGesture(),
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) {
                await controller.cancelAutoPipOnLeave();
                return;
              }
              await _handleBack(context);
            },
            child: Scaffold(
              body: MouseRegion(
                onEnter: (_) => controller.showControls(),
                onHover: (_) => controller.showControls(),
                child: Stack(
                  children: [
                    body,
                    ..._buildDesktopOverlayButtons(context),
                  ],
                ),
              ),
            ),
          );
        }
        final scaffold = Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: hasLandscapeActionPanel
                ? _buildLandscapeAppBarTitle(context)
                : _buildMobileAppBarTitle(context),
          ),
          body: effectiveOrientation == Orientation.portrait
              ? buildPhoneUI(context)
              : buildTabletUI(context),
        );
        return PopScope(
          canPop: _allowsNativePopGesture(),
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              await controller.cancelAutoPipOnLeave();
              return;
            }
            await _handleBack(context);
          },
          child: scaffold,
        );
      },
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    await controller.cancelAutoPipOnLeave();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget buildPhoneUI(BuildContext context) {
    if (_isDesktop && controller.desktopSidePanelCollapsed.value) {
      return Column(
        children: [
          Expanded(
            child: buildMediaPlayer(),
          ),
          _buildCollapsedDesktopBottomPanel(context),
        ],
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: buildMediaPlayer(),
        ),
        buildUserProfile(context),
        buildMessageArea(),
        buildBottomActions(context),
      ],
    );
  }

  Widget buildTabletUI(BuildContext context) {
    return Obx(() {
      final collapsed =
          _isDesktop && controller.desktopSidePanelCollapsed.value;
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: buildMediaPlayer(),
                ),
                if (!collapsed) _buildExpandedSidePanel(context),
              ],
            ),
          ),
          if (!collapsed)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withAlpha(25),
                  ),
                ),
              ),
              padding: AppStyle.edgeInsetsV4.copyWith(
                bottom: _bottomActionInset(context) + 4,
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
                  AppStyle.hGap4,
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
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    onPressed: controller.copyUrl,
                    icon: const Icon(Remix.file_copy_line),
                    label: const Text("复制链接"),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    onPressed: controller.copyPlayUrl,
                    icon: const Icon(Remix.file_copy_line),
                    label: const Text("复制播放直链"),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _buildExpandedSidePanel(BuildContext context) {
    final showCollapseAction = _isDesktop;
    return SizedBox(
      width: _desktopSidePanelWidth,
      child: Column(
        children: [
          if (showCollapseAction)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  left: BorderSide(
                    color: Colors.grey.withAlpha(25),
                  ),
                  bottom: BorderSide(
                    color: Colors.grey.withAlpha(25),
                  ),
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: "折叠聊天区",
                child: IconButton(
                  onPressed: controller.toggleDesktopSidePanel,
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                buildUserProfile(context),
                buildMessageArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedDesktopBottomPanel(BuildContext context) {
    return Container(
      height: 48 + _bottomActionInset(context),
      padding: EdgeInsets.only(bottom: _bottomActionInset(context)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Tooltip(
              message: "展开聊天区",
              child: IconButton(
                onPressed: controller.toggleDesktopSidePanel,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget buildMediaPlayer() {
    return _buildMediaPlayerContent();
  }

  Widget _buildMediaPlayerContent({bool pipMode = false}) {
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
    if (pipMode) {
      // The system PiP bounds use the decoded stream dimensions. Keep the
      // Flutter surface on the same ratio regardless of the user's normal
      // player scale preference.
      boxFit = BoxFit.contain;
      final width = controller.player.state.width ?? 0;
      final height = controller.player.state.height ?? 0;
      aspectRatio = width > 0 && height > 0 ? width / height : null;
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.black),
        ),
        Video(
          key: controller.globalPlayerKey,
          controller: controller.videoController,
          pauseUponEnteringBackgroundMode:
              !AppSettingsController.instance.allowBackgroundPlayback.value,
          resumeUponEnteringForegroundMode:
              !AppSettingsController.instance.allowBackgroundPlayback.value,
          controls:
              pipMode ? null : (state) => playerControls(state, controller),
          aspectRatio: aspectRatio,
          fit: boxFit,
          // 自己实现
          wakelock: false,
        ),
        if (!pipMode)
          Obx(
            () => Visibility(
              visible: !controller.liveStatus.value,
              child: const Center(
                child: Text(
                  "未开播",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
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
                    controller.online.value,
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
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: _bottomActionInset(context)),
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
    return Obx(() {
      final hasSuperChatTab = controller.site.id == Constant.kBiliBili ||
          controller.site.id == Constant.kHuya;
      final tabs = <Widget>[];
      final pages = <Widget>[];
      final keys = <String>[];
      void addTab(String key) {
        switch (key) {
          case "chat":
            keys.add(key);
            tabs.add(const Tab(text: "聊天"));
            pages.add(buildChatList());
            break;
          case "super_chat":
            if (!hasSuperChatTab) return;
            keys.add(key);
            tabs.add(
              Tab(
                child: Text(
                  controller.superChats.isNotEmpty
                      ? "${controller.site.id == Constant.kHuya ? "头条" : "SC"}(${controller.superChats.length})"
                      : controller.site.id == Constant.kHuya
                          ? "头条"
                          : "SC",
                ),
              ),
            );
            pages.add(buildSuperChats());
            break;
          case "follow":
            keys.add(key);
            tabs.add(const Tab(text: "关注"));
            pages.add(buildFollowList());
            break;
          case "contribution_rank":
            if (!controller.supportsContributionRank ||
                !AppSettingsController.instance.contributionRankEnable.value) {
              return;
            }
            keys.add(key);
            tabs.add(
              Tab(
                text: controller.site.id == Constant.kDouyu ? "亲密榜" : "贡献榜",
              ),
            );
            pages.add(
              KeepAliveWrapper(
                child: LiveContributionRankPanel(controller: controller),
              ),
            );
            break;
          case "event_flow":
            if (!AppSettingsController.instance.liveEventFlowEnable.value) {
              return;
            }
            keys.add(key);
            tabs.add(
              Tab(
                child: Text(
                  controller.liveEventFlows.isNotEmpty
                      ? "动态(${controller.liveEventFlows.length})"
                      : "动态",
                ),
              ),
            );
            pages.add(buildLiveEventFlow());
            break;
          case "settings":
            keys.add(key);
            tabs.add(const Tab(text: "设置"));
            pages.add(buildSettings());
            break;
        }
      }

      for (final key in AppSettingsController.instance.liveRoomTabSort) {
        addTab(key);
      }
      if (tabs.isEmpty) {
        keys.add("chat");
        tabs.add(const Tab(text: "聊天"));
        pages.add(buildChatList());
      }
      final selectedKey = controller.liveRoomSelectedPanelKey.value;
      final initialIndex =
          keys.contains(selectedKey) ? keys.indexOf(selectedKey) : 0;
      return Expanded(
        child: DefaultTabController(
          key: ValueKey(keys.join("|")),
          length: tabs.length,
          initialIndex: initialIndex,
          child: Column(
            children: [
              TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: EdgeInsets.zero,
                indicatorWeight: 1.0,
                onTap: (index) {
                  if (index >= 0 && index < keys.length) {
                    controller.liveRoomSelectedPanelKey.value = keys[index];
                  }
                },
                tabs: tabs,
              ),
              Expanded(
                child: TabBarView(
                  children: pages,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget buildChatList() {
    return Stack(
      children: [
        ListView.separated(
          controller: controller.scrollController,
          reverse: false,
          separatorBuilder: (_, i) => SizedBox(
            // *2与原来的EdgeInsets.symmetric(vertical: )做兼容
            height: AppSettingsController.instance.chatTextGap.value * 2,
          ),
          padding: AppStyle.edgeInsetsA12,
          itemCount: controller.messages.length,
          itemBuilder: (_, i) {
            var item = controller.messages[i];
            return buildMessageItem(item);
          },
        ),
        Visibility(
          visible: controller.disableAutoScroll.value,
          child: Positioned(
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: () {
                controller.forceChatScrollToBottom();
              },
              icon: const Icon(Icons.expand_more),
              label: const Text("最新"),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLiveEventFlow() {
    return KeepAliveWrapper(
      child: Obx(() {
        if (!AppSettingsController.instance.liveEventFlowEnable.value) {
          return const AppEmptyWidget(message: "重点动态已关闭");
        }
        if (controller.liveEventFlows.isEmpty) {
          return const AppEmptyWidget(message: "暂未捕捉到重复动态");
        }
        return ListView.separated(
          padding: AppStyle.edgeInsetsA12,
          itemCount: controller.liveEventFlows.length,
          separatorBuilder: (_, i) => AppStyle.vGap8,
          itemBuilder: (_, i) {
            final item = controller.liveEventFlows[i];
            return ListTile(
              visualDensity: VisualDensity.compact,
              contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 12),
              leading: const Icon(Remix.pulse_line),
              title: Text(
                item.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                "x${item.count}",
                style: Get.textTheme.titleMedium,
              ),
            );
          },
        );
      }),
    );
  }

  Widget buildMessageItem(LiveMessage message) {
    if (message.userName == "LiveSysMessage") {
      return Obx(
        () => Text(
          message.message,
          style: TextStyle(
            color: Colors.grey,
            fontSize: AppSettingsController.instance.chatTextSize.value,
          ),
        ),
      );
    }

    Widget buildMessageContent({
      required TextStyle userStyle,
      required TextStyle messageStyle,
    }) {
      final remark = controller.getUserRemark(message.userName);
      return _InteractiveChatText(
        userName: message.userName,
        remark: remark,
        message: message.message,
        imageUrls: AppSettingsController.instance.danmuRenderEmoji.value
            ? message.imageUrls
            : null,
        spans: AppSettingsController.instance.danmuRenderEmoji.value
            ? message.spans
            : null,
        userStyle: userStyle,
        messageStyle: messageStyle,
        onUserTap: () => controller.showUserActions(
          message.userName,
          messageContent: message.message,
        ),
        onUserLongPress: () => controller.copyUserName(message.userName),
      );
    }

    return Obx(
      () => AppSettingsController.instance.chatBubbleStyle.value
          ? Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withAlpha(25),
                      //borderRadius: AppStyle.radius8,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    padding:
                        AppStyle.edgeInsetsA4.copyWith(left: 12, right: 12),
                    child: buildMessageContent(
                      userStyle: TextStyle(
                        color: Colors.grey,
                        fontSize:
                            AppSettingsController.instance.chatTextSize.value,
                      ),
                      messageStyle: TextStyle(
                        color:
                            Get.isDarkMode ? Colors.white : AppColors.black333,
                        fontSize:
                            AppSettingsController.instance.chatTextSize.value,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : buildMessageContent(
              userStyle: TextStyle(
                color: Colors.grey,
                fontSize: AppSettingsController.instance.chatTextSize.value,
              ),
              messageStyle: TextStyle(
                color: Get.isDarkMode ? Colors.white : AppColors.black333,
                fontSize: AppSettingsController.instance.chatTextSize.value,
              ),
            ),
    );
  }

  Widget buildSuperChats() {
    return KeepAliveWrapper(
      child: Obx(
        () => controller.superChats.isEmpty
            ? AppEmptyWidget(
                message: controller.site.id == Constant.kHuya
                    ? "当前直播间无头条内容"
                    : "当前直播间无 SC 内容",
              )
            : ListView.separated(
                padding: AppStyle.edgeInsetsA12,
                itemCount: controller.superChats.length,
                separatorBuilder: (_, i) => AppStyle.vGap12,
                itemBuilder: (_, i) {
                  var item = controller.sortedSuperChats[i];
                  return SuperChatCard(
                    item,
                    remark: controller.getUserRemark(item.userName),
                    key: ValueKey(
                      item.id ??
                          "${item.userName}|${item.message}|${item.price}|${item.startTime.millisecondsSinceEpoch}",
                    ),
                    onExpire: () {
                      controller.removeSuperChats();
                    },
                    onUserTap: () => controller.showUserActions(
                      item.userName,
                      messageContent: item.message,
                    ),
                    onUserLongPress: () =>
                        controller.copyUserName(item.userName),
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
              AppStyle.divider,
              Obx(
                () => SettingsMenu<bool>(
                  title: controller.site.id == Constant.kHuya ? "头条排序" : "SC排序",
                  value: AppSettingsController.instance.superChatSortDesc.value,
                  valueMap: const {
                    false: "按消失时间正序",
                    true: "按消失时间倒序",
                  },
                  onChanged: (e) {
                    AppSettingsController.instance.setSuperChatSortDesc(e);
                    controller.superChats.refresh();
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "重点动态",
                  subtitle: "汇总短时间内重复较多的弹幕内容",
                  value:
                      AppSettingsController.instance.liveEventFlowEnable.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setLiveEventFlowEnable(e);
                    if (!e) {
                      controller.clearLiveEventFlow();
                    }
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "全屏显示重点动态",
                  subtitle: "在播放器全屏时显示当前重复弹幕摘要",
                  value: AppSettingsController
                      .instance.liveEventFlowOverlayEnable.value,
                  onChanged: AppSettingsController
                      .instance.setLiveEventFlowOverlayEnable,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态统计跨度",
                  subtitle: "多少秒内的重复弹幕合并计数",
                  value: AppSettingsController
                      .instance.liveEventFlowWindowSeconds.value,
                  min: AppSettingsController.kLiveEventFlowMinWindowSeconds,
                  max: AppSettingsController.kLiveEventFlowMaxWindowSeconds,
                  step: 5,
                  onChanged: AppSettingsController
                      .instance.setLiveEventFlowWindowSeconds,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态展示时间",
                  subtitle: "一条动态多久没有更新后自动消失",
                  value: AppSettingsController
                      .instance.liveEventFlowDisplaySeconds.value,
                  min: AppSettingsController.kLiveEventFlowMinDisplaySeconds,
                  max: AppSettingsController.kLiveEventFlowMaxDisplaySeconds,
                  step: 1,
                  onChanged: AppSettingsController
                      .instance.setLiveEventFlowDisplaySeconds,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态起显次数",
                  subtitle: "同一句重复达到多少次后进入重点动态",
                  value: AppSettingsController
                      .instance.liveEventFlowMinCount.value,
                  min: AppSettingsController.kLiveEventFlowMinCount,
                  max: AppSettingsController.kLiveEventFlowMaxCount,
                  step: 1,
                  onChanged:
                      AppSettingsController.instance.setLiveEventFlowMinCount,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "动态保留数量",
                  subtitle: "控制动态页最多保留多少条摘要",
                  value:
                      AppSettingsController.instance.liveEventFlowLimit.value,
                  min: AppSettingsController.kLiveEventFlowMinLimit,
                  max: AppSettingsController.kLiveEventFlowMaxLimit,
                  step: 50,
                  onChanged:
                      AppSettingsController.instance.setLiveEventFlowLimit,
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "重复弹幕过滤",
                  subtitle: AppSettingsController.instance.danmuDedupeStrictMode
                      ? "刷屏严父：不同用户重复发同一句也只显示一次"
                      : "普通：同一用户在最近若干条内重复发同一句只显示一次",
                  value: AppSettingsController.instance.danmuDedupeEnable.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuDedupeEnable(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsMenu<int>(
                  title: "过滤模式",
                  subtitle: "刷屏严父会忽略用户，只按弹幕内容去重",
                  value: AppSettingsController.instance.danmuDedupeMode.value,
                  valueMap: const {
                    AppSettingsController.kDanmuDedupeModeUser: "普通",
                    AppSettingsController.kDanmuDedupeModeStrict: "刷屏严父",
                  },
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuDedupeMode(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(() {
                final strictMode =
                    AppSettingsController.instance.danmuDedupeStrictMode;
                return SettingsNumber(
                  title: "过滤窗口",
                  subtitle: strictMode
                      ? "严父默认 10 条；超过 20 条可能会让弹幕明显变少"
                      : "默认 10 条；窗口越大越容易过滤刷屏",
                  value: AppSettingsController.instance.danmuDedupeWindow.value,
                  min: AppSettingsController.instance.danmuDedupeWindowMin,
                  max: AppSettingsController.kDanmuDedupeMaxWindow,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuDedupeWindow(e);
                    if (AppSettingsController.instance.danmuDedupeStrictMode &&
                        AppSettingsController.instance.danmuDedupeWindow.value >
                            AppSettingsController
                                .kDanmuDedupeStrictWarnWindow) {
                      SmartDialog.showToast("过滤窗口超过 20 条后，弹幕可能会明显变少");
                    }
                  },
                );
              }),
              Obx(() {
                if (AppSettingsController.instance.danmuDedupeStrictMode) {
                  return const SizedBox.shrink();
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppStyle.divider,
                    SettingsNumber(
                      title: "过滤步长",
                      subtitle: "默认 2；数值越大检查窗口移动越少",
                      value:
                          AppSettingsController.instance.danmuDedupeStep.value,
                      min: 1,
                      max: 20,
                      onChanged: (e) {
                        AppSettingsController.instance.setDanmuDedupeStep(e);
                      },
                    ),
                  ],
                );
              }),
              if (controller.supportsContributionRank) ...[
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: controller.site.id == Constant.kDouyu
                        ? "显示亲密榜"
                        : "显示贡献榜",
                    subtitle: "关闭后会隐藏排行榜标签页，降低对官方功能的替代感",
                    value: AppSettingsController
                        .instance.contributionRankEnable.value,
                    onChanged: (e) {
                      AppSettingsController.instance
                          .setContributionRankEnable(e);
                      if (e) {
                        controller.fetchContributionRank(forceRefresh: true);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (LiveSubtitleService.instance.uiEnabled) ...[
          Padding(
            padding: AppStyle.edgeInsetsA12,
            child: Text(
              "实时字幕",
              style: Get.textTheme.titleSmall,
            ),
          ),
          buildSubtitleSettingsCard(),
        ],
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
                title: "直播设置",
                onTap: controller.showLiveSettingsSheet,
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
    return KeepAliveWrapper(
      child: controller.buildFollowUserSelection(
        onClose: () {},
        scrollController: controller.liveRoomFollowScrollController,
      ),
    );
  }

  void showMore() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Utils.bottomSheetSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              title: const Text("切换清晰度"),
              trailing: const Icon(Icons.chevron_right),
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
            if (LiveSubtitleService.instance.uiEnabled)
              ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: const Text("实时字幕"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.back();
                  showSubtitleSettingsSheet();
                },
              ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text("观看历史"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.openHistoryPage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.interests_outlined),
              title: const Text("同类推荐"),
              subtitle: Text(controller.currentRecommendationSubtitle),
              trailing: const Icon(Icons.chevron_right),
              enabled: controller.hasCategoryRecommendation,
              onTap: !controller.hasCategoryRecommendation
                  ? null
                  : () {
                      Get.back();
                      controller.openCategoryRecommendation();
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

  Widget buildSubtitleSettingsCard() {
    if (!LiveSubtitleService.instance.uiEnabled) {
      return const SizedBox.shrink();
    }
    final settings = AppSettingsController.instance;
    return SettingsCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => SettingsSwitch(
              title: "启用实时字幕",
              subtitle:
                  "需要先选择本机模型路径，${LiveSubtitleService.instance.platformStatusLabel}",
              value: settings.liveSubtitleEnable.value,
              onChanged: (e) async {
                if (e) {
                  if (!LiveSubtitleService.instance.canStartRuntime) {
                    SmartDialog.showToast("当前平台暂不支持实时字幕识别");
                    return;
                  }
                  final hasModel = await LiveSubtitleService.instance
                      .validateModelPath(settings.liveSubtitleModelPath.value);
                  if (!hasModel) {
                    SmartDialog.showToast("请先选择有效的字幕模型路径");
                    return;
                  }
                }
                settings.setLiveSubtitleEnable(e);
                await LiveSubtitleService.instance.syncPreviewFromSettings();
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () {
              final modelPath = settings.liveSubtitleModelPath.value;
              final label = modelPath.isEmpty ? "未选择" : p.basename(modelPath);
              return SettingsAction(
                title: "模型关键文件",
                subtitle:
                    LiveSubtitleService.instance.modelPathSubtitle(modelPath),
                value: label,
                onTap: pickSubtitleModelPath,
              );
            },
          ),
          AppStyle.divider,
          SettingsAction(
            title: "模型推荐下载",
            subtitle: "按设备性能选择高级 / 中级 / 甜点级模型",
            onTap: showSubtitleModelRecommendations,
          ),
          AppStyle.divider,
          Obx(
            () => SettingsMenu<String>(
              title: "字幕语言",
              value: settings.liveSubtitleLanguage.value,
              valueMap: const {
                "auto": "自动",
                "zh": "中文",
                "en": "英语",
                "ja": "日语",
                "ko": "韩语",
              },
              onChanged: (e) async {
                settings.setLiveSubtitleLanguage(e);
                await LiveSubtitleService.instance.syncPreviewFromSettings();
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsNumber(
              title: "字幕字号",
              value: settings.liveSubtitleFontSize.value.toInt(),
              min: 12,
              max: 36,
              unit: "px",
              onChanged: (e) {
                settings.setLiveSubtitleFontSize(e.toDouble());
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsNumber(
              title: "水平位置",
              value: (settings.liveSubtitleOffsetX.value * 100).round(),
              min: 5,
              max: 95,
              unit: "%",
              onChanged: (e) {
                settings.setLiveSubtitleOffset(x: e / 100);
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsNumber(
              title: "垂直位置",
              value: (settings.liveSubtitleOffsetY.value * 100).round(),
              min: 8,
              max: 92,
              unit: "%",
              onChanged: (e) {
                settings.setLiveSubtitleOffset(y: e / 100);
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsMenu<int>(
              title: "字幕颜色",
              value: settings.liveSubtitleColor.value,
              valueMap: const {
                0xffffffff: "白色",
                0xffffeb3b: "黄色",
                0xff80cbc4: "青绿色",
                0xffffb3c7: "粉色",
                0xff111111: "黑色",
              },
              onChanged: (e) {
                settings.setLiveSubtitleColor(e);
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsMenu<int>(
              title: "字幕粗细",
              value: settings.liveSubtitleFontWeight.value,
              valueMap: const {
                4: "正常",
                5: "中等",
                6: "半粗",
                7: "加粗",
                8: "很粗",
              },
              onChanged: (e) {
                settings.setLiveSubtitleFontWeight(e);
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsSwitch(
              title: "字幕背景",
              value: settings.liveSubtitleBackgroundEnable.value,
              onChanged: (e) {
                settings.setLiveSubtitleBackgroundEnable(e);
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsSwitch(
              title: "锁定字幕位置",
              subtitle: "锁定后播放页只显示字幕，鼠标悬停时显示解锁按钮",
              value: settings.liveSubtitlePositionLocked.value,
              onChanged: (e) {
                settings.setLiveSubtitlePositionLocked(e);
              },
            ),
          ),
        ],
      ),
    );
  }

  void showSubtitleSettingsSheet() {
    if (!LiveSubtitleService.instance.uiEnabled) {
      return;
    }
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(maxWidth: 600),
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Utils.bottomSheetSafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: AppStyle.edgeInsetsA12.copyWith(
            bottom: AppStyle.bottomBarHeight,
          ),
          children: [
            Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(bottom: 8),
              child: Text(
                "实时字幕",
                style: Get.textTheme.titleMedium,
              ),
            ),
            buildSubtitleSettingsCard(),
          ],
        ),
      ),
    );
  }

  Future<void> pickSubtitleModelPath() async {
    if (!LiveSubtitleService.instance.uiEnabled) {
      return;
    }
    String? selectedPath;
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: "选择字幕模型关键 onnx 文件",
        type: FileType.custom,
        allowedExtensions: const ["onnx"],
      );
      selectedPath = result?.files.single.path;
    } catch (_) {
      selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择字幕模型文件夹",
      );
    }
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }
    final info = await LiveSubtitleService.instance.inspectModelPath(
      selectedPath,
    );
    if (info == null) {
      SmartDialog.showToast("未识别模型，请选择推荐模型的关键 onnx 文件");
      return;
    }
    if (!info.isValid) {
      SmartDialog.showToast("模型缺少：${info.missingFileNames.join("、")}");
      return;
    }
    AppSettingsController.instance.setLiveSubtitleModelPath(info.keyFilePath);
    await LiveSubtitleService.instance.syncPreviewFromSettings();
  }

  void showSubtitleModelRecommendations() {
    if (!LiveSubtitleService.instance.uiEnabled) {
      return;
    }
    Get.dialog(
      AlertDialog(
        title: const Text("字幕模型推荐"),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "选一个档位，下载该档位列出的全部文件，放到同一个文件夹；App 里选择关键 onnx 文件。其他 .weights、非 int8 onnx 和 test_wavs 不用下载。蓝奏云/百度网盘镜像链接看 README。",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              _SubtitleModelTile(
                title: "高级（高性能桌面）",
                subtitle:
                    "下载：large-v3-encoder.int8.onnx、large-v3-decoder.int8.onnx、large-v3-tokens.txt。App 里选 encoder 这个 onnx。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-large-v3",
              ),
              _SubtitleModelTile(
                title: "中级（中文直播优先）",
                subtitle:
                    "下载：model.int8.onnx、tokens.txt、config.yaml、am.mvn。App 里选 model.int8.onnx。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14",
              ),
              _SubtitleModelTile(
                title: "甜点级（先试这个）",
                subtitle:
                    "下载：encoder-epoch-99-avg-1.int8.onnx、decoder-epoch-99-avg-1.int8.onnx、joiner-epoch-99-avg-1.int8.onnx、tokens.txt、bpe.model、bpe.vocab。App 里选 encoder 这个 onnx。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
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

class _SubtitleModelTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;

  const _SubtitleModelTile({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () {
        launchUrlString(url, mode: LaunchMode.externalApplication);
      },
    );
  }
}

class _InteractiveChatText extends StatelessWidget {
  static final RegExp _emojiTokenPattern = RegExp(r'\[[^\[\]]{1,16}\]');

  final String userName;
  final String? remark;
  final String message;
  final List<String>? imageUrls;
  final List<LiveMessageSpan>? spans;
  final TextStyle userStyle;
  final TextStyle messageStyle;
  final VoidCallback onUserTap;
  final VoidCallback onUserLongPress;

  const _InteractiveChatText({
    required this.userName,
    this.remark,
    required this.message,
    this.imageUrls,
    this.spans,
    required this.userStyle,
    required this.messageStyle,
    required this.onUserTap,
    required this.onUserLongPress,
  });

  TextSpan _buildTextSpan() {
    final richSpans = spans ?? const <LiveMessageSpan>[];
    return TextSpan(
      style: messageStyle,
      children: [
        TextSpan(
          text: '$userName：',
          style: userStyle,
        ),
        if ((remark ?? "").trim().isNotEmpty)
          TextSpan(
            text: '[${remark!.trim()}] ',
            style: userStyle.copyWith(
              color: userStyle.color?.withAlpha(180),
              fontSize: (userStyle.fontSize ?? 14) - 1,
            ),
          ),
        if (richSpans.isNotEmpty)
          for (final span in richSpans)
            if (span.isText)
              TextSpan(text: span.text)
            else if (span.isImage)
              _buildImageSpan(span.imageUrl!.trim()),
        if (richSpans.isEmpty) ...[
          ..._buildFallbackContentSpans(),
        ],
      ],
    );
  }

  List<InlineSpan> _buildFallbackContentSpans() {
    final urls = (imageUrls ?? const <String>[])
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      return [TextSpan(text: message)];
    }

    final result = <InlineSpan>[];
    var start = 0;
    var imageIndex = 0;
    for (final match in _emojiTokenPattern.allMatches(message)) {
      if (imageIndex >= urls.length) {
        break;
      }
      if (match.start > start) {
        result.add(TextSpan(text: message.substring(start, match.start)));
      }
      result.add(_buildImageSpan(urls[imageIndex]));
      imageIndex += 1;
      start = match.end;
    }
    if (start < message.length) {
      result.add(TextSpan(text: message.substring(start)));
    }
    for (; imageIndex < urls.length; imageIndex += 1) {
      result.add(_buildImageSpan(urls[imageIndex]));
    }
    return result;
  }

  WidgetSpan _buildImageSpan(String url) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: NetImage(
          url,
          width: (messageStyle.fontSize ?? 14) * 1.35,
          height: (messageStyle.fontSize ?? 14) * 1.35,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSpan = _buildTextSpan();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onUserTap,
      onLongPress: onUserLongPress,
      child: Text.rich(
        textSpan,
        softWrap: true,
        textWidthBasis: TextWidthBasis.parent,
      ),
    );
  }
}
