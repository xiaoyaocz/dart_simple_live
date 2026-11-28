import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:simple_live_app/services/room_startup_cache.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// 只在明确的观看意图后准备接口，避免列表滚动时批量取流。
class RoomEntryWarmup extends StatefulWidget {
  final LiveSite source;
  final String roomId;
  final Widget child;
  const RoomEntryWarmup(
      {super.key,
      required this.source,
      required this.roomId,
      required this.child});
  @override
  State<RoomEntryWarmup> createState() => _RoomEntryWarmupState();
}

class _RoomEntryWarmupState extends State<RoomEntryWarmup> {
  Timer? _hover;
  void _prepare() {
    _hover?.cancel();
    RoomStartupCache.instance.prefetch(widget.source, widget.roomId);
  }

  @override
  void didUpdateWidget(RoomEntryWarmup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.roomId != widget.roomId) {
      _hover?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) {
          _hover?.cancel();
          _hover = Timer(const Duration(milliseconds: 180), _prepare);
        },
        onExit: (_) => _hover?.cancel(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            // 触屏滚动不触发预取，手机在确认导航后准备。
            if (event.kind == PointerDeviceKind.mouse &&
                event.buttons == kPrimaryButton) {
              _prepare();
            }
          },
          child: widget.child,
        ),
      );

  @override
  void dispose() {
    _hover?.cancel();
    super.dispose();
  }
}
