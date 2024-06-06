import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:motion_sensors/motion_sensors.dart' as motion_sensors;

class TestPage extends GetView<TestController> {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Obx(
          () => Text(
            controller.orientation.value,
            style: const TextStyle(fontSize: 32, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class TestController extends GetxController {
  var orientation = "".obs;

  @override
  void onInit() {
    setLandscape();
    super.onInit();
  }

  void setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    orientation.value = "LANDSCAPE LEFT";
    listenSensor();
  }

  StreamSubscription<AccelerometerEvent>? _streamSubscription;
  StreamSubscription? _orientationStreamSubscription;
  void listenSensor() {
    // 监听传感器事件，获取当前设备的方向
    // _streamSubscription = accelerometerEventStream(
    //   samplingPeriod: const Duration(seconds: 1),
    // ).listen((AccelerometerEvent event) {
    //   var x = event.x;
    //   var y = event.y;

    //   var newOrientation = "";
    //   if (x >= 9.0 && y < 9.0 && y >= -9.0) {
    //     newOrientation = "LANDSCAPE LEFT";
    //   } else if (x <= -9.0 && y < 9.0 && y >= -9.0) {
    //     newOrientation = "LANDSCAPE RIGHT";
    //   }
    //   if (orientation.value != newOrientation && newOrientation.isNotEmpty) {
    //     orientation.value = newOrientation;
    //     if (orientation.value == "LANDSCAPE RIGHT") {
    //       SystemChrome.setPreferredOrientations([
    //         DeviceOrientation.landscapeRight,
    //       ]);
    //     } else {
    //       SystemChrome.setPreferredOrientations([
    //         DeviceOrientation.landscapeLeft,
    //       ]);
    //     }
    //     Log.d("newOrientation: $newOrientation");
    //   }
    // });

    _orientationStreamSubscription =
        motion_sensors.motionSensors.accelerometer.listen((event) {
      var x = event.x;
      var y = event.y;

      var newOrientation = "";
      if (x >= 9.0 && y < 9.0 && y >= -9.0) {
        newOrientation = "LANDSCAPE LEFT";
      } else if (x <= -9.0 && y < 9.0 && y >= -9.0) {
        newOrientation = "LANDSCAPE RIGHT";
      }
      if (orientation.value != newOrientation && newOrientation.isNotEmpty) {
        orientation.value = newOrientation;
        if (orientation.value == "LANDSCAPE RIGHT") {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
          ]);
        }
        Log.d("newOrientation: $newOrientation");
      }
    });
  }

  @override
  void onClose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _streamSubscription?.cancel();
    _orientationStreamSubscription?.cancel();
    super.onClose();
  }
}
