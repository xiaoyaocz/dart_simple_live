import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/desktop_startup_args.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_models.dart';

class DesktopMultiWindowService {
  const DesktopMultiWindowService._();

  static final Set<int> _openedProcessIds = <int>{};

  static bool get isSupported => Platform.isWindows;

  static Future<bool> openRooms(List<MultiRoomItem> rooms) async {
    if (!isSupported || rooms.length < 2) {
      return false;
    }
    final executable = Platform.resolvedExecutable;
    final bounds = await _resolveGridBounds(rooms.length);
    final gap = AppSettingsController.instance.effectiveMultiRoomGap;
    for (var i = 0; i < rooms.length; i += 1) {
      final room = rooms[i];
      final rect = bounds[i];
      final args = [
        DesktopStartupArgs.secondaryInstanceArg,
        DesktopStartupArgs.openSiteArg,
        room.site.id,
        DesktopStartupArgs.openRoomArg,
        room.roomId,
        DesktopStartupArgs.windowLeftArg,
        rect.left.round().toString(),
        DesktopStartupArgs.windowTopArg,
        rect.top.round().toString(),
        DesktopStartupArgs.windowWidthArg,
        rect.width.round().toString(),
        DesktopStartupArgs.windowHeightArg,
        rect.height.round().toString(),
      ];
      if (gap == 0) {
        args.add(DesktopStartupArgs.framelessTileArg);
      }
      Log.i(
        "TV-Windows multi-open start site=${room.site.id} roomId=${room.roomId} "
        "bounds=${rect.left},${rect.top},${rect.width},${rect.height} "
        "args=${args.join(" ")}",
      );
      final process = await Process.start(
        executable,
        args,
        environment: {
          DesktopStartupArgs.secondaryInstanceEnv: "1",
        },
        mode: ProcessStartMode.detached,
      );
      Log.i("TV-Windows multi-open child pid=${process.pid}");
      _openedProcessIds.add(process.pid);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    SmartDialog.showToast("已打开 ${rooms.length} 个独立 TV-Windows 直播窗口");
    return true;
  }

  static Future<List<Rect>> _resolveGridBounds(int count) async {
    final displays = await screenRetriever.getAllDisplays();
    final display = displays.isNotEmpty ? displays.first : null;
    final origin = display?.visiblePosition ?? Offset.zero;
    final size = display?.visibleSize ?? display?.size ?? const Size(1280, 720);
    final safeWidth = math.max(size.width, 640.0);
    final safeHeight = math.max(size.height, 360.0);
    final columns = count <= 1 ? 1 : (count <= 4 ? 2 : 3);
    final rows = (count / columns).ceil();
    final gap = AppSettingsController.instance.effectiveMultiRoomGap.toDouble();
    final cellWidth = (safeWidth - gap * (columns + 1)) / columns;
    final cellHeight = (safeHeight - gap * (rows + 1)) / rows;
    final result = <Rect>[];
    for (var i = 0; i < count; i += 1) {
      final column = i % columns;
      final row = i ~/ columns;
      result.add(
        Rect.fromLTWH(
          origin.dx + gap + column * (cellWidth + gap),
          origin.dy + gap + row * (cellHeight + gap),
          cellWidth,
          cellHeight,
        ),
      );
    }
    return result;
  }
}
