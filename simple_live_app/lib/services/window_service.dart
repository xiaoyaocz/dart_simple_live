import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:window_manager/window_manager.dart';

class WindowService extends GetxService implements WindowListener {
  static WindowService get instance => Get.find<WindowService>();

  bool isPIP = false;

  WindowService() {
    windowManager.addListener(this);
  }

  Future<void> init() async {
    await resize();
    WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(280, 280),
      center: false,
      title: "Slive",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<void> resize() async {
    // 初始分辨率默认 1920×1080
    final width = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowWidth, 1280.0);
    final height = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowHeight, 720.0);
    final x = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowX, 320.0);
    final y = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowY, 180.0);
    windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
  }

  @override
  void onWindowBlur() {}

  @override
  void onWindowClose() {
    if (Platform.isLinux) {
      exit(0);
    }
  }

  @override
  void onWindowDocked() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  Future<void> onWindowMove() async {}

  @override
  Future<void> onWindowMoved() async {
    if (!isPIP) {
      final bounds = await windowManager.getBounds();
      _saveBounds(bounds);
    }
  }

  @override
  Future<void> onWindowResize() async {}

  @override
  Future<void> onWindowResized() async {
    if (!isPIP) {
      final bounds = await windowManager.getBounds();
      _saveBounds(bounds);
    }
  }

  @override
  void onWindowRestore() {}

  @override
  void onWindowUndocked() {}

  @override
  void onWindowUnmaximize() {}

  void _saveBounds(Rect bounds) {
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowX, bounds.left);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowY, bounds.top);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowWidth, bounds.width);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowHeight, bounds.height);
  }
}
