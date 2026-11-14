import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/iptv/player/iptv_player_controller.dart';
import 'package:simple_live_app/services/iptv_service.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class IptvPlayerPage extends GetView<IptvPlayerController> {
  const IptvPlayerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 桌面端鼠标移动自动呼出控制栏，无需点击，5秒无操作自动隐藏
      body: MouseRegion(
        onHover: (_) => controller.showControls(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Video(controller: controller.videoController, controls: NoVideoControls),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.toggleControls,
                onDoubleTap: controller.onDoubleTap,
                onLongPress: controller.onLongPress,
              ),
            ),
            Obx(
              () => AnimatedOpacity(
                opacity: controller.controlsVisible.value ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !controller.controlsVisible.value,
                  child: _buildControls(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(context),
        const Spacer(),
        _buildBottomBar(context),
      ],
    );
  }

  // 顶部栏：桌面端仅此处可拖动窗口，展示频道与源信息
  Widget _buildTopBar(BuildContext context) {
    final content = Container(
      padding: AppStyle.edgeInsetsH8.add(EdgeInsets.only(top: AppStyle.statusBarHeight)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back, color: Colors.white)),
          IconButton(onPressed: controller.reloadCurrent, icon: const Icon(Icons.refresh, color: Colors.white)),
          AppStyle.hGap8,
          Expanded(
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.currentTitle.value,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "来源：${controller.currentChannel.sourceNames.join("、")}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: "频道列表",
            onPressed: () => _showChannelList(context),
            icon: const Icon(Icons.view_list, color: Colors.white),
          ),
        ],
      ),
    );
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DragToMoveArea(child: content);
    }
    return content;
  }

  // 底部控制栏：对齐普通直播，包含播放、切台、线路、音量、全屏
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: AppStyle.edgeInsetsH12.add(EdgeInsets.only(bottom: AppStyle.bottomBarHeight + 8)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Obx(() => IconButton(
                icon: Icon(
                  controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: controller.togglePlayPause,
              )),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: controller.currentIndex > 0 ? () => controller.switchChannel(-1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: controller.currentIndex < controller.channels.length - 1
                    ? () => controller.switchChannel(1) : null,
              ),
              AppStyle.hGap16,
              // 线路选择按钮
              TextButton.icon(
                icon: const Icon(Icons.dns, color: Colors.white),
                label: const Text("线路选择", style: TextStyle(color: Colors.white)),
                onPressed: () => _showLineSelector(context),
              ),
              const Spacer(),
              // 音量滑块：上限随「音量增强」开关在 300/100 间切换
              const Icon(Icons.volume_up, color: Colors.white),
              SizedBox(
                width: 120,
                child: Obx(
                  () => Slider(
                    value: controller.currentVolume.value
                        .clamp(0, controller.volumeLimit),
                    min: 0,
                    max: controller.volumeLimit,
                    onChanged: controller.setVolume,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: controller.onDoubleTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 线路选择弹窗，展示所有可用线路，标注源名称
  void _showLineSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.separated(
        padding: AppStyle.edgeInsetsA12,
        itemCount: controller.currentChannel.lines.length,
        separatorBuilder: (_, __) => AppStyle.divider,
        itemBuilder: (_, index) {
          final line = controller.currentChannel.lines[index];
          final selected = index == controller.currentLineIndex;
          return ListTile(
            leading: NetImage(line.logo, width: 36, height: 36, borderRadius: 8),
            title: Text(line.sourceName),
            trailing: selected
                ? const Icon(Icons.check)
                : _lineStatusDot(line.url),
            onTap: () {
              controller.switchLine(index);
              Get.back();
            },
          );
        },
      ),
    );
  }

  /// 线路连通状态圆点：复用频道页红黄绿探测缓存，未检测过不显示
  Widget? _lineStatusDot(String url) {
    final status = IptvService.instance.freshLineStatus(url);
    final color = switch (status) {
      1 => Colors.green,
      2 => Colors.amber,
      3 => Colors.red,
      _ => null,
    };
    if (color == null) return null;
    return Icon(Icons.circle, color: color, size: 12);
  }

  void _showChannelList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.separated(
        padding: AppStyle.edgeInsetsA12,
        itemCount: controller.channels.length,
        separatorBuilder: (_, __) => AppStyle.divider,
        itemBuilder: (_, index) {
          final ch = controller.channels[index];
          final active = index == controller.currentIndex;
          return ListTile(
            leading: NetImage(ch.logo, width: 36, height: 36, borderRadius: 8),
            title: Text(ch.name),
            subtitle: Text("共${ch.lines.length}条线路 · ${ch.sourceNames.join("、")}"),
            trailing: active ? const Icon(Icons.play_arrow) : null,
            onTap: () {
              controller.play(index);
              Get.back();
            },
          );
        },
      ),
    );
  }
}
