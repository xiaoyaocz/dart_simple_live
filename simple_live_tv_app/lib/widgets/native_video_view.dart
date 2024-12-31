

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class NativeVideoView extends StatelessWidget {
  final MethodChannel _methodChannel = const MethodChannel("samples.flutter.jumpto.android");
  const NativeVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    return AndroidView(
        viewType: "nativeVideoView", onPlatformViewCreated: (int id) {});
  }

  void startPlayVideo(String videoUrl, Map<String, String>? httpHeaders) {
    _methodChannel.invokeMethod("startPlay", {
      "videoUrl": videoUrl,
      "headers": httpHeaders
    });
  }

  void stopPlayVideo() {
    _methodChannel.invokeMethod("stopPlay");
  }
}