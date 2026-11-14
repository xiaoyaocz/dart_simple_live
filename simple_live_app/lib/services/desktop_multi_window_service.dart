import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/desktop_startup_args.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_models.dart';

class DesktopMultiWindowService {
  const DesktopMultiWindowService._();

  static final Set<int> _openedProcessIds = <int>{};

  static bool get isSupported => Platform.isWindows || Platform.isMacOS;

  static bool get hasOpenedRooms => _openedProcessIds.isNotEmpty;

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
      if (AppSettingsController.instance.multiRoomCollapseChat.value) {
        args.add(DesktopStartupArgs.collapseChatArg);
      }
      if (gap == 0) {
        args.add(DesktopStartupArgs.framelessTileArg);
      }
      final process = await Process.start(
        executable,
        args,
        mode: ProcessStartMode.detached,
      );
      _openedProcessIds.add(process.pid);
    }
    SmartDialog.showToast("已打开 ${rooms.length} 个独立直播窗口");
    return true;
  }

  static Future<void> closeOpenedRooms() async {
    if (!isSupported || _openedProcessIds.isEmpty) {
      SmartDialog.showToast("当前没有可关闭的多开窗口");
      return;
    }
    var closed = 0;
    final ids = List<int>.from(_openedProcessIds);
    for (final pid in ids) {
      try {
        final result = Process.killPid(pid);
        if (result) {
          closed += 1;
        }
      } catch (_) {
        // Process may already be closed.
      } finally {
        _openedProcessIds.remove(pid);
      }
    }
    SmartDialog.showToast(
      closed > 0 ? "已关闭 $closed 个多开窗口" : "多开窗口已全部关闭",
    );
  }

  static Future<List<Rect>> _resolveGridBounds(int count) async {
    final displays = await screenRetriever.getAllDisplays();
    final display = displays.isNotEmpty ? displays.first : null;
    final origin = display?.visiblePosition ?? Offset.zero;
    final size = display?.visibleSize ?? display?.size ?? const Size(1280, 720);
    final safeWidth = math.max(size.width, 560.0);
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
