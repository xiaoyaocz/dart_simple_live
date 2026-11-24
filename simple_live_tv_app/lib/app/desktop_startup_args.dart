import 'dart:io';

import 'package:flutter/widgets.dart';

class DesktopStartupArgs {
  static const secondaryInstanceArg = "--simple-live-secondary-instance";
  static const secondaryInstanceEnv = "SIMPLE_LIVE_SECONDARY_INSTANCE";
  static const openSiteArg = "--simple-live-open-site";
  static const openRoomArg = "--simple-live-open-room";
  static const windowLeftArg = "--simple-live-window-left";
  static const windowTopArg = "--simple-live-window-top";
  static const windowWidthArg = "--simple-live-window-width";
  static const windowHeightArg = "--simple-live-window-height";
  static const framelessTileArg = "--simple-live-frameless-tile";

  static List<String> _args = const [];

  static void initialize(List<String> args) {
    _args = List.unmodifiable(args);
  }

  static bool get isSecondaryDesktopInstance {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return false;
    }
    return _args.contains(secondaryInstanceArg) ||
        Platform.environment[secondaryInstanceEnv] == "1";
  }

  static Map<String, String>? get startupRoom {
    final siteId = _argValue(openSiteArg)?.trim();
    final roomId = _argValue(openRoomArg)?.trim();
    if (siteId == null || siteId.isEmpty || roomId == null || roomId.isEmpty) {
      return null;
    }
    return {
      "siteId": siteId,
      "roomId": roomId,
    };
  }

  static Rect? get startupWindowBounds {
    final left = double.tryParse(_argValue(windowLeftArg) ?? "");
    final top = double.tryParse(_argValue(windowTopArg) ?? "");
    final width = double.tryParse(_argValue(windowWidthArg) ?? "");
    final height = double.tryParse(_argValue(windowHeightArg) ?? "");
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    if (width < 320 || height < 240) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  static bool get startupFramelessTile => _args.contains(framelessTileArg);

  static String? _argValue(String key) {
    for (var i = 0; i < _args.length; i += 1) {
      final arg = _args[i];
      if (arg == key && i + 1 < _args.length) {
        return _args[i + 1];
      }
      final prefix = "$key=";
      if (arg.startsWith(prefix)) {
        return arg.substring(prefix.length);
      }
    }
    return null;
  }
}
