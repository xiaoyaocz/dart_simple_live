import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_controller.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_player_controller.dart';

class MultiRoomPage extends GetView<MultiRoomController> {
  const MultiRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Obx(() => Text("多开同屏（${controller.rooms.length}）")),
        actions: [
          IconButton(
            tooltip: "全部刷新",
            onPressed: () {
              for (final room in controller.rooms) {
                controller.playerFor(room).refreshRoom();
              }
            },
            icon: const Icon(Remix.refresh_line),
          ),
        ],
      ),
      body: Obx(
        () => LayoutBuilder(
          builder: (context, constraints) {
            final count = _gridCount(
              controller.rooms.length,
              constraints.maxWidth,
            );
            final gap = AppSettingsController.instance.effectiveMultiRoomGap;
            return GridView.builder(
              padding: EdgeInsets.all(gap.toDouble()),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                childAspectRatio: 16 / 9,
                mainAxisSpacing: gap.toDouble(),
                crossAxisSpacing: gap.toDouble(),
              ),
              itemCount: controller.rooms.length,
              itemBuilder: (context, index) {
                final room = controller.rooms[index];
                return _MultiRoomTile(
                  item: room,
                  controller: controller.playerFor(room),
                  onRemove: () => controller.removeRoom(room),
                );
              },
            );
          },
        ),
      ),
    );
  }

  int _gridCount(int length, double width) {
    if (length <= 1) {
      return 1;
    }
    if (width >= 1400 && length >= 3) {
      return 3;
    }
    if (width >= 760) {
      return 2;
    }
    return 1;
  }
}

class _MultiRoomTile extends StatelessWidget {
  final MultiRoomItem item;
  final MultiRoomPlayerController controller;
  final VoidCallback onRemove;

  const _MultiRoomTile({
    required this.item,
    required this.controller,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppStyle.radius8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.white24),
          borderRadius: AppStyle.radius8,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Video(
                controller: controller.videoController,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
            ),
            Positioned.fill(
              child: Obx(
                () {
                  if (controller.loading.value) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (controller.errorText.value.isNotEmpty) {
                    return _CenterText(controller.errorText.value);
                  }
                  if (!controller.liveStatus.value) {
                    return const _CenterText("未开播");
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.black.withAlpha(150),
                child: Obx(
                  () => Text(
                    "${item.site.name} · ${controller.title}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Obx(
                () => Text(
                  [
                    if (controller.qualityInfo.value.isNotEmpty)
                      controller.qualityInfo.value,
                    if (controller.lineInfo.value.isNotEmpty)
                      controller.lineInfo.value,
                  ].join(" · "),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayButton(
                    tooltip: "刷新",
                    icon: Remix.refresh_line,
                    onPressed: controller.refreshRoom,
                  ),
                  Obx(
                    () => _OverlayButton(
                      tooltip: controller.muted.value ? "取消静音" : "静音",
                      icon: controller.muted.value
                          ? Remix.volume_mute_line
                          : Remix.volume_up_line,
                      onPressed: controller.toggleMute,
                    ),
                  ),
                  _OverlayButton(
                    tooltip: "移除",
                    icon: Remix.close_line,
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _OverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withAlpha(150),
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _CenterText extends StatelessWidget {
  final String text;

  const _CenterText(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: AppStyle.edgeInsetsA8,
        color: Colors.black.withAlpha(150),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
