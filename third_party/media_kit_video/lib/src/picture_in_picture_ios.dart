import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// iOS 画中画（AVSampleBufferDisplayLayer 路线，iOS 15+）。
///
/// 帧源来自 media_kit_video 的 VideoOutput：每帧渲染的 CVPixelBuffer
/// 零拷贝送入系统的画中画窗口。会话期间建议将渲染切换到纯软件路径
/// （[setHardwareAcceleration] enabled=false），因为退后台后进程失去
/// GPU 访问权，GL 渲染会停帧；软件渲染（mpv zimg）不受影响。
///
/// 事件：
/// - willStart / didStart：画中画即将/已经启动
/// - willStop / didStop：画中画即将/已经结束（restore 恢复 UI 场景）
/// - closed：用户在画中画窗口点关闭
/// - restore：用户点击画中画的恢复按钮
/// - setPlaying：用户在画中画窗口操作了播放/暂停（playing: bool）
/// - failed：画中画启动失败（reason: String）
class IosPictureInPicture {
  IosPictureInPicture._();

  static const MethodChannel _pipChannel = MethodChannel(
    'com.alexmercerind/media_kit_video/pip',
  );
  static const EventChannel _pipEventChannel = EventChannel(
    'com.alexmercerind/media_kit_video/pip/events',
  );
  static const MethodChannel _outputChannel = MethodChannel(
    'com.alexmercerind/media_kit_video',
  );

  static Stream<Map>? _events;

  /// 设备是否支持画中画（iOS 15+ 且系统支持）。
  static Future<bool> isSupported() async {
    if (!Platform.isIOS) {
      return false;
    }
    try {
      return await _pipChannel.invokeMethod('isSupported') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 建立帧管线并创建画中画控制器。
  ///
  /// [handle] 为 mpv 实例指针（`player.handle`）。
  /// [startImmediately] 为 true 时，首帧渲染完成后自动进入画中画；
  /// 否则需调用 [enter] 手动进入。[autoEnter] 决定退后台是否自动进入。
  static Future<bool> start({
    required int handle,
    bool autoEnter = false,
    bool startImmediately = false,
  }) async {
    if (!Platform.isIOS) {
      return false;
    }
    try {
      await _pipChannel.invokeMethod('start', {
        'handle': handle.toString(),
        'autoEnter': autoEnter,
        'startImmediately': startImmediately,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 立即进入画中画。
  static Future<void> enter() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _pipChannel.invokeMethod('enter');
    } catch (e) {
      // ignore
    }
  }

  /// 结束画中画并拆除帧管线。
  static Future<void> stop() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _pipChannel.invokeMethod('stop');
    } catch (e) {
      // ignore
    }
  }

  /// 设置退后台自动进入画中画。
  static Future<void> setAutoEnter(bool autoEnter) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _pipChannel.invokeMethod('setAutoEnter', {'autoEnter': autoEnter});
    } catch (e) {
      // ignore
    }
  }

  /// 切换视频输出的硬件/软件渲染（画中画会话期间应使用软件渲染）。
  static Future<void> setHardwareAcceleration({
    required int handle,
    required bool enabled,
  }) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _outputChannel.invokeMethod(
        'VideoOutputManager.SetHardwareAcceleration',
        {'handle': handle.toString(), 'enabled': enabled},
      );
    } catch (e) {
      // ignore
    }
  }

  /// 画中画事件流。
  static Stream<Map> get events {
    _events ??= _pipEventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => event as Map);
    return _events!;
  }
}
