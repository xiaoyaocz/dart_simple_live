import 'dart:io';

import 'package:flutter/services.dart';
import 'package:simple_live_app/app/log.dart';

class BackgroundPlaybackService {
  BackgroundPlaybackService._();

  static final BackgroundPlaybackService instance =
      BackgroundPlaybackService._();

  static const MethodChannel _channel =
      MethodChannel('simple_live/background_playback');

  bool _running = false;

  Future<void> start() async {
    if (!Platform.isAndroid || _running) {
      return;
    }
    try {
      await _channel.invokeMethod('start');
      _running = true;
    } catch (e) {
      Log.logPrint(e);
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid || !_running) {
      return;
    }
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      Log.logPrint(e);
    } finally {
      _running = false;
    }
  }
}
