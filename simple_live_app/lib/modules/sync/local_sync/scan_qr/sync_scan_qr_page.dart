import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
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
            onPressed: () {
              controller.qrController?.toggleFlash();
            },
            icon: const Icon(Icons.flash_on),
          ),
          // 反转摄像头
          IconButton(
            onPressed: () {
              controller.qrController?.flipCamera();
            },
            icon: const Icon(Icons.flip_camera_android),
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: controller.qrKey,
            onQRViewCreated: controller.onQRViewCreated,
          ),
          const ScanRectangle(),
        ],
      ),
    );
  }
}

class ScanRectangle extends StatefulWidget {
  const ScanRectangle({super.key});

  @override
  State<ScanRectangle> createState() => _ScanRectangleState();
}

class _ScanRectangleState extends State<ScanRectangle>
    with SingleTickerProviderStateMixin {
  late AnimationController animeController;
  late Animation<Offset> animation;

  @override
  void initState() {
    animeController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    animeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animeController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        animeController.forward();
      }
    });
    animation = Tween(
      begin: const Offset(0, 0),
      end: const Offset(0, 1),
    ).animate(animeController);
    animeController.forward();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 240,
        width: 240,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.withAlpha(50),
            width: 2,
          ),
        ),
        child: SlideTransition(
          position: animation,
          child: Container(
            height: 240,
            width: 240,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  width: 2,
                  color: Colors.green,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    animeController.dispose();
    super.dispose();
  }
}
