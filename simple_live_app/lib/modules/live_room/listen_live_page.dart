import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/widgets/mobile_page_insets.dart';

/// 听直播模式：纯音频页面。
/// 禁用视频轨只保留音频，隐藏弹幕与视频，Android 前台服务无条件保持，
/// 息屏/切后台都能持续收听；自带独立的听直播定时关闭。
class ListenLivePage extends StatefulWidget {
  const ListenLivePage({super.key});

  @override
  State<ListenLivePage> createState() => _ListenLivePageState();
}

class _ListenLivePageState extends State<ListenLivePage> {
  late final LiveRoomController controller = Get.find<LiveRoomController>();

  @override
  void dispose() {
    // 无论从哪种路径离开听直播页，都恢复视频轨与弹幕
    if (controller.listenMode.value) {
      controller.exitListenMode();
    }
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = seconds % 60;
    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}";
    }
    return "$minutes:${rest.toString().padLeft(2, '0')}";
  }

  Future<void> _pickCustomMinutes() async {
    final value = await showTimePicker(
      context: Get.context!,
      initialTime: const TimeOfDay(hour: 1, minute: 0),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (_, child) {
        return MediaQuery(
          data: Get.mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (value == null || (value.hour == 0 && value.minute == 0)) {
      return;
    }
    controller.setListenExitTimer(value.hour * 60 + value.minute);
  }

  void _showListenTimerSheet() {
    final current = controller.listenExitTotalMinutes.value;
    Widget buildOption(int minutes) {
      return ListTile(
        title: Text(minutes == 0 ? "不关闭" : "$minutes 分钟"),
        trailing:
            current == minutes ? const Icon(Icons.check_circle_rounded) : null,
        onTap: () {
          controller.setListenExitTimer(minutes);
          Get.back();
        },
      );
    }

    Utils.showBottomSheet(
      title: "听直播定时关闭",
      child: ListView(
        shrinkWrap: true,
        children: [
          buildOption(0),
          buildOption(30),
          buildOption(60),
          buildOption(90),
          buildOption(120),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("自定义时长"),
            trailing: current > 0 &&
                    const [0, 30, 60, 90, 120].contains(current) == false
                ? const Icon(Icons.check_circle_rounded)
                : null,
            onTap: () {
              Get.back();
              _pickCustomMinutes();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageInsets(child: Builder(builder: _buildContent));
  }

  Widget _buildContent(BuildContext context) {
    final detail = controller.detail.value;
    final siteName = controller.rxSite.value.name;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B1C22),
              Color(0xFF2A2C35),
              Color(0xFF1B1C22),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── 顶栏：回到视频 / 定时关闭 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: "回到视频画面",
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 30,
                      ),
                      onPressed: Get.back,
                    ),
                    Text(
                      "正在听直播",
                      style: Get.textTheme.labelLarge
                          ?.copyWith(color: Colors.white54),
                    ),
                    const Spacer(),
                    Obx(
                      () {
                        final countdown = controller.listenExitCountdown.value;
                        return TextButton.icon(
                          onPressed: _showListenTimerSheet,
                          icon: Icon(
                            Icons.timer_outlined,
                            color: countdown > 0
                                ? Colors.tealAccent[200]
                                : Colors.white70,
                          ),
                          label: Text(
                            countdown > 0 ? _formatCountdown(countdown) : "定时",
                            style: Get.textTheme.labelLarge?.copyWith(
                              color: countdown > 0
                                  ? Colors.tealAccent[200]
                                  : Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // ── 主播信息 ──
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white12,
                  backgroundImage: (detail?.userAvatar.isNotEmpty ?? false)
                      ? NetworkImage(detail!.userAvatar)
                      : null,
                  child: (detail?.userAvatar.isNotEmpty ?? false)
                      ? null
                      : const Icon(
                          Icons.headset_outlined,
                          size: 48,
                          color: Colors.white54,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                detail?.userName ?? siteName,
                style: Get.textTheme.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "$siteName · ${detail?.introduction?.isNotEmpty ?? false ? detail!.introduction : "音频模式播放中"}",
                style:
                    Get.textTheme.bodyMedium?.copyWith(color: Colors.white60),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Obx(
                () {
                  final live = controller.liveStatus.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: live ? Colors.greenAccent : Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          live ? "直播中" : "未开播",
                          style: Get.textTheme.labelMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(flex: 3),
              // ── 播放控制 ──
              StreamBuilder<bool>(
                stream: controller.player.stream.playing,
                initialData: controller.player.state.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _controlButton(
                        icon: playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 76,
                        onTap: () async {
                          if (playing) {
                            await controller.player.pause();
                          } else {
                            await controller.player.play();
                          }
                          unawaited(controller.syncBackgroundPlayback());
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                "退出听直播回到视频画面",
                style:
                    Get.textTheme.labelSmall?.copyWith(color: Colors.white38),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: size, color: Colors.white),
        ),
      ),
    );
  }
}
