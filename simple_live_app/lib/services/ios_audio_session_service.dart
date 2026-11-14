import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:simple_live_app/app/log.dart';

/// iOS 音频会话事件类型
class IosAudioEventType {
  IosAudioEventType._();

  /// 音频中断开始（来电、Siri、其他 App 抢占）
  static const interruptionBegan = 'interruptionBegan';

  /// 音频中断结束
  static const interruptionEnded = 'interruptionEnded';

  /// 音频路由变化（如拔出耳机）
  static const routeChange = 'routeChange';
}

class IosAudioSessionEvent {
  final String type;

  /// interruptionEnded: 系统是否建议恢复播放
  final bool shouldResume;

  /// routeChange: 是否建议暂停（旧设备不可用，如拔耳机）
  final bool shouldPause;

  const IosAudioSessionEvent({
    required this.type,
    this.shouldResume = false,
    this.shouldPause = false,
  });
}

/// iOS 音频会话管理：中断/路由事件、后台任务额外时间。
/// Android 不需要该服务（由前台服务承担）。
class IosAudioSessionService {
  IosAudioSessionService._() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  static final IosAudioSessionService instance = IosAudioSessionService._();

  static const MethodChannel _channel = MethodChannel('simple_live/ios_audio');

  final StreamController<IosAudioSessionEvent> _eventController =
      StreamController<IosAudioSessionEvent>.broadcast();

  Stream<IosAudioSessionEvent> get events => _eventController.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    final arguments = call.arguments;
    final map = arguments is Map ? Map<dynamic, dynamic>.from(arguments) : null;
    switch (call.method) {
      case 'interruptionBegan':
        _eventController.add(
          const IosAudioSessionEvent(
            type: IosAudioEventType.interruptionBegan,
          ),
        );
        break;
      case 'interruptionEnded':
        _eventController.add(
          IosAudioSessionEvent(
            type: IosAudioEventType.interruptionEnded,
            shouldResume: map?['shouldResume'] == true,
          ),
        );
        break;
      case 'routeChange':
        _eventController.add(
          IosAudioSessionEvent(
            type: IosAudioEventType.routeChange,
            shouldPause: map?['shouldPause'] == true,
          ),
        );
        break;
      default:
        break;
    }
    return null;
  }

  /// 申请额外后台执行时间（重连场景），返回任务 id；用完必须 endBackgroundTask。
  Future<int> beginBackgroundTask(String label) async {
    if (!Platform.isIOS) {
      return -1;
    }
    try {
      final id = await _channel.invokeMethod<int>(
        'beginBackgroundTask',
        {'label': label},
      );
      return id ?? -1;
    } catch (e) {
      Log.logPrint(e);
      return -1;
    }
  }

  Future<void> endBackgroundTask(int id) async {
    if (!Platform.isIOS || id < 0) {
      return;
    }
    try {
      await _channel.invokeMethod('endBackgroundTask', {'id': id});
    } catch (e) {
      Log.logPrint(e);
    }
  }
}
