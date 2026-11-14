import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:simple_live_app/app/log.dart';

/// 后台播放状态
class BackgroundPlaybackState {
  BackgroundPlaybackState._();

  /// 正在播放
  static const playing = 'playing';

  /// 播放中断，正在重连（FGS 必须保持运行）
  static const reconnecting = 'reconnecting';

  /// 用户暂停
  static const paused = 'paused';
}

/// 原生侧回传的事件（媒体按钮 / 音频焦点）
class BackgroundPlaybackEvent {
  /// mediaButton / audioFocus
  final String type;

  /// mediaButton: play / pause / stop
  final String? action;

  /// audioFocus: gain / loss / loss_transient / can_duck
  final String? focusState;

  const BackgroundPlaybackEvent({
    required this.type,
    this.action,
    this.focusState,
  });
}

class BackgroundPlaybackService {
  BackgroundPlaybackService._() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  static final BackgroundPlaybackService instance =
      BackgroundPlaybackService._();

  static const MethodChannel _channel =
      MethodChannel('simple_live/background_playback');

  final StreamController<BackgroundPlaybackEvent> _eventController =
      StreamController<BackgroundPlaybackEvent>.broadcast();

  /// 原生事件流：通知栏媒体按钮、音频焦点变化
  Stream<BackgroundPlaybackEvent> get events => _eventController.stream;

  bool _running = false;
  String _state = BackgroundPlaybackState.playing;
  String _title = '';
  String _subtitle = '';

  bool get isRunning => _running;
  String get currentState => _state;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'playbackEvent') {
      return null;
    }
    final arguments = call.arguments;
    if (arguments is! Map) {
      return null;
    }
    final map = Map<dynamic, dynamic>.from(arguments);
    _eventController.add(
      BackgroundPlaybackEvent(
        type: (map['event'] as String?) ?? '',
        action: map['action'] as String?,
        focusState: map['state'] as String?,
      ),
    );
    return null;
  }

  /// 是否向系统申请音频焦点。关闭后可与其它应用同时出声。
  bool _requestAudioFocus = true;
  bool get requestAudioFocus => _requestAudioFocus;

  Map<String, dynamic> get _arguments => {
        'state': _state,
        'title': _title,
        'subtitle': _subtitle,
        'requestAudioFocus': _requestAudioFocus,
      };

  /// 启动后台播放前台服务。
  /// 返回 false 表示系统拒绝启动（如 Android 12+ 后台启动限制）。
  Future<bool> start({
    String state = BackgroundPlaybackState.playing,
    String title = '',
    String subtitle = '',
    bool requestAudioFocus = true,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    _state = state;
    _title = title;
    _subtitle = subtitle;
    _requestAudioFocus = requestAudioFocus;
    if (_running) {
      await _update();
      return true;
    }
    try {
      final result = await _channel.invokeMethod<bool>('start', _arguments);
      final started = result ?? true;
      _running = started;
      return started;
    } catch (e) {
      Log.logPrint(e);
      return false;
    }
  }

  /// 更新播放状态/文案（重连、暂停等），FGS 不撤销。
  Future<void> update({
    String? state,
    String? title,
    String? subtitle,
    bool? requestAudioFocus,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (state != null) _state = state;
    if (title != null) _title = title;
    if (subtitle != null) _subtitle = subtitle;
    if (requestAudioFocus != null) _requestAudioFocus = requestAudioFocus;
    if (!_running) {
      return;
    }
    await _update();
  }

  Future<void> _update() async {
    try {
      await _channel.invokeMethod('update', _arguments);
    } catch (e) {
      Log.logPrint(e);
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      if (_running) {
        await _channel.invokeMethod('stop');
      }
    } catch (e) {
      Log.logPrint(e);
    } finally {
      _running = false;
      _state = BackgroundPlaybackState.playing;
    }
  }

  /// 设置切换后立即让运行中的前台服务重新评估音频焦点策略。
  Future<void> applyAudioFocusPreference({bool? requestAudioFocus}) async {
    if (!Platform.isAndroid) {
      return;
    }
    _requestAudioFocus = requestAudioFocus ?? _requestAudioFocus;
    if (!_running) {
      return;
    }
    await _update();
  }

  /// 是否已加入电池优化白名单
  Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'isBatteryOptimizationIgnored',
          ) ??
          false;
    } catch (e) {
      Log.logPrint(e);
      return false;
    }
  }

  /// 申请加入电池优化白名单
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } catch (e) {
      Log.logPrint(e);
      return false;
    }
  }

  /// 打开系统电池优化设置
  Future<bool> openBatteryOptimizationSettings() =>
      _invokeBool('openBatteryOptimizationSettings');

  /// 打开厂商自启动管理页（失败则回退应用详情）
  Future<bool> openAutoStartSettings() =>
      _invokeBool('openAutoStartSettings');

  /// 打开系统应用详情页
  Future<bool> openAppDetailsSettings() =>
      _invokeBool('openAppDetailsSettings');

  Future<bool> _invokeBool(String method) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      Log.logPrint(e);
      return false;
    }
  }
}
