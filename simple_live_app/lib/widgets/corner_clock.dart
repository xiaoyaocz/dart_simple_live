import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

/// 全屏直播间四角时钟
/// 常驻显示在画面角落，不随控制栏显隐消失；开关关闭时隐藏，仅在挂载于全屏层时运行。
class CornerClock extends StatefulWidget {
  /// 安全区边距（避开刘海、桌面任务栏等），与全屏控制栏同源
  final EdgeInsets safeArea;

  const CornerClock({
    required this.safeArea,
    Key? key,
  }) : super(key: key);

  @override
  State<CornerClock> createState() => _CornerClockState();
}

class _CornerClockState extends State<CornerClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onTick(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) {
      return;
    }
    // 关闭时不刷新
    if (!AppSettingsController.instance.playerClockEnable.value) {
      return;
    }
    final now = DateTime.now();
    // HH:mm 每分钟才变化一次，无需每秒重建
    if (_format(now) != _format(_now)) {
      setState(() {
        _now = now;
      });
    }
  }

  String _format(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Alignment _alignment(int position) {
    switch (position) {
      case AppSettingsController.kPlayerClockPositionTopLeft:
        return Alignment.topLeft;
      case AppSettingsController.kPlayerClockPositionBottomLeft:
        return Alignment.bottomLeft;
      case AppSettingsController.kPlayerClockPositionBottomRight:
        return Alignment.bottomRight;
      default:
        return Alignment.topRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;
    return Obx(
      () {
        if (!settings.playerClockEnable.value) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Align(
            alignment: _alignment(settings.playerClockPosition.value),
            child: Padding(
              padding: widget.safeArea + const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _format(_now),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
