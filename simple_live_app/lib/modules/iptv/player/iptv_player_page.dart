import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/iptv/player/iptv_player_controller.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class IptvPlayerPage extends GetView<IptvPlayerController> {
  const IptvPlayerPage({Key? key}) : super(key: key);

  static final DateFormat _timeFormat = DateFormat("HH:mm");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Video(
              controller: controller.videoController,
              controls: NoVideoControls,
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: controller.toggleControls,
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

  // 顶部：返回与频道名
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: AppStyle.edgeInsetsH8.add(
        EdgeInsets.only(top: AppStyle.statusBarHeight),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          AppStyle.hGap8,
          Expanded(
            child: Obx(
              () => Text(
                controller.currentTitle.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  }

  // 底部：EPG 信息与切台
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: AppStyle.edgeInsetsH12.add(
        EdgeInsets.only(bottom: AppStyle.bottomBarHeight + 8),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEpg(context),
          AppStyle.vGap12,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                style: _lightButton,
                onPressed: controller.currentIndex > 0
                    ? () => controller.switchChannel(-1)
                    : null,
                icon: const Icon(Icons.skip_previous),
                label: const Text("上一台"),
              ),
              AppStyle.hGap16,
              OutlinedButton.icon(
                style: _lightButton,
                onPressed: controller.currentIndex < controller.items.length - 1
                    ? () => controller.switchChannel(1)
                    : null,
                icon: const Icon(Icons.skip_next),
                label: const Text("下一台"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpg(BuildContext context) {
    return Obx(() {
      final now = controller.nowProgram.value;
      final next = controller.nextProgram.value;
      if (now == null && next == null) {
        return Text(
          controller.loadingEpg.value ? "节目单加载中…" : "暂无节目单信息",
          style: const TextStyle(color: Colors.white70),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (now != null)
            Text(
              "正在播出：${now.title}（${_span(now.start, now.stop)}）",
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (next != null)
            Text(
              "稍后 ${_timeFormat.format(next.start.toLocal())}：${next.title}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    });
  }

  // 频道选择列表
  void _showChannelList(BuildContext context) {
    Utils.showBottomSheet(
      title: "频道列表",
      child: ListView.separated(
        itemCount: controller.items.length,
        separatorBuilder: (_, __) => AppStyle.divider,
        itemBuilder: (_, index) {
          final item = controller.items[index];
          final active = index == controller.currentIndex;
          return ListTile(
            selected: active,
            leading: NetImage(item.logo, width: 36, height: 36, borderRadius: 8),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

  String _span(DateTime start, DateTime stop) {
    return "${_timeFormat.format(start.toLocal())}-${_timeFormat.format(stop.toLocal())}";
  }

  ButtonStyle get _lightButton => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
      );
}
