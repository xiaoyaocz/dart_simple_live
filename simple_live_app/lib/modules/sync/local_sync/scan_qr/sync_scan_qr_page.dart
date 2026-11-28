import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simple_live_app/modules/sync/local_sync/scan_qr/sync_scan_qr_controller.dart';

class SyncScanQRPage extends GetView<SyncScanQRControlelr> {
  const SyncScanQRPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          IconButton(
            onPressed: controller.toggleTorch,
            icon: const Icon(Icons.flash_on),
          ),
          // 反转摄像头
          IconButton(
            onPressed: controller.switchCamera,
            icon: const Icon(Icons.flip_camera_android),
          ),
        ],
      ),
      body: Obx(() {
        final cameraReady = controller.cameraReady.value;
        if (cameraReady == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!cameraReady) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('需要相机权限才能扫描二维码'),
                TextButton(
                  onPressed: controller.retryCamera,
                  child: const Text('授权相机'),
                ),
              ],
            ),
          );
        }
        return Stack(
          children: [
            MobileScanner(
              controller: controller.scannerController,
              onDetect: controller.onDetect,
              tapToFocus: true,
              errorBuilder: (context, error) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('相机启动失败，请检查相机权限'),
                    TextButton(
                      onPressed: controller.retryCamera,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
            const IgnorePointer(child: ScanRectangle()),
            Positioned(
              bottom: 36,
              left: 16,
              right: 16,
              child: Center(
                child: Obx(() => Text(
                      controller.hint.value,
                      style: const TextStyle(
                        color: Colors.white,
                        backgroundColor: Colors.black54,
                      ),
                    )),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class ScanRectangle extends StatelessWidget {
  const ScanRectangle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 280,
        width: 280,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white70,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
