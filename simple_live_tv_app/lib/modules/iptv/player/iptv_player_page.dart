import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/iptv/player/iptv_player_controller.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

class IptvPlayerPage extends GetView<IptvPlayerController> {
  const IptvPlayerPage({super.key});

  static final DateFormat _timeFormat = DateFormat("HH:mm");

  // LogicalKeyboardKey 重写了 == 与 hashCode，不能作为 const map 的键
  static final Map<LogicalKeyboardKey, String> _digitKeys = {
    LogicalKeyboardKey.digit0: "0",
    LogicalKeyboardKey.digit1: "1",
    LogicalKeyboardKey.digit2: "2",
    LogicalKeyboardKey.digit3: "3",
    LogicalKeyboardKey.digit4: "4",
    LogicalKeyboardKey.digit5: "5",
    LogicalKeyboardKey.digit6: "6",
    LogicalKeyboardKey.digit7: "7",
    LogicalKeyboardKey.digit8: "8",
    LogicalKeyboardKey.digit9: "9",
    LogicalKeyboardKey.numpad0: "0",
    LogicalKeyboardKey.numpad1: "1",
    LogicalKeyboardKey.numpad2: "2",
    LogicalKeyboardKey.numpad3: "3",
    LogicalKeyboardKey.numpad4: "4",
    LogicalKeyboardKey.numpad5: "5",
    LogicalKeyboardKey.numpad6: "6",
    LogicalKeyboardKey.numpad7: "7",
    LogicalKeyboardKey.numpad8: "8",
    LogicalKeyboardKey.numpad9: "9",
  };

  static String? _digitOf(LogicalKeyboardKey key) => _digitKeys[key];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.back();
      },
      child: KeyboardListener(
        focusNode: controller.focusNode,
        autofocus: true,
        onKeyEvent: onKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: controller.videoController,
                  controls: NoVideoControls,
                ),
              ),
              // 缓冲转圈
              Center(
                child: StreamBuilder<bool>(
                  stream: controller.player.stream.buffering,
                  initialData: controller.player.state.buffering,
                  builder: (_, snapshot) => Visibility(
                    visible: snapshot.data ?? false,
                    child: SizedBox(
                      width: 64.w,
                      height: 64.w,
                      child: const CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ),
              // 暂停提示
              Obx(
                () => Visibility(
                  visible: controller.userPaused.value,
                  child: Center(
                    child: Icon(Icons.pause_circle_outline,
                        color: Colors.white, size: 96.w),
                  ),
                ),
              ),
              // 控制栏（纯信息展示，操作走按键与频道列表对话框）
              Obx(
                () => AnimatedOpacity(
                  opacity: controller.controlsVisible.value ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(child: _buildControls()),
                ),
              ),
              // 数字跳台 OSD
              Obx(() {
                final number = controller.channelNumberInput.value;
                if (number.isEmpty) return const SizedBox.shrink();
                return Center(
                  child: Container(
                    padding: AppStyle.edgeInsetsA32,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: AppStyle.radius16,
                    ),
                    child: Text(
                      number,
                      style: AppStyle.titleStyleWhite.copyWith(
                        fontSize: 80.w,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void onKeyEvent(KeyEvent key) {
    if (key is KeyUpEvent) return;

    final logical = key.logicalKey;
    // 数字键：直接跳台（中央 OSD 显示已输频道号）
    final digit = _digitOf(logical);
    if (digit != null) {
      controller.appendChannelDigit(digit);
      return;
    }
    controller.clearChannelNumber();
    // 退出
    if (logical == LogicalKeyboardKey.escape ||
        logical == LogicalKeyboardKey.backspace ||
        logical == LogicalKeyboardKey.goBack ||
        logical == LogicalKeyboardKey.browserBack) {
      Get.back();
      return;
    }
    // 播放/暂停
    if (logical == LogicalKeyboardKey.mediaPlayPause ||
        logical == LogicalKeyboardKey.mediaPlay ||
        logical == LogicalKeyboardKey.mediaPause) {
      controller.togglePlayPause();
      return;
    }
    // 音量
    if (logical == LogicalKeyboardKey.audioVolumeUp) {
      controller.adjustVolume(5);
      return;
    }
    if (logical == LogicalKeyboardKey.audioVolumeDown) {
      controller.adjustVolume(-5);
      return;
    }
    // OK 键：显隐控制栏
    if (logical == LogicalKeyboardKey.select ||
        logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.space) {
      controller.toggleControls();
      return;
    }
    // 菜单键或右键：频道列表
    if (logical == LogicalKeyboardKey.contextMenu ||
        logical == LogicalKeyboardKey.arrowRight) {
      showChannelList();
      return;
    }
    // 上/左键：上一台；下键：下一台
    if (logical == LogicalKeyboardKey.arrowUp ||
        logical == LogicalKeyboardKey.arrowLeft) {
      controller.switchChannel(-1);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowDown) {
      controller.switchChannel(1);
    }
  }

  Widget _buildControls() {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        _buildBottomBar(),
      ],
    );
  }

  // 顶部：频道名与收藏状态
  Widget _buildTopBar() {
    return Container(
      padding: AppStyle.edgeInsetsA32,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.live_tv, color: Colors.white, size: 40.w),
          AppStyle.hGap16,
          Expanded(
            child: Obx(
              () => Text(
                controller.currentTitle.value,
                style: AppStyle.titleStyleWhite,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Obx(
            () {
              controller.favoriteVersion.value;
              return Icon(
                controller.isFavorite ? Icons.star : Icons.star_border,
                color: Colors.white,
                size: 36.w,
              );
            },
          ),
        ],
      ),
    );
  }

  // 底部：EPG 与按键提示
  Widget _buildBottomBar() {
    return Container(
      padding: AppStyle.edgeInsetsA32,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEpg(),
          AppStyle.vGap16,
          Text(
            "上/下键切台 · 数字键直接跳台 · 右键或菜单键打开频道列表 · OK 隐藏信息栏",
            style: AppStyle.subTextStyleWhite,
          ),
        ],
      ),
    );
  }

  Widget _buildEpg() {
    return Obx(() {
      final now = controller.nowProgram.value;
      final next = controller.nextProgram.value;
      if (now == null && next == null) {
        return Text(
          controller.loadingEpg.value ? "节目单加载中…" : "暂无节目单信息",
          style: AppStyle.subTextStyleWhite,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (now != null)
            Text(
              "正在播出：${now.title}（${_span(now.start, now.stop)}）",
              style: AppStyle.textStyleWhite,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (next != null)
            Text(
              "稍后 ${_timeFormat.format(next.start.toLocal())}：${next.title}",
              style: AppStyle.subTextStyleWhite,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    });
  }

  // 频道列表对话框：承载选择播放与收藏的焦点操作
  void showChannelList() {
    controller.focusNode.unfocus();
    final scrollController = ScrollController();
    final currentFocus = AppFocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        final offset = (controller.currentIndex * 110.w)
            .clamp(0.0, scrollController.position.maxScrollExtent);
        scrollController.jumpTo(offset);
      }
      currentFocus.requestFocus();
    });

    Utils.showSystemRightDialog(
      width: 720.w,
      child: Column(
        children: [
          AppStyle.vGap24,
          Row(
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                onTap: Get.back,
              ),
              AppStyle.hGap32,
              Text(
                "频道列表",
                style: AppStyle.titleStyleWhite
                    .copyWith(fontSize: 36.w, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppStyle.vGap16,
          Expanded(
            child: Obx(
              () {
                controller.favoriteVersion.value;
                return ListView.builder(
                  controller: scrollController,
                  padding: AppStyle.edgeInsetsA32,
                  itemExtent: 110.w,
                  itemCount: controller.items.length,
                  itemBuilder: (_, index) =>
                      _buildChannelRow(index, currentFocus),
                );
              },
            ),
          ),
        ],
      ),
    ).then((_) {
      scrollController.dispose();
      currentFocus.dispose();
      controller.focusNode.requestFocus();
    });
  }

  Widget _buildChannelRow(int index, AppFocusNode currentFocus) {
    final item = controller.items[index];
    final active = index == controller.currentIndex;
    final fav = controller.isItemFavorite(item);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.w),
      child: Row(
        children: [
          Expanded(
            child: HighlightListTile(
              focusNode: active ? currentFocus : AppFocusNode(),
              autofocus: active,
              leading: NetImage(item.logo,
                  width: 48.w, height: 48.w, borderRadius: 8),
              title: item.name,
              subtitle: item.group,
              onTap: () {
                controller.play(index);
                Get.back();
              },
            ),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: fav ? Icons.star : Icons.star_border,
            text: fav ? "已收藏" : "收藏",
            onTap: () => controller.toggleItemFavorite(item),
          ),
        ],
      ),
    );
  }

  String _span(DateTime start, DateTime stop) {
    return "${_timeFormat.format(start.toLocal())}-${_timeFormat.format(stop.toLocal())}";
  }
}
