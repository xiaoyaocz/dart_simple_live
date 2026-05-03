import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SuperChatCard extends StatefulWidget {
  final LiveSuperChatMessage message;
  final String? remark;
  final Function()? onExpire;
  final int? customCountdown;
  final VoidCallback? onUserTap;
  final VoidCallback? onUserLongPress;

  const SuperChatCard(
    this.message, {
    this.remark,
    required this.onExpire,
    this.customCountdown,
    this.onUserTap,
    this.onUserLongPress,
    Key? key,
  }) : super(key: key);

  @override
  State<SuperChatCard> createState() => _SuperChatCardState();
}

class _SuperChatCardState extends State<SuperChatCard> {
  Timer? timer;
  int countdown = 0;

  @override
  void initState() {
    super.initState();
    _restartCountdown();
  }

  int _resolveCountdown() {
    if (widget.customCountdown != null) {
      return widget.customCountdown!.clamp(0, 1 << 30).toInt();
    }
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final endTime = widget.message.endTime.millisecondsSinceEpoch ~/ 1000;
    return (endTime - currentTime).clamp(0, 1 << 30).toInt();
  }

  void _restartCountdown() {
    timer?.cancel();
    countdown = _resolveCountdown();
    if (widget.customCountdown != null || countdown <= 0) {
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), timerCallback);
  }

  @override
  void didUpdateWidget(covariant SuperChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.customCountdown != widget.customCountdown) {
      _restartCountdown();
    }
  }

  void timerCallback(Timer _) {
    if (countdown <= 0) {
      widget.onExpire?.call();
      timer?.cancel();
      return;
    }

    setState(() {
      countdown = (countdown - 1).clamp(0, 1 << 30).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayCountdown = (widget.customCountdown ?? countdown)
        .clamp(
          0,
          1 << 30,
        )
        .toInt();
    return ClipRRect(
      borderRadius: AppStyle.radius8,
      child: Container(
        decoration: BoxDecoration(
          color: Utils.convertHexColor(widget.message.backgroundColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppStyle.edgeInsetsA8,
              child: Row(
                children: [
                  NetImage(
                    widget.message.face,
                    width: 48,
                    height: 48,
                    borderRadius: 36,
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: widget.onUserTap,
                          onLongPress: widget.onUserLongPress,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: widget.message.userName),
                                if ((widget.remark ?? "").trim().isNotEmpty)
                                  TextSpan(
                                    text: " [${widget.remark!.trim()}]",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            style: const TextStyle(
                              color: AppColors.black333,
                            ),
                          ),
                        ),
                        Text(
                          "￥${widget.message.price}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "$displayCountdown",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color:
                    Utils.convertHexColor(widget.message.backgroundBottomColor),
              ),
              padding: AppStyle.edgeInsetsA8,
              child: Text(
                widget.message.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
