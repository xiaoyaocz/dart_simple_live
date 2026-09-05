import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_controller.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_player_controller.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class MultiRoomPage extends GetView<MultiRoomController> {
  const MultiRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                autofocus: true,
                onTap: Get.back,
              ),
              AppStyle.hGap32,
              Obx(
                () => Text(
                  "多屏同播（${controller.rooms.length}）",
                  style: AppStyle.titleStyleWhite.copyWith(
                    fontSize: 36.w,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.refresh,
                text: "全部刷新",
                onTap: () {
                  for (final room in controller.rooms) {
                    controller.playerFor(room).refreshRoom();
                  }
                },
              ),
              AppStyle.hGap48,
            ],
          ),
          AppStyle.vGap24,
          Expanded(
            child: Obx(
              () => LayoutBuilder(
                builder: (context, constraints) {
                  final count = _gridCount(controller.rooms.length);
                  final gap =
                      AppSettingsController.instance.effectiveMultiRoomGap;
                  final scaledGap = gap.w;
                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      scaledGap,
                      0,
                      scaledGap,
                      scaledGap,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      childAspectRatio: 16 / 9,
                      crossAxisSpacing: scaledGap,
                      mainAxisSpacing: scaledGap,
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
          ),
        ],
      ),
    );
  }

  int _gridCount(int length) {
    if (length <= 1) {
      return 1;
    }
    if (length <= 4) {
      return 2;
    }
    return 3;
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
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          controller.toggleMute();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
            event.logicalKey == LogicalKeyboardKey.keyM) {
          onRemove();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ClipRRect(
        borderRadius: AppStyle.radius16,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white24),
            borderRadius: AppStyle.radius16,
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.w),
                  color: Colors.black.withAlpha(160),
                  child: Obx(
                    () => Text(
                      "${item.site.name} · ${controller.title}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 24.w),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12.w,
                bottom: 10.w,
                child: Obx(
                  () => Text(
                    [
                      if (controller.qualityInfo.value.isNotEmpty)
                        controller.qualityInfo.value,
                      if (controller.lineInfo.value.isNotEmpty)
                        controller.lineInfo.value,
                      controller.muted.value ? "静音" : "有声",
                    ].join(" · "),
                    style: TextStyle(color: Colors.white70, fontSize: 20.w),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        padding: AppStyle.edgeInsetsA16,
        color: Colors.black.withAlpha(160),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24.w),
        ),
      ),
    );
  }
}
