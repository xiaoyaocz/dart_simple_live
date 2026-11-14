import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/iptv/player/iptv_player_controller.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

class IptvPlayerPage extends GetView<IptvPlayerController> {
  const IptvPlayerPage({super.key});

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
                child: Video(controller: controller.videoController, controls: NoVideoControls),
              ),
              Obx(
                () => AnimatedOpacity(
                  opacity: controller.controlsVisible.value ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(child: _buildControls()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onKeyEvent(KeyEvent key) {
    if (key is KeyUpEvent) return;
    final logical = key.logicalKey;

    if (logical == LogicalKeyboardKey.escape || logical == LogicalKeyboardKey.backspace) {
      Get.back();
      return;
    }
    if (logical == LogicalKeyboardKey.mediaPlayPause || logical == LogicalKeyboardKey.select) {
      controller.togglePlayPause();
      return;
    }
    if (logical == LogicalKeyboardKey.audioVolumeUp) {
      controller.setVolume((controller.currentVolume.value + 5).clamp(0, 100));
      return;
    }
    if (logical == LogicalKeyboardKey.audioVolumeDown) {
      controller.setVolume((controller.currentVolume.value - 5).clamp(0, 100));
      return;
    }
    if (logical == LogicalKeyboardKey.arrowUp || logical == LogicalKeyboardKey.arrowLeft) {
      controller.switchChannel(-1);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowDown) {
      controller.switchChannel(1);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowRight || logical == LogicalKeyboardKey.contextMenu) {
      _showLineSelector();
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
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(controller.currentTitle.value, style: AppStyle.titleStyleWhite),
                  Text(
                    "来源：${controller.currentChannel.sourceNames.join("、")}",
                    style: AppStyle.subTextStyleWhite,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          Row(
            children: [
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.skip_previous,
                text: "上一台",
                onTap: () => controller.switchChannel(-1),
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.dns,
                text: "线路选择",
                onTap: _showLineSelector,
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.skip_next,
                text: "下一台",
                onTap: () => controller.switchChannel(1),
              ),
              const Spacer(),
              Icon(Icons.volume_up, color: Colors.white, size: 32.w),
              AppStyle.hGap8,
              Obx(
                () => Text("${controller.currentVolume.value.toInt()}", style: AppStyle.textStyleWhite),
              ),
            ],
          ),
          AppStyle.vGap16,
          Text(
            "上下键切台 · 左右键/菜单键打开线路选择 · 音量键调整音量 · OK键暂停播放",
            style: AppStyle.subTextStyleWhite,
          ),
        ],
      ),
    );
  }

  void _showLineSelector() {
    showModalBottomSheet(
      context: Get.context!,
      builder: (context) => ListView.separated(
        padding: AppStyle.edgeInsetsA32,
        itemCount: controller.currentChannel.lines.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final line = controller.currentChannel.lines[index];
          final selected = index == controller.currentLineIndex;
          return ListTile(
            leading: NetImage(line.logo, width: 48.w, height: 48.w, borderRadius: 8),
            title: Text(line.sourceName, style: AppStyle.textStyleWhite),
            trailing: selected ? Icon(Icons.check, color: Colors.white, size: 32.w) : null,
            onTap: () {
              controller.switchLine(index);
              Get.back();
            },
          );
        },
      ),
    );
  }
}
